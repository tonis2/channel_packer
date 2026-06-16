import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Native (Linux/macOS/Windows): "download" = a Save-As dialog, then write the
/// bytes to the chosen path.
///
/// Kept synchronous (returning void) to match the web signature so callers need
/// no platform branching; the dialog + write run as a fire-and-forget future.
void downloadBytes(
  Uint8List bytes,
  String filename, {
  String mime = 'application/octet-stream',
}) {
  // Fire-and-forget: the file picker and write are async, but the call site
  // (a button's onPressed) doesn't need the result.
  _saveAs(bytes, filename);
}

Future<void> _saveAs(Uint8List bytes, String filename) async {
  final path = await FilePicker.saveFile(
    dialogTitle: 'Save file',
    fileName: filename,
    bytes: bytes,
  );
  if (path == null) return; // user cancelled
  // On some platforms file_picker writes the bytes itself when given `bytes`;
  // where it only returns a path, write them ourselves. Writing again is
  // harmless (same content).
  await File(path).writeAsBytes(bytes);
}
