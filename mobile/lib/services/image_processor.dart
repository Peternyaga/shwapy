import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CropFractions {
  const CropFractions({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

class PreparedImage {
  const PreparedImage({
    required this.bytes,
    required this.base64,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String base64;
  final String mimeType;
}

class ImageProcessor {
  static const captureCrop = CropFractions(
    left: 0.07,
    top: 0.27,
    width: 0.86,
    height: 0.46,
  );

  Future<PreparedImage> cropAndCompress(String path) async {
    final bytes = await compute(_process, {
      'path': path,
      'left': captureCrop.left,
      'top': captureCrop.top,
      'width': captureCrop.width,
      'height': captureCrop.height,
    });

    return PreparedImage(
      bytes: bytes,
      base64: base64Encode(bytes),
      mimeType: 'image/jpeg',
    );
  }
}

Future<Uint8List> _process(Map<String, Object> input) async {
  final file = File(input['path']! as String);
  final source = img.decodeImage(await file.readAsBytes());

  if (source == null) {
    throw StateError('Captured image could not be decoded.');
  }

  final left = input['left']! as double;
  final top = input['top']! as double;
  final width = input['width']! as double;
  final height = input['height']! as double;
  final cropX = max(0, (source.width * left).round());
  final cropY = max(0, (source.height * top).round());
  final cropW = min(source.width - cropX, (source.width * width).round());
  final cropH = min(source.height - cropY, (source.height * height).round());
  final cropped = img.copyCrop(
    source,
    x: cropX,
    y: cropY,
    width: cropW,
    height: cropH,
  );
  final longest = max(cropped.width, cropped.height);
  final resized = longest > 1200
      ? img.copyResize(
          cropped,
          width: cropped.width >= cropped.height ? 1200 : null,
          height: cropped.height > cropped.width ? 1200 : null,
          interpolation: img.Interpolation.average,
        )
      : cropped;

  var quality = 80;
  var encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));

  while (encoded.length > 420 * 1024 && quality > 52) {
    quality -= 8;
    encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

  return encoded;
}
