// The node execution model (easy_nodes) is a pull graph: a node must pass its
// BuildContext to upstream execute() calls across awaits. That is by design.
// ignore_for_file: use_build_context_synchronously
import 'dart:typed_data';
import 'package:easy_nodes/index.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../core/image_ops.dart';
import '../core/image_payload.dart';
import '../widgets/node_preview.dart';

/// Input port indices (fixed, labeled by semantic).
const _inputLabels = ['AO', 'Roughness', 'Metallic', 'Alpha'];

/// Combine up to four grayscale inputs into one RGBA image. Each output channel
/// (R/G/B/A) has a dropdown choosing which input feeds it. Default mapping is
/// ORM / glTF-compatible: R←AO, G←Roughness, B←Metallic, A←none.
// ignore: must_be_immutable
class PackerNode extends Node {
  @override
  String get typeName => 'PackerNode';

  PackerNode({
    super.color = const Color(0xFF3C6E8F),
    super.label = 'Packer',
    super.size = const Size(260, 430),
    super.inputs = const [
      Input(label: 'AO'),
      Input(label: 'Roughness'),
      Input(label: 'Metallic'),
      Input(label: 'Alpha'),
    ],
    super.outputs = const [Output(label: 'Packed', color: Colors.amber)],
    super.offset,
    super.uuid,
    super.key,
    Map<String, int?>? sel,
  }) : sel = sel ?? {'R': 0, 'G': 1, 'B': 2, 'A': null};

  factory PackerNode.fromJson(Map<String, dynamic> json) {
    final data = Node.fromJson(json);
    Map<String, int?>? sel;
    final s = json['sel'] as Map<String, dynamic>?;
    if (s != null) {
      sel = {
        for (final k in ['R', 'G', 'B', 'A']) k: s[k] as int?,
      };
    }
    return PackerNode(offset: data.offset, uuid: data.uuid, sel: sel);
  }

  /// Output channel -> input port index (or null for "none").
  final Map<String, int?> sel;

  Uint8List? _previewBytes;

  Future<img.Image?> _channelImage(
    BuildContext context,
    ExecutionContext cache,
    NodeEditorController? controller,
    int? inputIndex,
  ) async {
    if (inputIndex == null) return null;
    final upstream = controller?.incomingNodes(this, inputIndex) ?? const [];
    if (upstream.isEmpty) return null;
    final res = await upstream.first.execute(context, cache);
    return res is ImagePayload ? res.image : null;
  }

  @override
  Future<dynamic> run(BuildContext context, ExecutionContext cache) async {
    // Capture the controller before awaiting so we don't reach across async gaps.
    final controller = NodeControls.of(context);
    final r = await _channelImage(context, cache, controller, sel['R']);
    final g = await _channelImage(context, cache, controller, sel['G']);
    final b = await _channelImage(context, cache, controller, sel['B']);
    final a = await _channelImage(context, cache, controller, sel['A']);

    final out = packRGBA(r: r, g: g, b: b, a: a);
    final payload = ImagePayload(out);
    _previewBytes = payload.png;
    controller?.requestUpdate();
    return payload;
  }

  @override
  Widget build(BuildContext context) {
    final controller = NodeControls.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final channel in const ['R', 'G', 'B', 'A'])
          _ChannelRow(
            channel: channel,
            value: sel[channel],
            onChanged: (v) {
              sel[channel] = v;
              controller?.requestUpdate();
            },
          ),
        const SizedBox(height: 6),
        NodePreview(bytes: _previewBytes, filename: 'packed.png'),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['sel'] = sel;
    return json;
  }
}

class _ChannelRow extends StatelessWidget {
  final String channel;
  final int? value;
  final ValueChanged<int?> onChanged;

  const _ChannelRow({
    required this.channel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              channel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButton<int?>(
              isExpanded: true,
              isDense: true,
              value: value,
              onChanged: onChanged,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('None')),
                for (var i = 0; i < _inputLabels.length; i++)
                  DropdownMenuItem<int?>(
                    value: i,
                    child: Text(_inputLabels[i]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
