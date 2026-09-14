/// Chooses the TDLib backend implementation for the target platform.
///
/// `dart:ffi` does not exist on the web, so a web build gets a stub that
/// reports itself unavailable and lets [AppState] fall back to the demo
/// backend. Native builds get the real client.
library;

export 'tdlib_client.dart' if (dart.library.js_interop) 'tdlib_client_web.dart';
