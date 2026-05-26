import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/native_event_drain_loop.dart';

void main() {
  test(
    'foreground native event drain loop drains immediately and on ticks',
    () async {
      final ticks = StreamController<void>();
      addTearDown(ticks.close);

      var calls = 0;
      final loop = NativeEventDrainLoop(
        drain: () async {
          calls += 1;
          return calls;
        },
        ticks: ticks.stream,
      );
      addTearDown(loop.dispose);

      loop.start();
      await pumpEventQueue();

      expect(calls, 1);

      ticks.add(null);
      await pumpEventQueue();

      expect(calls, 2);
    },
  );

  test('foreground native event drain loop does not overlap drains', () async {
    final ticks = StreamController<void>();
    addTearDown(ticks.close);
    final completers = <Completer<int>>[];

    final loop = NativeEventDrainLoop(
      drain: () {
        final completer = Completer<int>();
        completers.add(completer);
        return completer.future;
      },
      ticks: ticks.stream,
    );
    addTearDown(loop.dispose);

    loop.start();
    await pumpEventQueue();
    ticks.add(null);
    await pumpEventQueue();

    expect(completers, hasLength(1));

    completers.single.complete(1);
    await pumpEventQueue();
    ticks.add(null);
    await pumpEventQueue();

    expect(completers, hasLength(2));
  });
}
