import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:channel_packer/core/image_ops.dart';

void main() {
  test('packRGBA writes selected channels and alpha default', () {
    final r = img.Image(width: 2, height: 2, numChannels: 1);
    r.setPixelRgb(0, 0, 200, 200, 200);
    final packed = packRGBA(r: r); // g/b null -> 0, a null -> 255

    final p = packed.getPixel(0, 0);
    expect(p.r.round(), 200);
    expect(p.g.round(), 0);
    expect(p.b.round(), 0);
    expect(p.a.round(), 255);
  });

  test('sobelNormal of a flat height map is the flat normal (0,0,1)', () {
    final flat = img.Image(width: 4, height: 4, numChannels: 1);
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        flat.setPixelRgb(x, y, 128, 128, 128);
      }
    }
    final n = sobelNormal(flat);
    final p = n.getPixel(1, 1);
    expect(p.r.round(), 128); // x ~ 0.5
    expect(p.g.round(), 128); // y ~ 0.5
    expect(p.b.round(), 255); // z ~ 1.0
  });

  test('all normal methods map a flat height to the flat normal (0,0,1)', () {
    final flat = img.Image(width: 8, height: 8, numChannels: 1);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        flat.setPixelRgb(x, y, 128, 128, 128);
      }
    }
    for (final method in NormalMethod.values) {
      final n = generateNormal(flat, method: method, blurRadius: 0);
      final p = n.getPixel(4, 4);
      expect(p.r.round(), 128, reason: '$method x');
      expect(p.g.round(), 128, reason: '$method y');
      expect(p.b.round(), 255, reason: '$method z');
    }
  });

  test('AO of a flat height map is fully unoccluded (white)', () {
    final flat = img.Image(width: 8, height: 8, numChannels: 1);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        flat.setPixelRgb(x, y, 128, 128, 128);
      }
    }
    final ao = generateAO(flat, radius: 4, strength: 2.0);
    expect(ao.getPixel(4, 4).r.round(), 255); // no valleys -> white
  });

  test('Roughness of a flat color map equals the base level', () {
    final flat = img.Image(width: 8, height: 8, numChannels: 3);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        flat.setPixelRgb(x, y, 100, 100, 100);
      }
    }
    final r = generateRoughness(flat, base: 0.5, intensity: 4.0);
    // No real detail -> stays near base (0.5 -> 128); a couple levels of 8-bit
    // blur-rounding noise is expected and amplified slightly by intensity.
    expect(r.getPixel(4, 4).r.round(), closeTo(128, 8));
  });

  test('AO darkens a valley and leaves the input image unmutated', () {
    // Bright field (200) with a dark 4x4 valley (40) in the centre.
    final height = img.Image(width: 16, height: 16, numChannels: 1);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        final inValley = x >= 6 && x < 10 && y >= 6 && y < 10;
        height.setPixelRgb(x, y, inValley ? 40 : 200, 0, 0);
      }
    }
    final ao = generateAO(height, radius: 6, strength: 2.0);

    expect(
      ao.getPixel(8, 8).r.round(),
      lessThan(255),
      reason: 'valley should be occluded (darkened)',
    );
    expect(
      ao.getPixel(0, 0).r.round(),
      255,
      reason: 'flat bright corner should stay unoccluded',
    );
    // Regression: gaussianBlur mutates in place; generateAO must blur a copy and
    // leave the caller's height map untouched.
    expect(height.getPixel(8, 8).r.round(), 40);
    expect(height.getPixel(0, 0).r.round(), 200);
  });

  test('Roughness rises on surface detail', () {
    // A high-contrast checker has lots of local detail -> roughness above base.
    final src = img.Image(width: 16, height: 16, numChannels: 3);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        final v = ((x + y) % 2 == 0) ? 230 : 20;
        src.setPixelRgb(x, y, v, v, v);
      }
    }
    final r = generateRoughness(src, base: 0.3, intensity: 4.0, radius: 2);
    expect(
      r.getPixel(8, 8).r.round(),
      greaterThan((0.3 * 255).round()),
      reason: 'detail should raise roughness above base',
    );
    expect(
      src.getPixel(8, 8).r.round(),
      anyOf(20, 230),
      reason: 'input must not be mutated',
    );
  });
}
