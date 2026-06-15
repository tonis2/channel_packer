import 'package:easy_nodes/index.dart';
import 'package:flutter/material.dart';

import '../core/graph_io.dart';
import '../state.dart';
import '../widgets/add_node_menu.dart';

/// Main screen: the node canvas plus a toolbar to add nodes, run the graph,
/// and save/load it.
class EditorPage extends StatelessWidget {
  const EditorPage({super.key});

  Future<void> _run(BuildContext context, NodeEditorController controller) async {
    try {
      await controller.executeAllEndpoints(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Run failed: $e')));
      }
    }
  }

  Future<void> _load(BuildContext context, NodeEditorController controller) async {
    try {
      await loadGraph(controller, context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Inherited.of(context).controller;
    return NodeControls(
      notifier: controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Channel Packer'),
          actions: [
            AddNodeMenu(controller: controller),
            IconButton(
              tooltip: 'Run',
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _run(context, controller),
            ),
            IconButton(
              tooltip: 'Save graph',
              icon: const Icon(Icons.save),
              onPressed: () => saveGraph(controller),
            ),
            IconButton(
              tooltip: 'Load graph',
              icon: const Icon(Icons.folder_open),
              onPressed: () => _load(context, controller),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: NodeCanvas(
          controller: controller,
          zoom: 0.8,
          backgroundColor: const Color(0xFF1E1E1E),
          lineColor: const Color(0x22FFFFFF),
          connectionColor: const Color(0xFFA6A4A4),
        ),
      ),
    );
  }
}
