import 'package:easy_nodes/index.dart';
import 'package:flutter/material.dart';

import 'nodes/ao_node.dart';
import 'nodes/depth_node.dart';
import 'nodes/image_node.dart';
import 'nodes/normal_map_node.dart';
import 'nodes/packer_node.dart';
import 'nodes/roughness_node.dart';

/// App-wide state: owns the [NodeEditorController] and registers the node types
/// so they appear in the canvas right-click menu and the toolbar add menu.
class AppState extends ChangeNotifier {
  final NodeEditorController controller = NodeEditorController();

  AppState() {
    _registerNodeTypes();
  }

  void _registerNodeTypes() {
    controller.registerNodeType(
      NodeTypeMetadata(
        typeName: 'ImageNode',
        displayName: 'Image',
        description: 'Load an image file',
        icon: Icons.image,
        factory: (json) => ImageNode.fromJson(json),
      ),
    );
    controller.registerNodeType(
      NodeTypeMetadata(
        typeName: 'PackerNode',
        displayName: 'Packer',
        description: 'Pack AO/Roughness/Metallic into RGBA',
        icon: Icons.layers,
        factory: (json) => PackerNode.fromJson(json),
      ),
    );
    controller.registerNodeType(
      NodeTypeMetadata(
        typeName: 'DepthNode',
        displayName: 'Depth',
        description: 'Albedo -> height/depth (Depth Anything V2)',
        icon: Icons.height,
        factory: (json) => DepthNode.fromJson(json),
      ),
    );
    controller.registerNodeType(
      NodeTypeMetadata(
        typeName: 'NormalMapNode',
        displayName: 'Normal Map',
        description: 'Height -> normal map (Sobel)',
        icon: Icons.terrain,
        factory: (json) => NormalMapNode.fromJson(json),
      ),
    );
    controller.registerNodeType(
      NodeTypeMetadata(
        typeName: 'AONode',
        displayName: 'Ambient Occlusion',
        description: 'Height -> ambient occlusion (ORM red)',
        icon: Icons.blur_on,
        factory: (json) => AONode.fromJson(json),
      ),
    );
    controller.registerNodeType(
      NodeTypeMetadata(
        typeName: 'RoughnessNode',
        displayName: 'Roughness',
        description: 'Color/height -> roughness estimate (ORM green)',
        icon: Icons.grain,
        factory: (json) => RoughnessNode.fromJson(json),
      ),
    );
  }
}

/// Exposes [AppState] to the widget tree.
class Inherited extends InheritedNotifier<AppState> {
  const Inherited({
    required super.child,
    super.key,
    required AppState super.notifier,
  });

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Inherited>()!.notifier!;
}
