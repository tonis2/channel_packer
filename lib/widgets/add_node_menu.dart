import 'package:easy_nodes/index.dart';
import 'package:flutter/material.dart';

/// Toolbar button that lists registered node types and adds the chosen one to
/// the canvas. (The canvas also supports right-click to add at a position.)
class AddNodeMenu extends StatelessWidget {
  final NodeEditorController controller;

  const AddNodeMenu({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NodeTypeMetadata>(
      tooltip: 'Add node',
      icon: const Icon(Icons.add),
      onSelected: (meta) {
        final node = meta.factory({'label': meta.displayName});
        // Drop new nodes into a roughly central, slightly staggered spot.
        final offset = Offset(400.0 + controller.nodes.length * 30, 200.0 + controller.nodes.length * 20);
        node.init(context).then((_) => controller.addNode(node, offset));
      },
      itemBuilder: (context) => [
        for (final meta in controller.registeredNodeTypes)
          PopupMenuItem<NodeTypeMetadata>(
            value: meta,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(meta.icon),
              title: Text(meta.displayName),
              subtitle: Text(meta.description),
            ),
          ),
      ],
    );
  }
}
