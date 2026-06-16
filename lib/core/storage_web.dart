import 'package:web/web.dart' as web;

/// Web: browser `localStorage` persistence (WASM-safe via `package:web`).

const _graphKey = 'channel_packer.graph';
const _embedKey = 'channel_packer.embedImages';

/// The user's last-saved graph JSON, or null if they have none yet.
String? loadStoredGraph() => web.window.localStorage.getItem(_graphKey);

void storeGraphString(String json) =>
    web.window.localStorage.setItem(_graphKey, json);

void clearStoredGraph() => web.window.localStorage.removeItem(_graphKey);

/// The persisted "embed images in saved config" toggle (default false).
bool loadEmbedImages() => web.window.localStorage.getItem(_embedKey) == 'true';

void storeEmbedImages(bool value) =>
    web.window.localStorage.setItem(_embedKey, value ? 'true' : 'false');
