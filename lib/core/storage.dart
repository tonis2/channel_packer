// Persistence for the saved graph + settings.
//
// Platform-dispatched: web uses browser `localStorage` (`storage_web.dart`);
// native desktop/mobile uses a JSON file in the user's config dir
// (`storage_io.dart`). Both expose the same synchronous API, so callers don't
// branch on platform.
export 'storage_io.dart' if (dart.library.js_interop) 'storage_web.dart';
