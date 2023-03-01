import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';

class ModelHelpers {
  static Future<void> downloadAndUnzip(
    String url,
    String filename,
    String directoryPath,
  ) async {
    Dio dio = Dio();

    await dio.download(
      url,
      "$directoryPath/$filename",
    );

    log('Zip file Downloaded');
    await unzipFile("$directoryPath/$filename", "$directoryPath/");
    log('Extraction completed');
  }

  static Future<void> unzipFile(
      String zipFilePath, String destinationDir) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(
        _unzipInIsolate, [zipFilePath, destinationDir, receivePort.sendPort]);
    await receivePort.first;
  }

  static void _unzipInIsolate(List<dynamic> args) {
    final zipFilePath = args[0];
    final destinationDir = args[1];
    final sendPort = args[2] as SendPort;
    final zipFile = File(zipFilePath);
    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = '$destinationDir/${file.name}';
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(filename)..createSync(recursive: true);
        outFile.writeAsBytesSync(data);
      } else {
        Directory(filename).createSync(recursive: true);
      }
    }
    sendPort.send(null);
  }
}
