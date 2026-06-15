import 'dart:convert';
import 'dart:typed_data';
import 'package:easy_nodes/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import 'download_helper.dart';
import 'storage.dart';

/// Path to the bundled starter graph, loaded the first time a user visits with
/// no saved config of their own.
const _defaultGraphAsset = 'assets/default_graph.json';

/// Serialize the whole node graph to a JSON string.
String serializeGraph(NodeEditorController controller) => jsonEncode(controller.toJson());

/// Persist the current graph to localStorage (used by Ctrl+S and Save).
void saveGraphToStorage(NodeEditorController controller) {
  storeGraphString(serializeGraph(controller));
}

/// Download the graph as `graph.json` *and* persist it to localStorage, so the
/// setup is both exportable and auto-restored on the next page load.
void saveGraph(NodeEditorController controller) {
  final jsonStr = serializeGraph(controller);
  storeGraphString(jsonStr);
  downloadBytes(
    Uint8List.fromList(utf8.encode(jsonStr)),
    'graph.json',
    mime: 'application/json',
  );
}

/// Apply a graph JSON string to [controller] (clears the existing graph first).
Future<void> _applyGraph(
  NodeEditorController controller,
  BuildContext context,
  String jsonStr,
) async {
  final json = jsonDecode(jsonStr) as Map<String, dynamic>;
  controller.clear();
  if (!context.mounted) return;
  await controller.fromJson(json, context);
  controller.requestUpdate();
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
  if (!context.mounted) return false;

  await _applyGraph(controller, context, utf8.decode(bytes));
  return true;
}

/// Initial graph on page load: the user's saved config from localStorage if it
/// exists, otherwise the bundled default starter graph.
Future<void> loadInitialGraph(NodeEditorController controller, BuildContext context) async {
  final stored = loadStoredGraph();
  final jsonStr = stored ?? await rootBundle.loadString(_defaultGraphAsset);
  if (!context.mounted) return;
  await _applyGraph(controller, context, jsonStr);
}
