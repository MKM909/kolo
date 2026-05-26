import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/connectivity_sync_retry_service.dart';

void main() {
  test('does not retry while connectivity is offline', () async {
    final controller = StreamController<List<ConnectivityResult>>();
    var retryCount = 0;
    final service = ConnectivitySyncRetryService(
      connectivityChanges: controller.stream,
      retryPending: () async => retryCount += 1,
    );
    addTearDown(() async {
      await service.dispose();
      await controller.close();
    });

    service.start();
    controller.add(const [ConnectivityResult.none]);
    await pumpEventQueue();

    expect(retryCount, 0);
  });

  test('retries pending writes when connectivity returns', () async {
    final controller = StreamController<List<ConnectivityResult>>();
    var retryCount = 0;
    final service = ConnectivitySyncRetryService(
      connectivityChanges: controller.stream,
      retryPending: () async => retryCount += 1,
    );
    addTearDown(() async {
      await service.dispose();
      await controller.close();
    });

    service.start();
    controller.add(const [ConnectivityResult.wifi]);
    await pumpEventQueue();

    expect(retryCount, 1);
  });

  test(
    'does not overlap retry runs during noisy connectivity changes',
    () async {
      final controller = StreamController<List<ConnectivityResult>>();
      final retryCompleter = Completer<void>();
      var retryCount = 0;
      final service = ConnectivitySyncRetryService(
        connectivityChanges: controller.stream,
        retryPending: () async {
          retryCount += 1;
          await retryCompleter.future;
          return retryCount;
        },
      );
      addTearDown(() async {
        await service.dispose();
        await controller.close();
      });

      service.start();
      controller.add(const [ConnectivityResult.mobile]);
      controller.add(const [ConnectivityResult.wifi]);
      await pumpEventQueue();

      expect(retryCount, 1);

      retryCompleter.complete();
      await pumpEventQueue();
      controller.add(const [ConnectivityResult.ethernet]);
      await pumpEventQueue();

      expect(retryCount, 2);
    },
  );

  test('app watches connectivity retry service at startup', () {
    final appSource = File('lib/app/kolo_app.dart').readAsStringSync();
    final providersSource = File('lib/app/providers.dart').readAsStringSync();

    expect(providersSource, contains('connectivitySyncRetryServiceProvider'));
    expect(
      appSource,
      contains('ref.watch(connectivitySyncRetryServiceProvider)'),
    );
  });
}
