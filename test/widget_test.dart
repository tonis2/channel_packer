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
}
