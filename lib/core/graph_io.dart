import 'dart:convert';
import 'dart:typed_data';
import 'package:easy_nodes/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import 'download_helper.dart';

/// Serialize the whole node graph and download it as `graph.json`.
void saveGraph(NodeEditorController controller) {
  final jsonStr = jsonEncode(controller.toJson());
  downloadBytes(
    Uint8List.fromList(utf8.encode(jsonStr)),
    'graph.json',
    mime: 'application/json',
  );
}

/// Pick a previously-saved `graph.json` and restore it into [controller].
///
/// WASM-safe: reads `result.files.first.bytes` (never `.path`, which is null on
/// web). Returns true if a graph was loaded.
Future<bool> loadGraph(NodeEditorController controller, BuildContext context) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    withData: true,
  );
  if (result == null) return false;
  final bytes = result.files.first.bytes;
  if (bytes == null) return false;

  final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  controller.clear();
  if (!context.mounted) return false;
  await controller.fromJson(json, context);
  controller.requestUpdate();
  return true;
}
