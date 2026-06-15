import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Pure image-processing helpers shared by the nodes. None of these touch
/// Flutter/BuildContext so they stay easy to test and reuse.

/// Read a pixel as an 8-bit grayscale value (0..255).
///
/// Texture maps (AO/roughness/metallic/height) are already grayscale data, so
/// we take the first/red channel directly (like the reference packer) rather
/// than recomputing perceptual luminance — the latter mis-weights single-channel
/// images. `rNormalized` is bit-depth agnostic (0..1).
int readGray(img.Pixel p) =>
    (p.rNormalized.toDouble() * 255.0).round().clamp(0, 255);

/// The common output size for a set of (possibly null) inputs: the max width
/// and height across all provided images. Falls back to 1x1 when all null.
({int w, int h}) commonSize(List<img.Image?> imgs) {
  var w = 0;
  var h = 0;
  for (final i in imgs) {
    if (i == null) continue;
    if (i.width > w) w = i.width;
    if (i.height > h) h = i.height;
  }
  return (w: w == 0 ? 1 : w, h: h == 0 ? 1 : h);
}

img.Image _resizeTo(img.Image src, int w, int h) =>
    (src.width == w && src.height == h) ? src : img.copyResize(src, width: w, height: h);

/// Pack up to four grayscale sources into a single RGBA image.
///
/// Each of [r], [g], [b], [a] supplies one output channel via its luminance.
/// Where a source is null the corresponding `defaultX` constant is written
/// (alpha defaults to 255 / opaque white). All sources are resized to the
/// common (max) resolution first.
img.Image packRGBA({
  img.Image? r,
  img.Image? g,
  img.Image? b,
  img.Image? a,
  int defaultR = 0,
  int defaultG = 0,
  int defaultB = 0,
  int defaultA = 255,
}) {
  final size = commonSize([r, g, b, a]);
  final w = size.w;
  final h = size.h;

  final rr = r == null ? null : _resizeTo(r, w, h);
  final gg = g == null ? null : _resizeTo(g, w, h);
  final bb = b == null ? null : _resizeTo(b, w, h);
  final aa = a == null ? null : _resizeTo(a, w, h);

  final out = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final cr = rr == null ? defaultR : readGray(rr.getPixel(x, y));
      final cg = gg == null ? defaultG : readGray(gg.getPixel(x, y));
      final cb = bb == null ? defaultB : readGray(bb.getPixel(x, y));
      final ca = aa == null ? defaultA : readGray(aa.getPixel(x, y));
      out.setPixelRgba(x, y, cr, cg, cb, ca);
    }
  }
  return out;
}

/// Convert a height/depth image into a tangent-space normal map using a Sobel
/// operator, matching the reference channel-packer site.
///
/// [strength] scales the gradient before normalization; [invertG] flips the
/// green channel for DirectX-style normal maps (default is OpenGL).
img.Image sobelNormal(img.Image height, {double strength = 2.0, bool invertG = false}) {
  final w = height.width;
  final h = height.height;
  final out = img.Image(width: w, height: h, numChannels: 4);

  // Grayscale lookup with clamped edges.
  double gray(int x, int y) => readGray(height.getPixelClamped(x, y)).toDouble();

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final tl = gray(x - 1, y - 1), t = gray(x, y - 1), tr = gray(x + 1, y - 1);
      final l = gray(x - 1, y), r = gray(x + 1, y);
      final bl = gray(x - 1, y + 1), b = gray(x, y + 1), br = gray(x + 1, y + 1);

      final dX = (tr + 2 * r + br) - (tl + 2 * l + bl);
      final dY = (bl + 2 * b + br) - (tl + 2 * t + tr);

      var nx = -dX * strength / 255.0;
      var ny = -dY * strength / 255.0;
      const nz = 1.0;
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      nx /= len;
      ny /= len;
      final nzn = nz / len;

      var gEnc = ny * 0.5 + 0.5;
      if (invertG) gEnc = 1.0 - gEnc;

      out.setPixelRgba(
        x,
        y,
        ((nx * 0.5 + 0.5) * 255.0).round().clamp(0, 255),
        (gEnc * 255.0).round().clamp(0, 255),
        ((nzn * 0.5 + 0.5) * 255.0).round().clamp(0, 255),
        255,
      );
    }
  }
  return out;
}
