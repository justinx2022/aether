import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aether/features/player/domain/engine_failover.dart';

void main() {
  group('PlaybackEngine', () {
    test('other returns the opposite engine', () {
      expect(PlaybackEngine.mediaKit.other, PlaybackEngine.vlc);
      expect(PlaybackEngine.vlc.other, PlaybackEngine.mediaKit);
    });

    test('other is an involution', () {
      for (final engine in PlaybackEngine.values) {
        expect(engine.other.other, engine);
      }
    });

    test('labels are non-empty and distinct', () {
      expect(PlaybackEngine.mediaKit.label, isNotEmpty);
      expect(PlaybackEngine.vlc.label, isNotEmpty);
      expect(
        PlaybackEngine.mediaKit.label,
        isNot(PlaybackEngine.vlc.label),
      );
    });
  });

  group('shouldHandOffToOtherEngine', () {
    test('hands off when the setting is on, platform supported, first hop', () {
      expect(
        shouldHandOffToOtherEngine(
          settingEnabled: true,
          alreadyHandedOff: false,
          platformSupported: true,
        ),
        isTrue,
      );
    });

    test('never hands off when the setting is off', () {
      expect(
        shouldHandOffToOtherEngine(
          settingEnabled: false,
          alreadyHandedOff: false,
          platformSupported: true,
        ),
        isFalse,
      );
    });

    test('never hands off from a screen opened by a hand-off', () {
      // One automatic hop per playback: the target must not bounce the
      // stream straight back.
      expect(
        shouldHandOffToOtherEngine(
          settingEnabled: true,
          alreadyHandedOff: true,
          platformSupported: true,
        ),
        isFalse,
      );
    });

    test('never hands off where the other engine does not exist', () {
      expect(
        shouldHandOffToOtherEngine(
          settingEnabled: true,
          alreadyHandedOff: false,
          platformSupported: false,
        ),
        isFalse,
      );
    });
  });

  group('engineFailoverPlatformSupported', () {
    test('true on windows and android', () {
      expect(
        engineFailoverPlatformSupported(TargetPlatform.windows),
        isTrue,
      );
      expect(
        engineFailoverPlatformSupported(TargetPlatform.android),
        isTrue,
      );
    });

    test('false everywhere else', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          engineFailoverPlatformSupported(platform),
          isFalse,
          reason: '$platform should not support cross-engine failover',
        );
      }
    });
  });

  group('engine switch notifier', () {
    setUp(clearEngineSwitchRequest);
    tearDown(clearEngineSwitchRequest);

    test('requestEngineSwitch publishes a request with all fields', () {
      const resumeAt = Duration(minutes: 1, seconds: 30);
      requestEngineSwitch(PlaybackEngine.vlc, resumeAt: resumeAt);

      final request = engineSwitchNotifier.value;
      expect(request, isNotNull);
      expect(request!.target, PlaybackEngine.vlc);
      expect(request.resumeAt, resumeAt);
      expect(request.fromFailover, isFalse);
    });

    test('fromFailover flag is carried through', () {
      requestEngineSwitch(
        PlaybackEngine.mediaKit,
        resumeAt: Duration.zero,
        fromFailover: true,
      );

      final request = engineSwitchNotifier.value;
      expect(request, isNotNull);
      expect(request!.fromFailover, isTrue);
    });

    test('a later request replaces an earlier one', () {
      requestEngineSwitch(PlaybackEngine.vlc, resumeAt: Duration.zero);
      requestEngineSwitch(PlaybackEngine.mediaKit, resumeAt: Duration.zero);

      expect(engineSwitchNotifier.value!.target, PlaybackEngine.mediaKit);
    });

    test('clearEngineSwitchRequest resets to null', () {
      requestEngineSwitch(PlaybackEngine.vlc, resumeAt: Duration.zero);
      clearEngineSwitchRequest();

      expect(engineSwitchNotifier.value, isNull);
    });

    test('notifier notifies listeners on request and clear', () {
      var notifications = 0;
      void listener() => notifications++;
      engineSwitchNotifier.addListener(listener);
      addTearDown(() => engineSwitchNotifier.removeListener(listener));

      requestEngineSwitch(PlaybackEngine.vlc, resumeAt: Duration.zero);
      expect(notifications, 1);

      clearEngineSwitchRequest();
      expect(notifications, 2);
    });
  });
}
