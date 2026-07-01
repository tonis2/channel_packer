import 'dart:convert';
import 'dart:io';

/// Native (Linux/macOS/Windows): persist to a small JSON file under the user's
/// config dir, mirroring the web's `localStorage` API (synchronous, same keys).
///
/// The whole store is one `~/.config/channel_packer/store.json` map; each getter
/// reads it and each setter reads-modifies-writes. The data is tiny (a graph
/// JSON string + a bool), so the per-call sync IO is negligible.

const _graphKey = 'graph';
const _embedKey = 'embedImages';
const _depthModelKey = 'depthModelPath';

File _storeFile() {
  final home =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;
  final dir = Directory('$home/.config/channel_packer');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return File('${dir.path}/store.json');
}

Map<String, dynamic> _read() {
  final f = _storeFile();
  if (!f.existsSync()) return {};
  try {
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {
    return {}; // corrupt/empty -> start fresh
  }
}

void _write(Map<String, dynamic> data) =>
    _storeFile().writeAsStringSync(jsonEncode(data));

String? loadStoredGraph() => _read()[_graphKey] as String?;

void storeGraphString(String json) => _write(_read()..[_graphKey] = json);

void clearStoredGraph() => _write(_read()..remove(_graphKey));

bool loadEmbedImages() => _read()[_embedKey] == true;

void storeEmbedImages(bool value) => _write(_read()..[_embedKey] = value);

String? loadDepthModelPath() => _read()[_depthModelKey] as String?;

void storeDepthModelPath(String? value) => _write(
  _read()..[_depthModelKey] = value,
);
