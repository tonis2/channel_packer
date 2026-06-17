import 'dart:typed_data';

/// Web has no subprocess support, so the Depth node is desktop-only. These stubs
/// keep the web build compiling; both report the limitation if ever reached.

String? resolveDepthBinary(String? override) => null;

Future<Uint8List> runDepth({
  required String binaryPath,
  required String modelPath,
  required Uint8List inputPng,
  required List<String> flags,
}) async {
  throw UnsupportedError('Depth generation requires the desktop app');
}
