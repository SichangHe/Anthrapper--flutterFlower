import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ant/app/modules/home/controllers/home_controller.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:grpc/grpc.dart';

import 'helpers.dart';
import '../model/transfer_learning_model.dart';
import '../transport_protos.dart';
import 'flower_base.dart';

class FlowerClient extends FlowerBase {
  late FlowerServiceClient stub;
  late ClientChannel channel;
  late ClientMessage c;
  final messageStream = StreamController<ClientMessage>();
  final int imageSize = 32;
  final TransferLearningModelWrapper tlModel = TransferLearningModelWrapper();
  final int lowerByteMask = 0xFF;
  Completer<void> isTraining = Completer<void>();
  int localEpochs = 1;
  ValueNotifier<double> lastLoss = ValueNotifier<double>(0.0);
  final logger = Get.find<HomeController>().logger;

  FlowerClient() {
    initTf();
  }
  Future<void> initTf() async {
    await tlModel.init();
  }

  Future<List<Uint8List>> getWeights() async {
    return await tlModel.getParameters();
  }

  Future<void> grpcConnect({
    required String ip,
    required String port,
  }) async {
    try {
      channel = ClientChannel(
        ip,
        port: int.parse(port),
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );

      stub = FlowerServiceClient(channel);

      logger.info('Joining Flower server');
      final subscription = stub.join(messageStream.stream).listen(
        (message) async {
          if (message.hasGetParametersIns()) {
            c = await handleGetParameters(message);
          } else if (message.hasFitIns()) {
            c = await handleFit(message);
          } else if (message.hasEvaluateIns()) {
            c = await handleEvaluate(message);
          }
          sendMessage(c);
        },
      );

      await subscription.asFuture();
      await channel.shutdown();
      logger.info('Connection Closed');
    } on Exception catch (e) {
      logger.severe(e.toString());
    }
  }

  void sendMessage(ClientMessage message) {
    messageStream.add(message);
  }

  Future<Map<String, dynamic>> fit(List<Uint8List> weights, int epochs) async {
    localEpochs = epochs;
    await tlModel.updateParameters(weights);
    isTraining = Completer<void>();
    logger.config("Weights updated");
    await tlModel.train(localEpochs);
    logger.info('Training enabled. Local Epochs = $localEpochs');
    await tlModel.enableTraining(
      (epoch, loss) async => setLastLoss(epoch, loss),
    );
    await isTraining.future;
    List<Uint8List> newWeights = await getWeights();
    int trainingSize = await tlModel.getSizeTraining();
    logger.info("trainingSize = $trainingSize");
    return {'weights': newWeights, 'trainingSize': trainingSize};
  }

  void setLastLoss(int epoch, double newLoss) {
    if (epoch == localEpochs - 1) {
      logger.info("Training finished after epoch = $epoch");
      lastLoss.value = newLoss;
      tlModel.disableTraining();
      isTraining.complete();
    }
  }

  Future<Map<String, dynamic>> evaluate(List<Uint8List> weights) async {
    await tlModel.updateParameters(weights);
    await tlModel.disableTraining();
    return {
      'testStats': await tlModel.calculateTestStatistics(),
      'testSize': await tlModel.getSizeTesting()
    };
  }

  Future<void> downloadAndUnzip(
      String url, String filename, String dirPath) async {
    await ModelHelpers.downloadAndUnzip(url, filename, dirPath);
  }

  Future<void> loadData(int deviceId, String path) async {
    final trainReader = await rootBundle
        .loadString('assets/data/partition_${deviceId - 1}_train.txt');
    final trainLines =
        trainReader.split('\n').where((line) => line.isNotEmpty).toList();

    final testReader = await rootBundle
        .loadString('assets/data/partition_${deviceId - 1}_test.txt');
    final testLines =
        testReader.split('\n').where((line) => line.isNotEmpty).toList();
    logger.info(
        "Found ${testLines.length} testing & ${trainLines.length} training samples");

    final futures = <Future>[];
    for (final line in trainLines) {
      futures.add(addSample('$path/$line', true));
    }

    for (final line in testLines) {
      futures.add(addSample('$path/$line', false));
    }

    await Future.wait(futures);

    logger.info("Loaded training and testing samples");
  }

  Future predictImg(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final bitmap = frame.image;

    // get rgb equivalent and class
    final rgbImage = await prepareImage(bitmap);
    await tlModel.predict(rgbImage);
  }

  Future<void> addSample(String photoPath, bool isTraining) async {
    final file = File(photoPath);
    final bytes = await file.readAsBytes();

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final bitmap = frame.image;

    final sampleClass = getClass(photoPath);
    // get rgb equivalent and class
    final rgbImage = await prepareImage(bitmap);

    // add to the list.
    try {
      await tlModel.addSample(rgbImage, sampleClass, isTraining);
    } on Exception catch (e) {
      throw Exception("Failed to add sample to model: $e");
    }
  }

  Future<Float32List> prepareImage(ui.Image image) async {
    final modelImageSize = imageSize;
    final normalizedRgb = Float32List(modelImageSize * modelImageSize * 3);
    int nextIdx = 0;
    final imageByteData = await image.toByteData();

    for (int y = 0; y < modelImageSize; y++) {
      for (int x = 0; x < modelImageSize; x++) {
        final pixelIndex = (y * modelImageSize + x) * 4;
        final r = imageByteData!.getUint8(pixelIndex) * (1 / 255.0);
        final g = imageByteData.getUint8(pixelIndex + 1) * (1 / 255.0);
        final b = imageByteData.getUint8(pixelIndex + 2) * (1 / 255.0);

        normalizedRgb[nextIdx++] = r;
        normalizedRgb[nextIdx++] = g;
        normalizedRgb[nextIdx++] = b;
      }
    }
    return normalizedRgb;
  }

  String getClass(String path) {
    String className = path.split('/').elementAt(path.split('/').length - 2);
    return className;
  }

  Future<ClientMessage> handleGetParameters(ServerMessage message) async {
    logger.info('Handling GetParameters message from the server.');
    List<Uint8List> weights = await getWeights();
    ClientMessage res = weightsAsProto(weights);
    return res;
  }

  Future<ClientMessage> handleFit(ServerMessage message) async {
    logger.info('Handling Fit request from the server.');

    List<Uint8List> layers = message.fitIns.parameters.tensors
        .map((tensor) => Uint8List.fromList(tensor))
        .toList();

    Int64 epochConfig =
        (message.fitIns.config['local_epochs']?.sint64 ?? 1) as Int64;
    logger.info("Number of epochs: $epochConfig");

    Map<String, dynamic> fitRes = await fit(layers, epochConfig.toInt());
    List<Uint8List> newWeights = fitRes['weights'];
    int trainingSize = fitRes['trainingSize'];
    ClientMessage res = fitResAsProto(newWeights, trainingSize);
    return res;
  }

  Future<ClientMessage> handleEvaluate(ServerMessage message) async {
    logger.info('Handling Evaluate request from the server');

    List<Uint8List> layers = message.evaluateIns.parameters.tensors
        .map((tensor) => Uint8List.fromList(tensor))
        .toList();

    Map<String, dynamic> evalRes = await evaluate(layers);
    double loss = evalRes['testStats'][0];
    double accuracy = evalRes['testStats'][1];

    logger.info("Test Accuracy after this round = $accuracy");
    int testSize = evalRes['testSize'];
    ClientMessage res = evaluateResAsProto(loss, testSize);
    return res;
  }
}
