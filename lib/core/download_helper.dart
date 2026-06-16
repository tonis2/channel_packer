// Save [bytes] to a file named [filename].
//
// Platform-dispatched: on the web this triggers a browser download
// (`download_helper_web.dart`); on native desktop/mobile it opens a Save-As
// dialog and writes the file (`download_helper_io.dart`). Callers just call
// `downloadBytes(...)` and never see the difference.
export 'download_helper_io.dart'
    if (dart.library.js_interop) 'download_helper_web.dart';
