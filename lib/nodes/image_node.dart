import 'dart:convert';
import 'dart:typed_data';
import 'package:easy_nodes/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../core/image_payload.dart';
import '../core/settings.dart';

/// Source node: load an image file, preview it, and output the decoded image.
///
/// Performance note: we keep the *original* file bytes (PNG/JPG/etc.) for both
/// the preview and serialization. The browser can render those bytes directly
/// via [Image.memory] with no decode, and we only decode to pixels lazily — the
/// first time a downstream node actually pulls the image during a Run. This
/// keeps picking instant; decoding/encoding the full-res image on the main
/// isolate is expensive (zlib deflate in pure Dart) and was the source of the
/// multi-second, CPU-heavy stall on pick.
// ignore: must_be_immutable
class ImageNode extends Node {
  @override
  String get typeName => 'ImageNode';

  ImageNode({
    super.color = const Color(0xFF4E7D4E),
    super.label = 'Image',
    super.size = const Size(240, 280),
    super.inputs = const [],
    super.outputs = const [Output(label: 'Image', color: Colors.amber)],
    super.offset,
    super.uuid,
    super.key,
    this.bytes,
  });

  factory ImageNode.fromJson(Map<String, dynamic> json) {
    final data = Node.fromJson(json);
    final b64 = json['bytes'] as String?;
    return ImageNode(
      offset: data.offset,
      uuid: data.uuid,
      bytes: b64 != null ? base64Decode(b64) : null,
    );
  }

  /// Original picked file bytes (for preview + serialization).
  Uint8List? bytes;

  /// Lazily-decoded pixels, computed on first downstream pull.
  img.Image? _decoded;

  /// Decode on demand (and cache). Returns null if no image / undecodable.
  img.Image? get image => _decoded ??= (bytes == null ? null : img.decodeImage(bytes!));

  Future<void> pickImage(BuildContext context) async {
    // Capture the controller before awaiting — context may be unsafe after.
    final controller = NodeControls.of(context);
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (result == null) return;
    final picked = result.files.first.bytes;
    if (picked == null) return;

    // Store the raw bytes only — no decode, no re-encode. Decoding happens
    // lazily in `image` when the graph runs.
    bytes = picked;
    _decoded = null;
    controller?.requestUpdate();
  }

  @override
  Future<dynamic> run(BuildContext context, ExecutionContext cache) async {
    final decoded = image;
    if (decoded == null) throw Exception('Image node has no image');
    return ImagePayload(decoded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = NodeControls.of(context);
    return InkWell(
      onTap: () => pickImage(context),
      child: Container(
        width: 220,
        height: 220,
        color: Colors.black26,
        child: Stack(
          children: [
            if (bytes == null)
              Center(child: Text('Click to pick image', style: theme.textTheme.bodySmall))
            else ...[
              Positioned.fill(
                child: Image.memory(bytes!, fit: BoxFit.contain, gaplessPlayback: true),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: InkWell(
                  onTap: () {
                    bytes = null;
                    _decoded = null;
                    controller?.requestUpdate();
                  },
                  child: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    // Only embed the raw image bytes when the user has opted in (Settings →
    // "Embed images in saved config"). Off by default to keep graphs small and
    // within the localStorage quota.
    if (bytes != null && PackerSettings.embedImages) {
      json['bytes'] = base64Encode(bytes!);
    }
    return json;
  }
}
