import 'dart:convert';
import 'dart:typed_data';
import 'package:easy_nodes/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../core/image_payload.dart';

/// Source node: load an image file, preview it, and output the decoded image.
///
/// The picked image is re-encoded to PNG so it can be both previewed and
/// embedded (base64) in the saved graph for full round-trip restore.
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
    this.pngBytes,
  }) {
    if (pngBytes != null) image = img.decodePng(pngBytes!);
  }

  factory ImageNode.fromJson(Map<String, dynamic> json) {
    final data = Node.fromJson(json);
    final b64 = json['bytes'] as String?;
    return ImageNode(
      offset: data.offset,
      uuid: data.uuid,
      pngBytes: b64 != null ? base64Decode(b64) : null,
    );
  }

  /// PNG-encoded bytes (for preview + serialization).
  Uint8List? pngBytes;

  /// Decoded image (for downstream processing).
  img.Image? image;

  Future<void> pickImage(BuildContext context) async {
    // Capture the controller before awaiting — context may be unsafe after.
    final controller = NodeControls.of(context);
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (result == null) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    image = decoded;
    // Normalize to PNG for preview + serialization regardless of source format.
    pngBytes = Uint8List.fromList(img.encodePng(decoded));
    controller?.requestUpdate();
  }

  @override
  Future<dynamic> run(BuildContext context, ExecutionContext cache) async {
    if (image == null) throw Exception('Image node has no image');
    return ImagePayload(image!);
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
            if (pngBytes == null)
              Center(child: Text('Click to pick image', style: theme.textTheme.bodySmall))
            else ...[
              Positioned.fill(
                child: Image.memory(pngBytes!, fit: BoxFit.contain, gaplessPlayback: true),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: InkWell(
                  onTap: () {
                    image = null;
                    pngBytes = null;
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
    if (pngBytes != null) json['bytes'] = base64Encode(pngBytes!);
    return json;
  }
}
