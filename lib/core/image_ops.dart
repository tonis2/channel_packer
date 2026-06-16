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

/// Gradient operator used to turn a height map into a normal map.
///
/// - [sobel]: classic 3×3 `[1,2,1]` kernel. Cheap but has a slight diagonal bias.
/// - [scharr]: 3×3 `[3,10,3]` kernel, optimized for rotational symmetry, so the
///   gradient *direction* is more accurate than Sobel — a strictly better swap.
/// - [multiScale]: runs Scharr at two scales (a fine pass + a heavily-blurred
///   large pass) and blends them, capturing crisp detail and broad surface form
///   without the grain a single pass produces.
enum NormalMethod { sobel, scharr, multiScale }

/// One side's kernel weights (outer, center) for each operator. Scharr weights
/// also drive the multi-scale passes.
({double outer, double center}) _kernelWeights(NormalMethod method) =>
    method == NormalMethod.sobel ? (outer: 1, center: 2) : (outer: 3, center: 10);

/// Sobel/Scharr-shaped gradient at (x, y), normalized so every operator lands on
/// the same magnitude scale as the classic Sobel (so `strength` means the same
/// thing regardless of method). Returns slopes in roughly [-255, 255].
({double dx, double dy}) _slopeAt(
  double Function(int, int) g,
  int x,
  int y,
  double outer,
  double center,
) {
  final tl = g(x - 1, y - 1), t = g(x, y - 1), tr = g(x + 1, y - 1);
  final l = g(x - 1, y), r = g(x + 1, y);
  final bl = g(x - 1, y + 1), b = g(x, y + 1), br = g(x + 1, y + 1);

  // Rescale to Sobel's magnitude: Sobel's one-side weight sum is 4, so dividing
  // by this operator's sum and multiplying by 4 keeps `strength` comparable.
  final scale = 4.0 / (2 * outer + center);
  final dx = ((outer * tr + center * r + outer * br) -
          (outer * tl + center * l + outer * bl)) *
      scale;
  final dy = ((outer * bl + center * b + outer * br) -
          (outer * tl + center * t + outer * tr)) *
      scale;
  return (dx: dx, dy: dy);
}

/// Encode tangent-space slopes into a normal-map RGBA pixel.
void _encodeNormal(
  img.Image out,
  int x,
  int y,
  double dX,
  double dY,
  double strength,
  bool invertG,
) {
  var nx = -dX * strength / 255.0;
  // OpenGL convention (Blender/glTF): +Y green points up the image, so green is
  // proportional to +dY (dY = bottom - top). invertG flips this to DirectX.
  var ny = dY * strength / 255.0;
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

/// Convert a height/depth image into a tangent-space normal map.
///
/// [method] picks the gradient operator (see [NormalMethod]).
/// [strength] scales the gradient before normalization; [invertG] flips the
/// green channel for DirectX-style normal maps (default is OpenGL).
/// [blurRadius] applies a Gaussian pre-blur to remove per-pixel noise (0 = off).
/// [detail]/[large] only apply to [NormalMethod.multiScale]: they weight the
/// fine and coarse passes; [largeScale] is the coarse pass's extra blur radius.
img.Image generateNormal(
  img.Image height, {
  NormalMethod method = NormalMethod.scharr,
  double strength = 2.0,
  bool invertG = false,
  int blurRadius = 0,
  double detail = 1.0,
  double large = 1.0,
  int largeScale = 6,
}) {
  // Pre-blur to remove high-frequency noise. gaussianBlur is a no-op at 0.
  if (blurRadius > 0) {
    height = img.gaussianBlur(height, radius: blurRadius);
  }
  final w = height.width;
  final h = height.height;
  final out = img.Image(width: w, height: h, numChannels: 4);
  final k = _kernelWeights(method);

  double gray(int x, int y) => readGray(height.getPixelClamped(x, y)).toDouble();

  if (method == NormalMethod.multiScale) {
    // Fine pass = the (already noise-blurred) source; large pass = a heavily
    // blurred copy that captures broad form. Blend the slopes (partial-derivative
    // blending), which is the correct way to combine normals.
    final coarse = img.gaussianBlur(height, radius: largeScale);
    double grayCoarse(int x, int y) =>
        readGray(coarse.getPixelClamped(x, y)).toDouble();
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final f = _slopeAt(gray, x, y, k.outer, k.center);
        final c = _slopeAt(grayCoarse, x, y, k.outer, k.center);
        _encodeNormal(
          out, x, y, detail * f.dx + large * c.dx, detail * f.dy + large * c.dy, strength, invertG);
      }
    }
    return out;
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final s = _slopeAt(gray, x, y, k.outer, k.center);
      _encodeNormal(out, x, y, s.dx, s.dy, strength, invertG);
    }
  }
  return out;
}

/// Backwards-compatible Sobel wrapper (kept for existing callers/tests).
img.Image sobelNormal(
  img.Image height, {
  double strength = 2.0,
  bool invertG = false,
  int blurRadius = 0,
}) =>
    generateNormal(
      height,
      method: NormalMethod.sobel,
      strength: strength,
      invertG: invertG,
      blurRadius: blurRadius,
    );
