import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../diagnostics.dart';

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

  /// Loads the native library, or returns null when it cannot be used.
  ///
  /// Every failure is logged with its real reason: "nothing happened" on the
  /// login screen is almost always one of these, and without the text there is
  /// no way to tell a missing library from a missing symbol.
  static TdJsonBindings? open({bool quiet = false}) {
    final DynamicLibrary lib;
    try {
      final opened = _openLibrary();
      if (opened == null) {
        if (!quiet) {
          TgDiagnostics.instance.error(
            'No TDLib library for this platform (${Platform.operatingSystem}).',
          );
        }
        return null;
      }
      lib = opened;
    } on Object catch (error) {
      if (!quiet) {
        TgDiagnostics.instance.error('Could not load libtdjson: $error');
      }
      return null;
    }

    try {
      final bindings = TdJsonBindings._(lib);
      if (!quiet) TgDiagnostics.instance.info('libtdjson loaded.');
      return bindings;
    } on Object catch (error) {
      // The library opened but a symbol is missing — a Java-interface build,
      // or one whose exports are restricted.
      if (!quiet) {
        TgDiagnostics.instance.error('libtdjson is missing a symbol: $error');
      }
      return null;
    }
  }

  static DynamicLibrary? _openLibrary() {
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libtdjson.so');
    }
    if (Platform.isWindows) return DynamicLibrary.open('tdjson.dll');
    if (Platform.isIOS || Platform.isMacOS) return DynamicLibrary.process();
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
