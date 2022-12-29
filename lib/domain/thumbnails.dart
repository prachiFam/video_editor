import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_editor/domain/bloc/controller.dart';
import 'package:video_editor/domain/entities/cover_data.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

Stream<List<Uint8List>> generateTrimThumbnails(
  VideoEditorController controller, {
  required int quantity,
  int quality = 10,
}) async* {
  List<Uint8List> imagesList = [];
  generateThumbnailUsingFFmg(controller, quantity, (byteList) {
    imagesList.addAll(byteList);
  });
  yield imagesList;

  // final String path = controller.file.path;
  // final double eachPart = controller.videoDuration.inMilliseconds / quantity;
  // List<Uint8List> byteList = [];
  //
  // for (int i = 1; i <= quantity; i++) {
  //   try {
  //     final Uint8List? bytes = await VideoThumbnail.thumbnailData(
  //       imageFormat: ImageFormat.JPEG,
  //       video: path,
  //       timeMs: (eachPart * i).toInt(),
  //       quality: quality,
  //     );
  //     if (bytes != null) {
  //       byteList.add(bytes);
  //     }
  //   } catch (e) {
  //     debugPrint(e.toString());
  //   }
  //
  //   yield byteList;
  //}
}

void generateThumbnailUsingFFmg(
  VideoEditorController controller,
  int quantity,
  ValueChanged onProcessed,
) async {
  final String path = controller.file.path;
  final double eachPart = controller.videoDuration.inMilliseconds / quantity;
  String timeFrame = DateTime.now().microsecondsSinceEpoch.toString();

  Directory tempDirectory = await getTemporaryDirectory();
  String videoPlayerSnapshotDirectoryPath =
      tempDirectory.path + "/frames/$timeFrame";
  Directory snapshotDir =
      await Directory(videoPlayerSnapshotDirectoryPath).create(recursive: true);

  FFmpegKit.execute(
          '-i ${path} -s 300x300 -vf fps=1 ${snapshotDir.path}/ffmpeg_%0d.jpg')
      .then((session) async {
    // Return code for completed sessions. Will be undefined if session is still running or FFmpegKit fails to run it
    final returnCode = await session.getReturnCode();

    // Console output generated for this execution
    final output = await session.getOutput();

    if (output != null && returnCode != num && returnCode!.getValue() == 0) {
      List<FileSystemEntity> filesList = [];
      List<Uint8List> byteList = [];
      filesList = await snapshotDir.listSync();
      if (filesList.isNotEmpty) {
        for (FileSystemEntity fileSystemEntity in filesList) {
          Uint8List byte = File(fileSystemEntity.path).readAsBytesSync();
          byteList.add(byte);
        }
      }
      onProcessed(byteList);
    } else {}
  });
}

Stream<List<CoverData>> generateCoverThumbnails(
  VideoEditorController controller, {
  required int quantity,
  int quality = 10,
}) async* {
  final int duration = controller.isTrimmed
      ? controller.trimmedDuration.inMilliseconds
      : controller.videoDuration.inMilliseconds;
  final double eachPart = duration / quantity;
  List<CoverData> byteList = [];

  for (int i = 0; i < quantity; i++) {
    try {
      final CoverData bytes = await generateSingleCoverThumbnail(
        controller.file.path,
        timeMs: (controller.isTrimmed
                ? (eachPart * i) + controller.startTrim.inMilliseconds
                : (eachPart * i))
            .toInt(),
        quality: quality,
      );

      if (bytes.thumbData != null) {
        byteList.add(bytes);
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    yield byteList;
  }
}

/// Generate a cover at [timeMs] in video
///
/// return [CoverData] depending on [timeMs] milliseconds
Future<CoverData> generateSingleCoverThumbnail(
  String filePath, {
  int timeMs = 0,
  int quality = 10,
}) async {
  final Uint8List? thumbData = await VideoThumbnail.thumbnailData(
    imageFormat: ImageFormat.JPEG,
    video: filePath,
    timeMs: timeMs,
    quality: quality,
  );

  return CoverData(thumbData: thumbData, timeMs: timeMs);
}
