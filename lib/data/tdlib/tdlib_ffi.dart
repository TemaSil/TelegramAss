import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Raw FFI bindings for TDLib's JSON interface.
///
/// Mirrors `td_json_client.h` from tdlib/td, using the modern client-id API:
/// `td_create_client_id` / `td_send` / `td_receive` / `td_execute`.
/// See https://core.telegram.org/tdlib/getting-started
///
/// The Android build expects `libtdjson.so` in
/// `android/app/src/main/jniLibs/<abi>/`. When the library is absent, [TdJsonBindings.open] returns null and
/// the app falls back to the demo backend instead of crashing.
class TdJsonBindings {
  TdJsonBindings._(DynamicLibrary lib)
    : _createClientId = lib.lookupFunction<Int32 Function(), int Function()>(
        'td_create_client_id',
      ),
      _send = lib
          .lookupFunction<
            Void Function(Int32, Pointer<Utf8>),
            void Function(int, Pointer<Utf8>)
          >('td_send'),
      _receive = lib
          .lookupFunction<
            Pointer<Utf8> Function(Double),
            Pointer<Utf8> Function(double)
          >('td_receive'),
      _execute = lib
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Utf8>),
            Pointer<Utf8> Function(Pointer<Utf8>)
          >('td_execute');

  final int Function() _createClientId;
  final void Function(int, Pointer<Utf8>) _send;
  final Pointer<Utf8> Function(double) _receive;
  final Pointer<Utf8> Function(Pointer<Utf8>) _execute;

  /// Loads the native library, or returns null when it is not bundled.
  static TdJsonBindings? open() {
    try {
      final lib = _openLibrary();
      if (lib == null) return null;
      return TdJsonBindings._(lib);
    } on Object {
      // Missing symbol or wrong ABI — treat exactly like a missing library.
      return null;
    }
  }

  static DynamicLibrary? _openLibrary() {
    try {
      if (Platform.isAndroid) return DynamicLibrary.open('libtdjson.so');
      if (Platform.isLinux) return DynamicLibrary.open('libtdjson.so');
      if (Platform.isWindows) return DynamicLibrary.open('tdjson.dll');
      if (Platform.isIOS || Platform.isMacOS) return DynamicLibrary.process();
    } on ArgumentError {
      return null;
    }
    return null;
  }

  int createClientId() => _createClientId();

  void send(int clientId, String request) {
    final pointer = request.toNativeUtf8();
    try {
      _send(clientId, pointer);
    } finally {
      calloc.free(pointer);
    }
  }

  /// Blocks up to [timeout] seconds waiting for the next update.
  /// Returns null on timeout. The returned string is owned by TDLib and is
  /// only valid until the next `td_receive` on the same thread, so it is
  /// copied into a Dart string immediately.
  String? receive(double timeout) {
    final pointer = _receive(timeout);
    if (pointer == nullptr) return null;
    return pointer.toDartString();
  }

  /// Synchronous calls only (e.g. `setLogVerbosityLevel`).
  String? execute(String request) {
    final pointer = request.toNativeUtf8();
    try {
      final result = _execute(pointer);
      if (result == nullptr) return null;
      return result.toDartString();
    } finally {
      calloc.free(pointer);
    }
  }
}
