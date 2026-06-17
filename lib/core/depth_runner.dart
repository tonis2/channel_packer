// Runs the bundled Depth Anything `depth` binary to turn an albedo image into a
// height/depth map.
//
// Platform-dispatched: native desktop shells out to the binary via a temp file
// round-trip (`depth_runner_io.dart`); the web has no subprocess support, so the
// stub (`depth_runner_web.dart`) throws. Callers import this file only.
export 'depth_runner_io.dart'
    if (dart.library.js_interop) 'depth_runner_web.dart';
