import 'dart:typed_data';
import 'package:easy_nodes/index.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../core/depth_runner.dart';
import '../core/image_payload.dart';
import '../core/settings.dart';
import '../widgets/node_preview.dart';

/// Generate a height/depth map from an albedo input by shelling out to the
/// bundled Depth Anything V2 `depth` binary.
///
/// Two modes: "Texture height" (the binary's `--height` pipeline — best for
/// tiling material maps, with Albedo/Flatten/Detail/Detrend tuning) and "Scene
/// depth" (raw monocular depth). Resolution trades sharpness for VRAM. The model
/// weights are user-supplied via Settings; the binary is bundled (or overridden).
///
/// The binary reloads the model + Vulkan on every call (a few seconds), so the
/// result is cached on (input image identity + argument signature): re-running
/// the graph without touching this node or its input reuses the last output.
// ignore: must_be_immutable
class DepthNode extends Node {
  @override
  String get typeName => 'DepthNode';

  DepthNode({
    super.color = const Color(0xFF3A6B8F),
    super.backgroundColor = const Color(0xFF2C2C31),
    super.label = 'Depth',
    super.size = const Size(260, 560),
    super.inputs = const [Input(label: 'Albedo')],
    super.outputs = const [Output(label: 'Height', color: Colors.amber)],
    super.offset,
    super.uuid,
    super.key,
    this.mode = DepthMode.textureHeight,
    this.albedo = 1.0,
    this.flatten = 0.5,
    this.detail = 0.3,
    this.detrend = 0.1,
    this.res = 1036,
  });

  factory DepthNode.fromJson(Map<String, dynamic> json) {
    final data = Node.fromJson(json);
    return DepthNode(
      offset: data.offset,
      uuid: data.uuid,
      mode: _modeFromName(json['mode'] as String?),
      albedo: (json['albedo'] as num?)?.toDouble() ?? 0.1,
      flatten: (json['flatten'] as num?)?.toDouble() ?? 0.3,
      detail: (json['detail'] as num?)?.toDouble() ?? 0.08,
      detrend: (json['detrend'] as num?)?.toDouble() ?? 0.2,
      res: (json['res'] as num?)?.toInt() ?? 1036,
    );
  }

