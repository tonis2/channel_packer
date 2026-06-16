import 'dart:typed_data';
import 'package:easy_nodes/index.dart';
import 'package:flutter/material.dart';

import '../core/image_ops.dart';
import '../core/image_payload.dart';
import '../widgets/node_preview.dart';

/// Approximate an ambient-occlusion map from a height/depth input. Valleys
/// (pixels below the local average height) darken; peaks and flats stay white.
/// Radius sets the occlusion scale, Strength the darkening, Smooth softens the
/// result. The output feeds the Packer's AO port (R in ORM).
// ignore: must_be_immutable
class AONode extends Node {
  @override
  String get typeName => 'AONode';

  AONode({
    super.color = const Color(0xFF6E8F5A),
    super.backgroundColor = const Color(0xFF2C2C31),
    super.label = 'Ambient Occlusion',
    super.size = const Size(260, 470),
    super.inputs = const [Input(label: 'Height')],
    super.outputs = const [Output(label: 'AO', color: Colors.amber)],
    super.offset,
    super.uuid,
    super.key,
    this.radius = 16,
    this.strength = 1.0,
    this.smooth = 0,
  });

  factory AONode.fromJson(Map<String, dynamic> json) {
    final data = Node.fromJson(json);
    return AONode(
      offset: data.offset,
      uuid: data.uuid,
      radius: (json['radius'] as num?)?.toInt() ?? 16,
      strength: (json['strength'] as num?)?.toDouble() ?? 1.0,
      smooth: (json['smooth'] as num?)?.toInt() ?? 0,
    );
  }

  int radius;
  double strength;
  int smooth;

  Uint8List? _previewBytes;

  @override
  Future<dynamic> run(BuildContext context, ExecutionContext cache) async {
    final controller = NodeControls.of(context);
    final upstream = controller?.incomingNodes(this, 0) ?? const [];
    if (upstream.isEmpty) throw Exception('AO node has no Height input');
    final res = await upstream.first.execute(context, cache);
    if (res is! ImagePayload) {
      throw Exception('Height input did not produce an image');
    }

    final out = generateAO(
      res.image,
      radius: radius,
      strength: strength,
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
          'Radius',
          radius.toDouble(),
          1,
          64,
          63,
          '$radius px',
          (v) => radius = v.round(),
          controller,
        ),
        _slider(
          'Strength',
          strength,
          0.0,
          4.0,
          80,
          strength.toStringAsFixed(1),
          (v) => strength = v,
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
        const SizedBox(height: 6),
        NodePreview(bytes: _previewBytes, filename: 'ao.png'),
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
    json['radius'] = radius;
    json['strength'] = strength;
    json['smooth'] = smooth;
    return json;
  }
}
