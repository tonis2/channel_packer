import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// The value that flows between nodes during execution.
///
/// Wraps a decoded [img.Image] and lazily caches its PNG-encoded bytes so the
/// same result can be both previewed (via `Image.memory`) and downloaded
/// without re-encoding.
class ImagePayload {
  final img.Image image;
  Uint8List? _png;

  ImagePayload(this.image);

  /// PNG bytes for the wrapped image, encoded once and cached.
  Uint8List get png => _png ??= Uint8List.fromList(img.encodePng(image));
}
