import 'dart:typed_data';
import 'package:easy_nodes/index.dart';
import 'package:flutter/material.dart';

import '../core/image_ops.dart';
import '../core/image_payload.dart';
import '../widgets/node_preview.dart';

/// Convert a height/depth input into a normal map. The gradient method is
/// selectable (Sobel / Scharr / Multi-scale); plus strength, a noise pre-blur,
/// an invert-G toggle (DirectX vs OpenGL), and — in multi-scale — Detail/Large
/// weighting of the fine and coarse passes.
// ignore: must_be_immutable
class NormalMapNode extends Node {
  @override
  String get typeName => 'NormalMapNode';

  NormalMapNode({
    super.color = const Color(0xFF6E5A8F),
    super.label = 'Normal Map',
    super.size = const Size(260, 520),
    super.inputs = const [Input(label: 'Height')],
    super.outputs = const [Output(label: 'Normal', color: Colors.amber)],
    super.offset,
    super.uuid,
    super.key,
    this.method = NormalMethod.scharr,
    this.strength = 2.0,
    this.invertG = false,
    this.blur = 1,
    this.detail = 1.0,
    this.large = 1.0,
  });

  factory NormalMapNode.fromJson(Map<String, dynamic> json) {
    final data = Node.fromJson(json);
    return NormalMapNode(
      offset: data.offset,
      uuid: data.uuid,
      method: _methodFromName(json['method'] as String?),
      strength: (json['strength'] as num?)?.toDouble() ?? 2.0,
      invertG: json['invertG'] as bool? ?? false,
      blur: (json['blur'] as num?)?.toInt() ?? 1,
      detail: (json['detail'] as num?)?.toDouble() ?? 1.0,
      large: (json['large'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static NormalMethod _methodFromName(String? name) => NormalMethod.values.firstWhere(
        (m) => m.name == name,
        orElse: () => NormalMethod.scharr,
      );

  NormalMethod method;
  double strength;
  bool invertG;
  int blur;
  double detail;
  double large;

  Uint8List? _previewBytes;

  @override
  Future<dynamic> run(BuildContext context, ExecutionContext cache) async {
    final controller = NodeControls.of(context);
    final upstream = controller?.incomingNodes(this, 0) ?? const [];
    if (upstream.isEmpty) throw Exception('Normal Map node has no Height input');
    final res = await upstream.first.execute(context, cache);
    if (res is! ImagePayload) throw Exception('Height input did not produce an image');

    final out = generateNormal(
      res.image,
      method: method,
      strength: strength,
      invertG: invertG,
      blurRadius: blur,
      detail: detail,
      large: large,
    );
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Method'),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<NormalMethod>(
                isExpanded: true,
                isDense: true,
                value: method,
                onChanged: (v) {
                  if (v == null) return;
                  method = v;
                  controller?.requestUpdate();
                },
                items: const [
                  DropdownMenuItem(value: NormalMethod.sobel, child: Text('Sobel')),
                  DropdownMenuItem(value: NormalMethod.scharr, child: Text('Scharr')),
                  DropdownMenuItem(value: NormalMethod.multiScale, child: Text('Multi-scale')),
                ],
              ),
            ),
          ],
        ),
        _slider('Strength', strength, 1.0, 10.0, 90, strength.toStringAsFixed(1),
            (v) => strength = v, controller),
        _slider('Blur', blur.toDouble(), 0, 8, 8, '$blur px',
            (v) => blur = v.round(), controller),
        if (method == NormalMethod.multiScale) ...[
          _slider('Detail', detail, 0.0, 2.0, 40, detail.toStringAsFixed(2),
              (v) => detail = v, controller),
          _slider('Large', large, 0.0, 2.0, 40, large.toStringAsFixed(2),
              (v) => large = v, controller),
        ],
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

  /// A labeled slider row with a trailing value readout.
  Widget _slider(String label, double value, double min, double max, int divisions,
      String readout, ValueChanged<double> onChanged, NodeEditorController? controller) {
    return Row(
      children: [
        SizedBox(width: 56, child: Text(label)),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            value: value.clamp(min, max),
            label: readout,
            divisions: divisions,
            onChanged: (v) {
              onChanged(v);
              controller?.requestUpdate();
            },
          ),
        ),
        SizedBox(width: 40, child: Text(readout)),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['method'] = method.name;
    json['strength'] = strength;
    json['invertG'] = invertG;
    json['blur'] = blur;
    json['detail'] = detail;
    json['large'] = large;
    return json;
  }
}
