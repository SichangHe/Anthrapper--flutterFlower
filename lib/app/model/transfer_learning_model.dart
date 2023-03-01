import 'package:ant/app/modules/home/controllers/home_controller.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'model_wrapper.dart';

class TransferLearningModelWrapper extends ModelWrapper {
  final MethodChannel tf = Get.find<HomeController>().tf;
  final logger = Get.find<HomeController>().logger;

  @override
  Future<List<Uint8List>> getParameters() async {
    var parameters = await tf.invokeMethod('getParameters');
    List<Uint8List> weights =
        parameters.map((x) => x).cast<Uint8List>().toList();
    logger.info('Got weights: ${weights.length} layers');
    return weights;
  }

  @override
  Future<void> updateParameters(List<Uint8List> weights) async {
    await tf.invokeMethod('updateParameters', {"weight": weights});
  }

  @override
  Future<void> train(int epochs) async {
    await tf.invokeMethod('train', {"epochs": epochs});
  }

  @override
  Future<void> enableTraining(
    void Function(
      int epoch,
      double loss,
    )
        callback,
  ) async {
    tf.setMethodCallHandler((call) async {
      if (call.method == 'onLoss') {
        final args = call.arguments;
        logger.info('${args.toString()} ');
        final epoch = args['step'];
        final loss = args['loss'];
        callback(epoch, loss);
      }
    });
    await tf.invokeMethod('enableTraining');
  }

  @override
  Future<void> disableTraining() async {
    await tf.invokeMethod('disableTraining');
  }

  @override
  Future<int> getSizeTraining() async {
    return (await tf.invokeMethod('getSizeTraining')) as int? ?? 0;
  }

  @override
  Future<int> getSizeTesting() async {
    return (await tf.invokeMethod('getSizeTesting')) as int? ?? 0;
  }

  @override
  Future<List<dynamic>> calculateTestStatistics() async {
    final result = await tf.invokeMethod('calculateTestStatistics');
    logger.info("calculate Test statistics: $result");
    return result;
  }

  Future predict(List<double> image) async {
    try {
      var predictRes = await tf.invokeMethod('predict', {
        "image": image,
      });
      logger.info('Predicted: ${predictRes.toString()}');
    } on Exception catch (e) {
      throw Exception('Failed to predict: ${e.toString()}');
    }
  }

  Future<void> addSample(
    List<double> rgbImage,
    String sampleClass,
    bool isTraining,
  ) async {
    try {
      await tf.invokeMethod(
        'addSample',
        {
          "rgbImage": rgbImage,
          "sampleClass": sampleClass,
          "isTraining": isTraining
        },
      );
    } on Exception catch (e) {
      throw Exception('Failed to add sample: ${e.toString()}');
    }
  }

  @override
  Future<void> init() async {
    await tf.invokeMethod('init');
  }
}
