import 'dart:typed_data';
import 'package:easy_nodes/index.dart';
import 'package:flutter/material.dart';

import '../core/image_ops.dart';
import '../core/image_payload.dart';
import '../widgets/node_preview.dart';

/// Convert a height/depth input into a normal map (Sobel), with a strength
/// slider and an invert-G toggle for DirectX vs OpenGL conventions.
// ignore: must_be_immutable
class NormalMapNode extends Node {
  @override
  String get typeName => 'NormalMapNode';

  NormalMapNode({
    super.color = const Color(0xFF6E5A8F),
    super.label = 'Normal Map',
    super.size = const Size(260, 400),
    super.inputs = const [Input(label: 'Height')],
    super.outputs = const [Output(label: 'Normal', color: Colors.amber)],
    super.offset,
    super.uuid,
    super.key,
    this.strength = 2.0,
    this.invertG = false,
    this.blur = 1,
  });

  factory NormalMapNode.fromJson(Map<String, dynamic> json) {
    final data = Node.fromJson(json);
    return NormalMapNode(
      offset: data.offset,
      uuid: data.uuid,
      strength: (json['strength'] as num?)?.toDouble() ?? 2.0,
      invertG: json['invertG'] as bool? ?? false,
      blur: (json['blur'] as num?)?.toInt() ?? 1,
    );
  }

  double strength;
  bool invertG;
  int blur;

  Uint8List? _previewBytes;

  @override
  Future<dynamic> run(BuildContext context, ExecutionContext cache) async {
    final controller = NodeControls.of(context);
    final upstream = controller?.incomingNodes(this, 0) ?? const [];
    if (upstream.isEmpty) throw Exception('Normal Map node has no Height input');
    final res = await upstream.first.execute(context, cache);
    if (res is! ImagePayload) throw Exception('Height input did not produce an image');

    final out = sobelNormal(res.image, strength: strength, invertG: invertG, blurRadius: blur);
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
        Row(
          children: [
            const Text('Strength'),
            Expanded(
              child: Slider(
                min: 1.0,
                max: 10.0,
                value: strength.clamp(1.0, 10.0),
                label: strength.toStringAsFixed(1),
                divisions: 90,
                onChanged: (v) {
                  strength = v;
                  controller?.requestUpdate();
                },
              ),
            ),
            SizedBox(width: 34, child: Text(strength.toStringAsFixed(1))),
          ],
        ),
        Row(
          children: [
            const Text('Blur'),
            Expanded(
              child: Slider(
                min: 0,
                max: 8,
                value: blur.clamp(0, 8).toDouble(),
                label: '$blur',
                divisions: 8,
                onChanged: (v) {
                  blur = v.round();
                  controller?.requestUpdate();
                },
              ),
            ),
            SizedBox(width: 34, child: Text('$blur px')),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: invertG,
              onChanged: (v) {
                invertG = v ?? false;
                controller?.requestUpdate();
              },
            ),
            const Text('Invert G (DirectX)'),
          ],
        ),
        const SizedBox(height: 6),
        NodePreview(bytes: _previewBytes, filename: 'normal.png'),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['strength'] = strength;
    json['invertG'] = invertG;
    json['blur'] = blur;
    return json;
  }
}
