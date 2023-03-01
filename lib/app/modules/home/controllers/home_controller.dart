import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../flower/flower_client.dart';

class HomeController extends GetxController {
  RxBool isDownloaded = false.obs;
  RxBool isFederated = false.obs;
  RxBool isDatasetLoaded = false.obs;
  late FlowerClient flowerClient;
  RxBool isDownloading = false.obs;
  RxBool isLoading = false.obs;
  final url = 'https://www.dropbox.com/s/coeixr4kh8ljw6o/cifar10.zip?dl=1';
  final filename = 'cifar.zip';
  late TextEditingController ip;
  late TextEditingController port;
  late TextEditingController deviceId;
  late Logger logger;
  RxString displayLog = ''.obs;
  late MethodChannel tf;
  late ScrollController scrollController;
  @override
  void onInit() {
    super.onInit();
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      log(
        '${record.level.name} ${record.time} ${record.message}',
        name: 'FLOWER',
      );
      displayLog.value +=
          '${record.level.name} ${record.time} ${record.message} \n \n ';
    });
    logger = Logger('FLOWER');
    ip = TextEditingController();
    port = TextEditingController();
    deviceId = Tehttps://github.com/Anthrapper/flutterFlower  Here is my rough implementation!xtEditingController(text: '1');
    tf = const MethodChannel('tl_wrapper');
  }

  @override
  void onReady() {
    _requestWritePermission();
    flowerClient = FlowerClient();
    super.onReady();
  }

  @override
  void onClose() {
    ip.dispose();
    port.dispose();
    deviceId.dispose();
    super.onClose();
  }

  Future _requestWritePermission() async {
    await Permission.storage.request();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  void clearLogs() {
    displayLog.value = '';
  }

  Future grpcConnect() async {
    if (ip.text.isEmpty || port.text.isEmpty) {
      return Get.rawSnackbar(title: 'Error', message: 'IP or Port is empty');
    } else if (isDatasetLoaded.value == false) {
      return Get.rawSnackbar(title: 'Error', message: 'Dataset is not loaded');
    }
    await flowerClient.grpcConnect(ip: ip.text, port: port.text).onError(
        (error, stackTrace) =>
            Get.rawSnackbar(title: 'Error', message: error.toString()));
    isFederated.toggle();
  }

  Future loadData() async {
    String path = await _localPath;

    if (deviceId.text.isEmpty) {
      return Get.rawSnackbar(title: 'Error', message: 'Device ID is empty');
    } else if (isDownloaded.value == false) {
      int count =
          Directory(path).listSync(recursive: true).whereType<File>().length;
      if (count > 10) {
        isDownloaded.toggle();
      } else {
        return Get.rawSnackbar(
            title: 'Error', message: 'Dataset is not downloaded');
      }
    }

    isLoading.toggle();
    await flowerClient.initTf();
    await flowerClient
        .loadData(int.parse(deviceId.text), path)
        .onError((error, stackTrace) {
      Get.rawSnackbar(title: 'Error', message: error.toString());
    });

    isLoading.toggle();
    isDatasetLoaded.toggle();
  }

  Future<void> downloadData() async {
    String path = await _localPath;

    isDownloading.toggle();
    await flowerClient
        .downloadAndUnzip(url, filename, path)
        .onError((error, stackTrace) {
      Get.rawSnackbar(title: 'Error', message: error.toString());
      log(error.toString());
    });
    logger.info('Downloaded and Unzipped');
    isDownloading.toggle();
    isDownloaded.toggle();
  }

  Future<XFile?> pickImages() async {
    try {
      final img = await ImagePicker().pickImage(source: ImageSource.gallery);
      return img;
    } catch (e) {
      logger.info('Error picking images: $e');
      return null;
    }
  }

  Future predict() async {
    XFile? img = await pickImages();
    if (img == null) {
      return;
    } else {
      logger.info(img.path);
      await flowerClient.predictImg(img.path);
    }
  }
}
