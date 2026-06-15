import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../core/download_helper.dart';

/// Reusable preview area for compute nodes: shows the last computed PNG (or a
/// placeholder) plus a "Download PNG" button. [bytes] are the PNG-encoded
/// output; [filename] is used for the download.
class NodePreview extends StatelessWidget {
  final Uint8List? bytes;
  final String filename;
  final String placeholder;
  final double size;

  const NodePreview({
    super.key,
    required this.bytes,
    required this.filename,
    this.placeholder = 'Run to preview',
    this.size = 240,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          color: Colors.black26,
          alignment: Alignment.center,
          child: bytes == null
              ? Text(placeholder, style: theme.textTheme.bodySmall)
              : Image.memory(bytes!, width: size, height: size, fit: BoxFit.contain, gaplessPlayback: true),
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: bytes == null ? null : () => downloadBytes(bytes!, filename, mime: 'image/png'),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download PNG'),
        ),
      ],
    );
  }
}
