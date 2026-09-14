// Exercises the real TdlibTelegramClient against a native libtdjson, without
// Flutter and without touching anyone's account.
//
// It answers the question a phone cannot: does our own code drive TDLib
// correctly — does the library bind, does the receive isolate deliver updates,
// is setTdlibParameters accepted, does a request get its answer back?
//
//   LD_LIBRARY_PATH=<dir with libtdjson.so> \
//   dart run tool/tdlib_probe.dart <api_id> <api_hash> [phone]
//
// With no phone given it stops once TDLib is ready for one. Pass a deliberately
// invalid number to check the error path; never pass a real one here.
import 'dart:async';
import 'dart:io';

import 'package:telegram_liquid/data/diagnostics.dart';
import 'package:telegram_liquid/data/tdlib/tdlib_client.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: tdlib_probe.dart <api_id> <api_hash> [phone]');
    exit(64);
  }

  TgDiagnostics.instance.stream.listen((line) {
    stdout.writeln('[${line.stamp}] ${line.level.name.padRight(7)} '
        '${line.message}');
  });

  final directory = Directory.systemTemp.createTempSync('tdlib-probe-');
  final client = TdlibTelegramClient(
    apiId: int.parse(args[0]),
    apiHash: args[1],
    databaseDirectory: '${directory.path}/db',
    filesDirectory: '${directory.path}/files',
    deviceModel: 'probe',
  );

  client.authStage.listen((stage) => stdout.writeln('>> stage: ${stage.name}'));

  try {
    await client.start();
  } on Object catch (error) {
    stdout.writeln('!! start failed: $error');
    exit(1);
  }

  // Wait for the handshake to land on "ready for a phone number".
  final ready = Completer<bool>();
  final timer = Timer(const Duration(seconds: 25), () {
    if (!ready.isCompleted) ready.complete(false);
  });
  final poll = Timer.periodic(const Duration(milliseconds: 200), (t) {
    if (client.isReadyForPhone && !ready.isCompleted) ready.complete(true);
  });

  final reached = await ready.future;
  timer.cancel();
  poll.cancel();

  stdout.writeln(reached
      ? '>> reached authorizationStateWaitPhoneNumber'
      : '!! never reached waitPhoneNumber — last state: '
          '${client.authorizationState}');

  // Linger so connection-state transitions are visible: a client that never
  // leaves connectionStateConnecting cannot reach Telegram at all, which looks
  // exactly like a bug in our code but is not one.
  stdout.writeln('>> watching the connection for 60s…');
  await Future<void>.delayed(const Duration(seconds: 60));
  stdout.writeln('>> connection after 60s: ${client.connectionState}');

  if (reached && args.length > 2) {
    stdout.writeln('>> submitting phone ${args[2]}');
    final result = await client.submitPhone(args[2]);
    stdout.writeln('>> result: stage=${result.stage.name} '
        'error=${result.error}');
  }

  await client.dispose();
  directory.deleteSync(recursive: true);
  exit(reached ? 0 : 2);
}
