import 'package:easy_nodes/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:channel_packer/core/graph_io.dart';
import 'package:channel_packer/state.dart';

// A node saved at a negative offset renders (Stack uses Clip.none) and can still
// be dragged (the canvas finds drag targets mathematically) but never receives
// taps, because Flutter won't hit-test a child positioned outside the canvas
// Stack's bounds. normalizeNodeOffsets() shifts everything back on-canvas on
// load. We swap FilePicker's platform with a recorder so a fired onTap is
// observable without a real dialog.
class _RecordingFilePicker extends FilePickerPlatform {
  int pickCalls = 0;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    pickCalls++;
    return null;
  }
}

Map<String, dynamic> _imageNodeJson(String uuid, double dx, double dy) => {
  'type': 'ImageNode',
  'uuid': uuid,
  'label': 'Image',
  'offset': {'dx': dx, 'dy': dy},
  'size': {'width': 240.0, 'height': 280.0},
  'color': 0xFF4E7D4E,
  'inputs': <dynamic>[],
  'outputs': [
    {'label': 'Image', 'key': null, 'color': 0xFFFFC107},
  ],
};

void main() {
  late _RecordingFilePicker picker;

  setUp(() {
    picker = _RecordingFilePicker();
    FilePickerPlatform.instance = picker;
  });

  Widget harness(NodeEditorController controller) => MaterialApp(
    home: NodeControls(
      notifier: controller,
      child: Builder(
        builder: (context) =>
            Scaffold(body: NodeCanvas(controller: controller, zoom: 0.8)),
      ),
    ),
  );

  test('normalizeNodeOffsets shifts negative offsets (and lines) on-canvas', () {
    final controller = AppState().controller;
    final a = controller.getNodeMetadata('ImageNode')!.factory(
      _imageNodeJson('a', -206.8, 263.7),
    );
    final b = controller.getNodeMetadata('PackerNode')!.factory(
      _imageNodeJson('b', 400.0, -30.0)..['type'] = 'PackerNode',
    );
    controller.nodes[a.uuid] = a;
    controller.nodes[b.uuid] = b;
    controller.connections.add(
      Connection(
        start: const Offset(-100, 280),
        end: const Offset(400, 10),
        startNode: a,
        startIndex: 0,
        endNode: b,
        endIndex: 0,
      ),
    );

    normalizeNodeOffsets(controller);

    // minX was -206.8 -> shift +246.8 to reach the 40px margin; minY -30 -> +70.
    expect(a.offset.dx, closeTo(40.0, 0.01));
    expect(b.offset.dy, closeTo(40.0, 0.01));
    expect(a.offset.dy, closeTo(263.7 + 70.0, 0.01));
    // Connection endpoints shift by the same delta so lines stay aligned.
    expect(controller.connections.first.start, const Offset(-100 + 246.8, 280 + 70));
  });

  testWidgets('negative-offset node: not tappable before, tappable after fix',
      (tester) async {
    final controller = AppState().controller;
    await tester.pumpWidget(harness(controller));

    final context = tester.element(find.byType(NodeCanvas));
    await controller.fromJson({
      'nodes': [_imageNodeJson('neg', -206.8, 60.0)],
      'connections': <dynamic>[],
    }, context);
    await tester.pumpAndSettle();

    // Before the fix: the node is left of the canvas origin -> taps don't land.
    picker.pickCalls = 0;
    await tester.tap(find.text('Click to pick image'), warnIfMissed: false);
    await tester.pump();
    expect(picker.pickCalls, 0, reason: 'off-canvas node should not be tappable');

    // After normalizing, it is on-canvas and tappable.
    normalizeNodeOffsets(controller);
    controller.requestUpdate();
    await tester.pumpAndSettle();

    picker.pickCalls = 0;
    await tester.tap(find.text('Click to pick image'), warnIfMissed: false);
    await tester.pump();
    expect(picker.pickCalls, 1, reason: 'node should be tappable after normalize');
  });
}