  static DepthMode _modeFromName(String? name) => DepthMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => DepthMode.textureHeight,
  );

  DepthMode mode;
  double albedo;
  double flatten;
  double detail;
  double detrend;
  int res;

  Uint8List? _previewBytes;

  // True while the binary is actually running, so the node can show a spinner.
  bool _running = false;

  // One-shot result cache: skip re-spawning the binary when neither the upstream
  // image nor the arguments changed since the last run.
  Object? _cacheImageKey;
  String? _cacheArgKey;
  ImagePayload? _cached;

  /// The binary flags for the current settings (everything after the in/out paths).
  List<String> _flags() {
    String f(double v) => v.toStringAsFixed(3);
    if (mode == DepthMode.sceneDepth) return ['--res', '$res'];
    return [
      '--height',
      '--albedo',
      f(albedo),
      '--flatten',
      f(flatten),
      '--detail',
      f(detail),
      '--detrend',
      f(detrend),
      '--res',
      '$res',
    ];
  }

  @override
  Future<dynamic> run(BuildContext context, ExecutionContext cache) async {
    final controller = NodeControls.of(context);
    final upstream = controller?.incomingNodes(this, 0) ?? const [];
    if (upstream.isEmpty) {
      throw Exception('Depth node has no Albedo input');
    }
    final res0 = await upstream.first.execute(context, cache);
    if (res0 is! ImagePayload) {
      throw Exception('Albedo input did not produce an image');
    }

    final flags = _flags();
    final argKey = flags.join(' ');
    // ImageNode caches its decoded image, so an unchanged upstream yields the
    // same object identity -> we can skip the (slow) binary call.
    final imageKey = identityHashCode(res0.image);
    if (_cached != null &&
        _cacheArgKey == argKey &&
        _cacheImageKey == imageKey) {
      _previewBytes = _cached!.png;
      controller?.requestUpdate();
      return _cached!;
    }

    final modelPath = PackerSettings.depthModelPath;
    if (modelPath == null || modelPath.isEmpty) {
      throw Exception(
        'No depth model set. Open Settings → "Set depth model…" and pick '
        'depth_anything_v2_vits_fp32.safetensors (download it first).',
      );
    }
    final binaryPath = resolveDepthBinary();
    if (binaryPath == null) {
      throw Exception(
        'depth binary not found. It ships in the app bundle (lib/depth) — '
        'try reinstalling the app.',
      );
    }

    _running = true;
    controller?.requestUpdate();
    final Uint8List outPng;
    try {
      outPng = await runDepth(
        binaryPath: binaryPath,
        modelPath: modelPath,
        inputPng: res0.png,
        flags: flags,
      );
    } finally {
      _running = false;
      controller?.requestUpdate();
    }
    final decoded = img.decodeImage(outPng);
    if (decoded == null) throw Exception('depth output was not a valid image');

    final payload = ImagePayload(decoded);
    _previewBytes = payload.png;
    _cacheImageKey = imageKey;
    _cacheArgKey = argKey;
    _cached = payload;
    controller?.requestUpdate();
    return payload;
  }

  @override
  Widget build(BuildContext context) {
    final controller = NodeControls.of(context);
    final texture = mode == DepthMode.textureHeight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Mode'),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<DepthMode>(
                isExpanded: true,
                isDense: true,
                value: mode,
                onChanged: (v) {
                  if (v == null) return;
                  mode = v;
                  controller?.requestUpdate();
                },
                items: const [
                  DropdownMenuItem(
                    value: DepthMode.textureHeight,
                    child: Text('Texture height'),
                  ),
                  DropdownMenuItem(
                    value: DepthMode.sceneDepth,
                    child: Text('Scene depth'),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Tooltip(
              message:
                  'Resolution the model processes the albedo at internally — a '
                  'detail/sharpness knob, not the output size. The height map is '
                  'always returned at the albedo\'s resolution. Higher = sharper '
                  'surface detail but more GPU VRAM (shown per option).',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Detail res'),
                  SizedBox(width: 3),
                  Icon(Icons.info_outline, size: 13, color: Colors.white38),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                isDense: true,
                value: res,
                onChanged: (v) {
                  if (v == null) return;
                  res = v;
                  controller?.requestUpdate();
                },
                items: const [
                  DropdownMenuItem(
                    value: 518,
                    child: Text('518  ·  ~45 MB VRAM'),
                  ),
                  DropdownMenuItem(
                    value: 1036,
                    child: Text('1036  ·  ~720 MB VRAM'),
                  ),
                  DropdownMenuItem(
                    value: 1554,
                    child: Text('1554  ·  ~3.6 GB VRAM'),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (texture) ...[
          _slider(
            'Albedo',
            albedo,
            0.0,
            1.0,
            100,
            albedo.toStringAsFixed(2),
            (v) => albedo = v,
            controller,
          ),
          _slider(
            'Flatten',
            flatten,
            0.0,
            1.0,
            100,
            flatten.toStringAsFixed(2),
            (v) => flatten = v,
            controller,
          ),
          _slider(
            'Detail',
            detail,
            0.0,
            1.0,
            100,
            detail.toStringAsFixed(2),
            (v) => detail = v,
            controller,
          ),
          _slider(
            'Detrend',
            detrend,
            0.02,
            0.5,
            96,
            detrend.toStringAsFixed(2),
            (v) => detrend = v,
            controller,
          ),
        ],
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            NodePreview(bytes: _previewBytes, filename: 'depth.png'),
            if (_running)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xCC1E1E22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Generating…',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// A labeled slider row with a trailing value readout.
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
    json['mode'] = mode.name;
    json['albedo'] = albedo;
    json['flatten'] = flatten;
    json['detail'] = detail;
    json['detrend'] = detrend;
    json['res'] = res;
    return json;
  }
}

enum DepthMode { textureHeight, sceneDepth }
