import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:still_alive/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart' show PlatformInt64;
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';
import 'package:still_alive/src/rust/api/timer/config.dart';
import 'package:still_alive/src/rust/api/timer/state.dart';

/// Helper to create a minimal TimerConfig for testing.
TimerConfig _buildTestConfig({String name = 'Test Timer', PlatformInt64 durationSecs = 3600, PlatformInt64? gracePeriodSecs}) {
  final now = DateTime.now().toIso8601String();
  return TimerConfig(
    name: name,
    durationSecs: durationSecs,
    gracePeriodSecs: gracePeriodSecs,
    passwordProtected: false,
    passwordHash: null,
    locationSharingEnabled: false,
    routeSharingEnabled: false,
    locationCollectionIntervalSecs: null,
    audioRecordingEnabled: false,
    contacts: [],
    customSms: [],
    customEmail: [],
    integrations: TimerIntegrations(
      discord: TimerIntegration(accounts: []),
      telegram: TimerIntegration(accounts: []),
    ),
    message: 'Test message',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();

    final tempDir = await getTemporaryDirectory();
    final dbPath = p.join(tempDir.path, 'timer_integ_${DateTime.now().millisecondsSinceEpoch}.db');

    await initDatabase(path: dbPath);
  });

  group('Timer Lifecycle', () {
    test('startTimerRun creates Running state with correct timestamps', () async {
      // Create a fresh timer0 with known duration.
      final config = _buildTestConfig(name: 'Lifecycle Timer', durationSecs: 120, gracePeriodSecs: 30);

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Persist the timer.
      await persistTimer(key: 'timer0', config: config);

      // Load and start a timer run.
      final maybeTimer = await reconcileActiveTimer(nowMs: nowMs);
      expect(maybeTimer, isNotNull, reason: 'reconcileActiveTimer should return a timer');
      final timer = maybeTimer!;
      expect(timer.key, 'timer0');
      expect(timer.run.state, TimerState.completed);

      await timer.startTimerRun(nowMs: nowMs);

      // Verify state transition.
      expect(timer.run.state, TimerState.running);
      expect(timer.run.startedAtMs, nowMs);
      expect(timer.run.expiresAtMs, nowMs + 120 * 1000);
      expect(timer.run.warningDurationMs, 30 * 1000);
    });

    test('pauseTimerRun transitions Running to Paused', () async {
      // Start from a fresh state.
      final config = _buildTestConfig(name: 'Pause Test', durationSecs: 600);

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await persistTimer(key: 'timer0', config: config);

      final maybeTimer = await reconcileActiveTimer(nowMs: nowMs);
      expect(maybeTimer, isNotNull, reason: 'reconcileActiveTimer should return a timer');
      final timer = maybeTimer!;

      await timer.startTimerRun(nowMs: nowMs);
      expect(timer.run.state, TimerState.running);

      final pauseTime = nowMs + 10000;
      await timer.pauseTimerRun(nowMs: pauseTime, passwordVerified: true);

      expect(timer.run.state, TimerState.paused);
      expect(timer.run.pausedAtMs, pauseTime);
      // Expiry should NOT shift.
      expect(timer.run.expiresAtMs, nowMs + 600 * 1000);
    });

    test('resumeTimerRun shifts start and expiry by pause duration', () async {
      final config = _buildTestConfig(name: 'Resume Test', durationSecs: 600);

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await persistTimer(key: 'timer0', config: config);

      final maybeTimer = await reconcileActiveTimer(nowMs: nowMs);
      expect(maybeTimer, isNotNull, reason: 'reconcileActiveTimer should return a timer');
      final timer = maybeTimer!;

      await timer.startTimerRun(nowMs: nowMs);
      final pauseTime = nowMs + 10000;
      await timer.pauseTimerRun(nowMs: pauseTime, passwordVerified: true);

      final resumeTime = nowMs + 30000;
      await timer.resumeTimerRun(nowMs: resumeTime);

      expect(timer.run.state, TimerState.running);
      expect(timer.run.pausedAtMs, null);

      // Started and expiry both shift by (30000 - 10000) = 20000 ms.
      expect(timer.run.startedAtMs, nowMs + 20000);
      expect(timer.run.expiresAtMs, nowMs + 600 * 1000 + 20000);
    });

    test('cancelTimerRun transitions Running to Cancelled', () async {
      final config = _buildTestConfig(name: 'Cancel Test', durationSecs: 300);

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await persistTimer(key: 'timer0', config: config);

      final maybeTimer = await reconcileActiveTimer(nowMs: nowMs);
      expect(maybeTimer, isNotNull, reason: 'reconcileActiveTimer should return a timer');
      final timer = maybeTimer!;

      await timer.startTimerRun(nowMs: nowMs);
      await timer.cancelTimerRun(nowMs: nowMs + 1000, passwordVerified: true);

      expect(timer.run.state, TimerState.cancelled);
    });

    test('pause requires password verification when passwordProtected', () async {
      final now = DateTime.now().toIso8601String();
      final config = TimerConfig(
        name: 'Protected Timer',
        durationSecs: 300,
        passwordProtected: true,
        passwordHash: r'$2a$10$abcdefghijklmnopqrstuv',
        locationSharingEnabled: false,
        routeSharingEnabled: false,
        audioRecordingEnabled: false,
        contacts: [],
        customSms: [],
        customEmail: [],
        integrations: TimerIntegrations(
          discord: TimerIntegration(accounts: []),
          telegram: TimerIntegration(accounts: []),
        ),
        createdAt: now,
        updatedAt: now,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await persistTimer(key: 'timer0', config: config);

      final maybeTimer = await reconcileActiveTimer(nowMs: nowMs);
      expect(maybeTimer, isNotNull, reason: 'reconcileActiveTimer should return a timer');
      final timer = maybeTimer!;

      await timer.startTimerRun(nowMs: nowMs);

      // Should fail without password verification.
      await expectLater(
        () => timer.pauseTimerRun(nowMs: nowMs, passwordVerified: false),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Password'))),
      );
    });
  });

  group('Timer Unique ID', () {
    test('getUniqueTimerId returns first unused identifier', () async {
      final id = await getUniqueTimerId();

      expect(id, isNotNull);
      expect(id, startsWith('timer'));
    });

    test('getUniqueTimerId skips used identifiers', () async {
      // Create timer1 and timer2.
      final config1 = _buildTestConfig(name: 'Timer 1');
      final config2 = _buildTestConfig(name: 'Timer 2');

      await persistTimer(key: 'timer1', config: config1);
      await persistTimer(key: 'timer2', config: config2);

      final id = await getUniqueTimerId();

      expect(id, isNotNull);
      expect(id, startsWith('timer'));
      // Should skip timer1 and timer2.
      expect(id, isNot('timer1'));
      expect(id, isNot('timer2'));
    });
  });

  group('Timer Persistence', () {
    test('persisted timer survives reconcile', () async {
      final config = _buildTestConfig(name: 'Persistent Timer', durationSecs: 1800, gracePeriodSecs: 60);

      await persistTimer(key: 'timer0', config: config);

      final timer = await reconcileActiveTimer(nowMs: DateTime.now().millisecondsSinceEpoch);
      expect(timer, isNotNull);
      expect(timer!.key, 'timer0');
      expect(timer.config.name, 'Persistent Timer');
      expect(timer.config.durationSecs, 1800);
      expect(timer.config.gracePeriodSecs, 60);
    });
  });

  group('TimerState String Round-trip', () {
    test('state round-trips through as_str and state_from_str', () async {
      // This verifies the enum is correctly serialized through FRB.
      final states = [TimerState.running, TimerState.paused, TimerState.cancelled, TimerState.expired, TimerState.warning, TimerState.completed];

      for (final state in states) {
        // Verify the round-trip through Rust's as_str and state_from_str.
        final stateFromStr = await TimerState.stateFromStr(value: state.toString().split('.').last);
        expect(stateFromStr, state);
      }
    });
  });
}
