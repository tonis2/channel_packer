import 'dart:io';
import 'dart:typed_data';

/// Resolve the bundled `depth` binary: the copy shipped next to the app in
/// `lib/depth` (CMake installs it there). Returns null if it's not present.
String? resolveDepthBinary() {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final bundled = '$exeDir/lib/depth';
  if (File(bundled).existsSync()) return bundled;
  return null;
}

/// Run the depth binary on [inputPng] and return the produced PNG bytes.
///
/// Writes the input to a private temp dir, invokes
/// `depth <model> <in.png> <out.png> [flags]`, and reads back `out.png`. The
/// binary loads the model and inits Vulkan on every call (a few seconds), so
/// callers should cache results. Throws with the binary's stderr/stdout on a
/// non-zero exit. The temp dir is always removed.
Future<Uint8List> runDepth({
  required String binaryPath,
  required String modelPath,
  required Uint8List inputPng,
  required List<String> flags,
}) async {
  final dir = Directory.systemTemp.createTempSync('channel_packer_depth');
  try {
    final inPath = '${dir.path}/in.png';
    final outPath = '${dir.path}/out.png';
    File(inPath).writeAsBytesSync(inputPng);

    final result = await Process.run(binaryPath, [
      modelPath,
      inPath,
      outPath,
      ...flags,
    ]);

    if (result.exitCode != 0) {
      final err = (result.stderr as String).trim();
      final out = (result.stdout as String).trim();
      final detail = err.isNotEmpty ? err : out;
      throw Exception(
        'depth exited ${result.exitCode}'
        '${detail.isEmpty ? '' : ':\n${_tail(detail)}'}',
      );
    }

    final outFile = File(outPath);
    if (!outFile.existsSync()) {
      throw Exception('depth produced no output (no $outPath written)');
    }
    return outFile.readAsBytesSync();
  } finally {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {
      /* best-effort cleanup */
    }
  }
}

/// Keep error messages short: the last few non-empty lines of binary output.
String _tail(String text, [int lines = 6]) {
  final kept = text
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();
  return (kept.length <= lines ? kept : kept.sublist(kept.length - lines))
      .join('\n');
}
