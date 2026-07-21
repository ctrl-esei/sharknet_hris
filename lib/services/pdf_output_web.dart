import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Downloads a generated PDF directly through the web browser.
///
/// This avoids using Printing.sharePdf() or Printing.layoutPdf()
/// when the Flutter application is running in Chrome.
Future<void> savePdfFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  // Create an independent byte buffer to avoid offset or view issues.
  final Uint8List pdfBytes = Uint8List.fromList(bytes);

  final JSArrayBuffer arrayBuffer = pdfBytes.buffer.toJS;

  final web.Blob blob = web.Blob(
    <JSArrayBuffer>[arrayBuffer].toJS,
    web.BlobPropertyBag(
      type: 'application/pdf',
    ),
  );

  final String objectUrl =
      web.URL.createObjectURL(blob);

  final web.HTMLAnchorElement anchor =
      web.document.createElement('a')
          as web.HTMLAnchorElement;

  anchor
    ..href = objectUrl
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);

  anchor.click();
  anchor.remove();

  // Give Chrome enough time to start the download before
  // revoking the temporary object URL.
  await Future<void>.delayed(
    const Duration(milliseconds: 300),
  );

  web.URL.revokeObjectURL(objectUrl);
}