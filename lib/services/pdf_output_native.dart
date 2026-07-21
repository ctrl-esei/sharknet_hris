import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Opens the native sharing interface on Android, iOS,
/// macOS, Windows, and Linux.
Future<void> savePdfFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  await Printing.sharePdf(
    bytes: bytes,
    filename: fileName,
  );
}