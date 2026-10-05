import 'package:flutter_test/flutter_test.dart';
import 'package:still_alive/services/history_service.dart';

void main() {
  DateTime startedAt = DateTime.parse('2026-01-01T10:00:00.000Z');
  DateTime endedAt = DateTime.parse('2026-01-01T11:00:00.000Z');

  group('TimerStartedEvent', () {
    final json = <String, dynamic>{
      'type': 'started',
      'timer_name': 'My Timer',
      'started_at': '2026-01-01T10:00:00.000Z',
      'ended_at': null,
      'details': <String, dynamic>{
        'duration_seconds': 3600,
        'grace_period_seconds': 60,
        'password_protected': true,
      },
    };

    test('parses correctly and returns the right class', () {
      final event = HistoryService.fromJson(json);
      expect(event, isA<TimerStartedEvent>());
    });

    test('parses all fields correctly', () {
      final event = HistoryService.fromJson(json) as TimerStartedEvent;
      expect(event.timerName, 'My Timer');
      expect(event.startedAt, startedAt);
      expect(event.endedAt, isNull);
      expect(event.durationSeconds, 3600);
      expect(event.gracePeriodSeconds, 60);
      expect(event.passwordProtected, true);
    });
  });

  group('TimerWarningEvent', () {
    final json = <String, dynamic>{
      'type': 'warning',
      'timer_name': 'My Timer',
      'started_at': '2026-01-01T10:00:00.000Z',
      'ended_at': '2026-01-01T11:00:00.000Z',
      'details': <String, dynamic>{
        'remaining_seconds': 60,
      },
    };

    test('parses correctly and returns the right class', () {
      final event = HistoryService.fromJson(json);
      expect(event, isA<TimerWarningEvent>());
    });

    test('parses all fields correctly', () {
      final event = HistoryService.fromJson(json) as TimerWarningEvent;
      expect(event.timerName, 'My Timer');
      expect(event.startedAt, startedAt);
      expect(event.endedAt, endedAt);
      expect(event.remainingSeconds, 60);
    });
  });

  group('TimerPausedEvent', () {
    final json = <String, dynamic>{
      'type': 'paused',
      'timer_name': 'My Timer',
      'started_at': '2026-01-01T10:00:00.000Z',
      'ended_at': '2026-01-01T10:30:00.000Z',
      'details': <String, dynamic>{
        'remaining_seconds': 300,
        'password_verified': false,
      },
    };
    final endedAt = DateTime.parse('2026-01-01T10:30:00.000Z');

    test('parses correctly and returns the right class', () {
      final event = HistoryService.fromJson(json);
      expect(event, isA<TimerPausedEvent>());
    });

    test('parses all fields correctly', () {
      final event = HistoryService.fromJson(json) as TimerPausedEvent;
      expect(event.timerName, 'My Timer');
      expect(event.startedAt, startedAt);
      expect(event.endedAt, endedAt);
      expect(event.remainingSeconds, 300);
      expect(event.passwordVerified, false);
    });
  });

  group('TimerCancelledEvent', () {
    final json = <String, dynamic>{
      'type': 'cancelled',
      'timer_name': 'My Timer',
      'started_at': '2026-01-01T10:00:00.000Z',
      'ended_at': '2026-01-01T10:30:00.000Z',
      'details': <String, dynamic>{
        'remaining_seconds': 300,
        'password_verified': true,
      },
    };
    final endedAt = DateTime.parse('2026-01-01T10:30:00.000Z');

    test('parses correctly and returns the right class', () {
      final event = HistoryService.fromJson(json);
      expect(event, isA<TimerCancelledEvent>());
    });

    test('parses all fields correctly', () {
      final event = HistoryService.fromJson(json) as TimerCancelledEvent;
      expect(event.timerName, 'My Timer');
      expect(event.startedAt, startedAt);
      expect(event.endedAt, endedAt);
      expect(event.remainingSeconds, 300);
      expect(event.passwordVerified, true);
    });
  });

  group('TimerExpiredEvent', () {
    final json = <String, dynamic>{
      'type': 'expired',
      'timer_name': 'My Timer',
      'started_at': '2026-01-01T10:00:00.000Z',
      'ended_at': '2026-01-01T11:00:00.000Z',
      'details': <String, dynamic>{
        'location': <String, dynamic>{'latitude': 1.234, 'longitude': 5.678},
        'polyline': 'some_encoded_polyline',
        'sms': [
          <String, dynamic>{'recipient': '+123', 'status': 'sent'}
        ],
        'emails': [
          <String, dynamic>{'recipient': 'test@example.com', 'status': 'sent'}
        ],
        'channels': [
          <String, dynamic>{'platform': 'Discord | #alerts', 'status': 'sent'}
        ],
        'alarm_triggered': true,
        'audio_recorded': false,
      },
    };

    test('parses correctly and returns the right class', () {
      final event = HistoryService.fromJson(json);
      expect(event, isA<TimerExpiredEvent>());
    });

    test('parses all fields correctly', () {
      final event = HistoryService.fromJson(json) as TimerExpiredEvent;
      expect(event.timerName, 'My Timer');
      expect(event.startedAt, startedAt);
      expect(event.endedAt, endedAt);
      expect(event.location, isNotNull);
      expect(event.location!['latitude'], 1.234);
      expect(event.location!['longitude'], 5.678);
      expect(event.polyline, 'some_encoded_polyline');
      expect(event.sms.length, 1);
      expect(event.sms.first['recipient'], '+123');
      expect(event.sms.first['status'], 'sent');
      expect(event.emails.length, 1);
      expect(event.emails.first['recipient'], 'test@example.com');
      expect(event.emails.first['status'], 'sent');
      expect(event.channels.length, 1);
      expect(event.channels.first['platform'], 'Discord | #alerts');
      expect(event.channels.first['status'], 'sent');
      expect(event.alarmTriggered, true);
      expect(event.audioRecorded, false);
    });

    test('handles missing optional fields', () {
      final json = <String, dynamic>{
        'type': 'expired',
        'timer_name': 'My Timer',
        'started_at': '2026-01-01T10:00:00.000Z',
        'ended_at': '2026-01-01T11:00:00.000Z',
        'details': <String, dynamic>{},
      };

      final event = HistoryService.fromJson(json) as TimerExpiredEvent;
      expect(event.timerName, 'My Timer');
      expect(event.startedAt, startedAt);
      expect(event.endedAt, endedAt);
      expect(event.location, isNull);
      expect(event.polyline, isNull);
      expect(event.sms, isEmpty);
      expect(event.emails, isEmpty);
      expect(event.channels, isEmpty);
      expect(event.alarmTriggered, false);
      expect(event.audioRecorded, false);
    });
  });

  group('Unknown type', () {
    test('throws UnsupportedError', () {
      expect(
        () => HistoryService.fromJson(<String, dynamic>{
          'type': 'unknown',
          'timer_name': 'My Timer',
          'started_at': '2026-01-01T10:00:00.000Z',
          'ended_at': null,
          'details': <String, dynamic>{},
        }),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('listFromJson', () {
    test('parses multiple events from a JSON string', () {
      final jsonString = '''
      {
        "events": [
          {
            "type": "started",
            "timer_name": "My Timer",
            "started_at": "2026-01-01T10:00:00.000Z",
            "ended_at": null,
            "details": {
              "duration_seconds": 3600,
              "grace_period_seconds": 60,
              "password_protected": true
            }
          },
          {
            "type": "warning",
            "timer_name": "My Timer",
            "started_at": "2026-01-01T10:00:00.000Z",
            "ended_at": "2026-01-01T11:00:00.000Z",
            "details": {
              "remaining_seconds": 60
            }
          },
          {
            "type": "paused",
            "timer_name": "My Timer",
            "started_at": "2026-01-01T10:00:00.000Z",
            "ended_at": "2026-01-01T10:30:00.000Z",
            "details": {
              "remaining_seconds": 300,
              "password_verified": false
            }
          }
        ]
      }
      ''';

      final events = HistoryService.listFromJson(jsonString);
      expect(events.length, 3);
      expect(events[0], isA<TimerStartedEvent>());
      expect(events[1], isA<TimerWarningEvent>());
      expect(events[2], isA<TimerPausedEvent>());

      final started = events[0] as TimerStartedEvent;
      expect(started.timerName, 'My Timer');
      expect(started.startedAt, startedAt);
      expect(started.endedAt, isNull);
      expect(started.durationSeconds, 3600);
      expect(started.gracePeriodSeconds, 60);
      expect(started.passwordProtected, true);

      final warning = events[1] as TimerWarningEvent;
      expect(warning.timerName, 'My Timer');
      expect(warning.startedAt, startedAt);
      expect(warning.endedAt, endedAt);
      expect(warning.remainingSeconds, 60);

      final paused = events[2] as TimerPausedEvent;
      expect(paused.timerName, 'My Timer');
      expect(paused.startedAt, startedAt);
      expect(paused.endedAt, DateTime.parse('2026-01-01T10:30:00.000Z'));
      expect(paused.remainingSeconds, 300);
      expect(paused.passwordVerified, false);
    });
  });

  group('Serialization round-trip (toJson → fromJson)', () {
    test('TimerStartedEvent round-trips through JSON', () {
      final original = TimerStartedEvent(
        timerName: 'My Timer',
        startedAt: startedAt,
        endedAt: null,
        durationSeconds: 3600,
        gracePeriodSeconds: 60,
        passwordProtected: true,
      );

      final roundTripped = HistoryService.fromJson(original.toJson()) as TimerStartedEvent;

      expect(roundTripped.timerName, original.timerName);
      expect(roundTripped.startedAt, original.startedAt);
      expect(roundTripped.endedAt, isNull);
      expect(roundTripped.durationSeconds, original.durationSeconds);
      expect(roundTripped.gracePeriodSeconds, original.gracePeriodSeconds);
      expect(roundTripped.passwordProtected, original.passwordProtected);
    });

    test('TimerWarningEvent round-trips through JSON', () {
      final original = TimerWarningEvent(
        timerName: 'My Timer',
        startedAt: startedAt,
        endedAt: endedAt,
        remainingSeconds: 60,
      );

      final roundTripped = HistoryService.fromJson(original.toJson()) as TimerWarningEvent;

      expect(roundTripped.timerName, original.timerName);
      expect(roundTripped.startedAt, original.startedAt);
      expect(roundTripped.endedAt, original.endedAt);
      expect(roundTripped.remainingSeconds, original.remainingSeconds);
    });

    test('TimerCancelledEvent round-trips through JSON', () {
      final ended = DateTime.parse('2026-01-01T10:30:00.000Z');
      final original = TimerCancelledEvent(
        timerName: 'My Timer',
        startedAt: startedAt,
        endedAt: ended,
        remainingSeconds: 300,
        passwordVerified: true,
      );

      final roundTripped = HistoryService.fromJson(original.toJson()) as TimerCancelledEvent;

      expect(roundTripped.timerName, original.timerName);
      expect(roundTripped.startedAt, original.startedAt);
      expect(roundTripped.endedAt, original.endedAt);
      expect(roundTripped.remainingSeconds, original.remainingSeconds);
      expect(roundTripped.passwordVerified, original.passwordVerified);
    });

    test('TimerExpiredEvent round-trips through JSON with all optional fields populated', () {
      final original = TimerExpiredEvent(
        timerName: 'My Timer',
        startedAt: startedAt,
        endedAt: endedAt,
        location: {'latitude': 1.234, 'longitude': 5.678},
        polyline: 'some_encoded_polyline',
        sms: [{'recipient': '+123', 'status': 'sent'}],
        emails: [{'recipient': 'test@example.com', 'status': 'sent'}],
        channels: [{'platform': 'Discord | #alerts', 'status': 'sent'}],
        alarmTriggered: true,
        audioRecorded: false,
      );

      final roundTripped = HistoryService.fromJson(original.toJson()) as TimerExpiredEvent;

      expect(roundTripped.timerName, original.timerName);
      expect(roundTripped.startedAt, original.startedAt);
      expect(roundTripped.endedAt, original.endedAt);
      expect(roundTripped.location!['latitude'], 1.234);
      expect(roundTripped.location!['longitude'], 5.678);
      expect(roundTripped.polyline, original.polyline);
      expect(roundTripped.sms.length, original.sms.length);
      expect(roundTripped.emails.length, original.emails.length);
      expect(roundTripped.channels.length, original.channels.length);
      expect(roundTripped.alarmTriggered, original.alarmTriggered);
      expect(roundTripped.audioRecorded, original.audioRecorded);
    });

    test('TimerExpiredEvent round-trips through JSON when all optional fields are null', () {
      final original = TimerExpiredEvent(
        timerName: 'My Timer',
        startedAt: startedAt,
        endedAt: endedAt,
        location: null,
        polyline: null,
        sms: [],
        emails: [],
        channels: [],
        alarmTriggered: false,
        audioRecorded: false,
      );

      final roundTripped = HistoryService.fromJson(original.toJson()) as TimerExpiredEvent;

      expect(roundTripped.timerName, original.timerName);
      expect(roundTripped.startedAt, original.startedAt);
      expect(roundTripped.endedAt, original.endedAt);
      expect(roundTripped.location, isNull);
      expect(roundTripped.polyline, isNull);
      expect(roundTripped.sms, isEmpty);
      expect(roundTripped.emails, isEmpty);
      expect(roundTripped.channels, isEmpty);
      expect(roundTripped.alarmTriggered, isFalse);
      expect(roundTripped.audioRecorded, isFalse);
    });

    test('TimerExpiredEvent with unicode timer name round-trips through JSON', () {
      final original = TimerExpiredEvent(
        timerName: 'Urgent! ⚠️ Café ☕',
        startedAt: startedAt,
        endedAt: endedAt,
        location: null,
        polyline: null,
        sms: [],
        emails: [],
        channels: [],
        alarmTriggered: false,
        audioRecorded: false,
      );

      final roundTripped = HistoryService.fromJson(original.toJson()) as TimerExpiredEvent;

      expect(roundTripped.timerName, original.timerName);
    });
  });
}
