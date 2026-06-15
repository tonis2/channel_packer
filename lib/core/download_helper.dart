import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Trigger a browser download of [bytes] as [filename].
///
/// WASM-safe: uses `package:web` + `dart:js_interop` (a Blob + object URL +
/// a synthetic anchor click), never `dart:html`/`dart:io`. Used by both the
/// per-node "Download PNG" buttons and the graph JSON save.
void downloadBytes(Uint8List bytes, String filename, {String mime = 'application/octet-stream'}) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
