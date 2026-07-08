// SPDX-License-Identifier: MIT
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Renders [data] as a print-ready QR PNG: black modules on a white
/// square with a quiet zone, [size] px on each side (#112).
Future<Uint8List> buildQrPng(String data, {int size = 1024}) async {
  final side = size.toDouble();
  final margin = side / 16;
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Colors.black,
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Colors.black,
    ),
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, side, side),
      Paint()..color = Colors.white,
    )
    ..translate(margin, margin);
  painter.paint(canvas, Size(side - 2 * margin, side - 2 * margin));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
