import 'dart:typed_data';
import 'package:easy_nodes/index.dart';
import 'package:flutter/material.dart';

import '../core/image_ops.dart';
import '../core/image_payload.dart';
import '../widgets/node_preview.dart';

/// Estimate a roughness map from a color (albedo) or height input. Surface
/// detail raises roughness around a base level; smooth areas stay near base.
/// Base sets the flat level, Detail the scale, Intensity the variation, Invert
/// flips it. The output feeds the Packer's Roughness port (G in ORM).
// ignore: must_be_immutable
class RoughnessNode extends Node {
  @override
  String get typeName => 'RoughnessNode';

  RoughnessNode({
    super.color = const Color(0xFF8F7A5A),
    super.backgroundColor = const Color(0xFF2C2C31),
    super.label = 'Roughness',
    super.size = const Size(260, 540),
    super.inputs = const [Input(label: 'Color/Height')],
    super.outputs = const [Output(label: 'Roughness', color: Colors.amber)],
    super.offset,
    super.uuid,
    super.key,
    this.radius = 4,
    this.intensity = 2.0,
    this.base = 0.5,
    this.invert = false,
    this.smooth = 0,
  });

  factory RoughnessNode.fromJson(Map<String, dynamic> json) {
    final data = Node.fromJson(json);
    return RoughnessNode(
      offset: data.offset,
      uuid: data.uuid,
      radius: (json['radius'] as num?)?.toInt() ?? 4,
      intensity: (json['intensity'] as num?)?.toDouble() ?? 2.0,
      base: (json['base'] as num?)?.toDouble() ?? 0.5,
      invert: json['invert'] as bool? ?? false,
      smooth: (json['smooth'] as num?)?.toInt() ?? 0,
    );
  }

  int radius;
  double intensity;
  double base;
  bool invert;
  int smooth;

  Uint8List? _previewBytes;

  @override
  Future<dynamic> run(BuildContext context, ExecutionContext cache) async {
    final controller = NodeControls.of(context);
    final upstream = controller?.incomingNodes(this, 0) ?? const [];
    if (upstream.isEmpty) throw Exception('Roughness node has no input');
    final res = await upstream.first.execute(context, cache);
    if (res is! ImagePayload) throw Exception('Input did not produce an image');

    final out = generateRoughness(
      res.image,
      radius: radius,
      intensity: intensity,
      base: base,
      invert: invert,
      smooth: smooth,
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
        _slider(
          'Base',
          base,
          0.0,
          1.0,
          100,
          base.toStringAsFixed(2),
          (v) => base = v,
          controller,
        ),
        _slider(
          'Detail',
          radius.toDouble(),
          1,
          32,
          31,
          '$radius px',
          (v) => radius = v.round(),
          controller,
        ),
        _slider(
          'Intensity',
          intensity,
          0.0,
          8.0,
          80,
          intensity.toStringAsFixed(1),
          (v) => intensity = v,
          controller,
        ),
        _slider(
          'Smooth',
          smooth.toDouble(),
          0,
          8,
          8,
          '$smooth px',
          (v) => smooth = v.round(),
          controller,
        ),
        Row(
          children: [
            Checkbox(
              value: invert,
              onChanged: (v) {
                invert = v ?? false;
                controller?.requestUpdate();
              },
            ),
            const Text('Invert (detail = smoother)'),
          ],
        ),
        const SizedBox(height: 6),
        NodePreview(bytes: _previewBytes, filename: 'roughness.png'),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    String readout,
    ValueChanged<double> onChanged,
    NodeEditorController? controller,
  ) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
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
    json['radius'] = radius;
    json['intensity'] = intensity;
    json['base'] = base;
    json['invert'] = invert;
    json['smooth'] = smooth;
    return json;
  }
}
