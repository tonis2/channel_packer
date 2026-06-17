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
String serializeGraph(NodeEditorController controller) =>
    jsonEncode(controller.toJson());

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

/// Margin (canvas px) to keep the top-left-most node away from the origin after
/// a load, so it stays comfortably inside the hit-testable canvas.
const double _loadMargin = 40.0;

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
  normalizeNodeOffsets(controller);
  controller.requestUpdate();
}

/// Shift every node (and connection endpoint) so no node sits at a negative /
/// off-canvas coordinate after loading.
///
/// The canvas only grows its size for positive overflow, and Flutter won't
/// hit-test a child positioned outside the canvas Stack's bounds — so a saved
/// node with a negative offset renders and can still be dragged (the canvas
/// finds drag targets mathematically) but never receives taps. Loading can
/// produce such offsets (e.g. a node previously dragged to the left); a uniform
/// translation brings everything on-canvas while preserving the layout, and —
/// because lines cache absolute endpoints — those are shifted by the same delta.
void normalizeNodeOffsets(NodeEditorController controller) {
  final nodes = controller.nodes.values;
  if (nodes.isEmpty) return;

  double minX = double.infinity, minY = double.infinity;
  for (final n in nodes) {
    if (n.offset.dx < minX) minX = n.offset.dx;
    if (n.offset.dy < minY) minY = n.offset.dy;
  }
  final shiftX = minX < _loadMargin ? _loadMargin - minX : 0.0;
  final shiftY = minY < _loadMargin ? _loadMargin - minY : 0.0;
  if (shiftX == 0 && shiftY == 0) return;

  final delta = Offset(shiftX, shiftY);
  for (final n in nodes) {
    n.offset = n.offset + delta;
  }
  for (final c in controller.connections) {
    c.start = c.start + delta;
    c.end = c.end + delta;
  }
}

/// Pick a previously-saved `graph.json` and restore it into [controller].
///
/// WASM-safe: reads `result.files.first.bytes` (never `.path`, which is null on
/// web). Returns true if a graph was loaded.
Future<bool> loadGraph(
  NodeEditorController controller,
  BuildContext context,
) async {
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
Future<void> loadInitialGraph(
  NodeEditorController controller,
  BuildContext context,
) async {
  final stored = loadStoredGraph();
  final jsonStr = stored ?? await rootBundle.loadString(_defaultGraphAsset);
  if (!context.mounted) return;
  await _applyGraph(controller, context, jsonStr);
}
