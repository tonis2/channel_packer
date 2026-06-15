import 'package:easy_nodes/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/graph_io.dart';
import '../core/settings.dart';
import '../core/storage.dart';
import '../state.dart';
import '../widgets/add_node_menu.dart';

/// Main screen: the node canvas plus a toolbar to add nodes, run the graph,
/// and save/load it. On first build it restores the user's saved graph from
/// localStorage (or the bundled default), and Ctrl/Cmd+S quick-saves.
class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  bool _restoredInitial = false;

  Future<void> _run(BuildContext context, NodeEditorController controller) async {
    try {
      await controller.executeAllEndpoints(context);
    } catch (e) {
      if (context.mounted) _notify(context, 'Run failed: $e');
    }
  }

  Future<void> _load(BuildContext context, NodeEditorController controller) async {
    try {
      await loadGraph(controller, context);
    } catch (e) {
      if (context.mounted) _notify(context, 'Load failed: $e');
    }
  }

  /// Quick-save to localStorage (Ctrl/Cmd+S) with a small confirmation toast.
  void _quickSave(BuildContext context, NodeEditorController controller) {
    saveGraphToStorage(controller);
    _notify(context, 'Node config saved');
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        width: 240,
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final controller = Inherited.of(context).controller;
    return NodeControls(
      notifier: controller,
      // The Builder gives the Scaffold (and its callbacks) a BuildContext that
      // lives below NodeControls, which graph execution/restore both require.
      child: Builder(
        builder: (context) {
          // Restore the saved/default graph once, after the first frame (so the
          // node tree exists and node.init has a valid descendant context).
          if (!_restoredInitial) {
            _restoredInitial = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) loadInitialGraph(controller, context);
            });
          }
          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                  () => _quickSave(context, controller),
              const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                  () => _quickSave(context, controller),
            },
            child: Focus(
              autofocus: true,
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
                      tooltip: 'Save graph (download + store)',
                      icon: const Icon(Icons.save),
                      onPressed: () {
                        saveGraph(controller);
                        _notify(context, 'Node config saved');
                      },
                    ),
                    IconButton(
                      tooltip: 'Load graph from file',
                      icon: const Icon(Icons.folder_open),
                      onPressed: () => _load(context, controller),
                    ),
                    const _SettingsMenu(),
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
            ),
          );
        },
      ),
    );
  }
}

/// App settings dropdown. Currently just the "embed images" toggle, persisted
/// to localStorage so it survives reloads.
class _SettingsMenu extends StatefulWidget {
  const _SettingsMenu();

  @override
  State<_SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<_SettingsMenu> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings),
      itemBuilder: (context) => [
        CheckedPopupMenuItem<String>(
          value: 'embed',
          checked: PackerSettings.embedImages,
          child: const Text('Embed images in saved config'),
        ),
      ],
      onSelected: (value) {
        if (value == 'embed') {
          setState(() => PackerSettings.embedImages = !PackerSettings.embedImages);
          storeEmbedImages(PackerSettings.embedImages);
        }
      },
    );
  }
}
