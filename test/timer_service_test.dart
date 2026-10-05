import 'package:flutter_test/flutter_test.dart';
import 'package:still_alive/services/timer_service.dart';

void main() {
  group('TimerService.formatDuration', () {
    test('returns "0s" for Duration.zero', () {
      expect(TimerService.formatDuration(Duration.zero), '0s');
    });

    test('returns "30s" for 30 seconds', () {
      expect(TimerService.formatDuration(Duration(seconds: 30)), '30s');
    });

    test('returns "05m" for 5 minutes', () {
      expect(TimerService.formatDuration(Duration(minutes: 5)), '05m');
    });

    test('returns "01h 05m 30s" for 1 hour, 5 minutes, 30 seconds', () {
      expect(
        TimerService.formatDuration(Duration(hours: 1, minutes: 5, seconds: 30)),
        '01h 05m 30s',
      );
    });

    test('returns "01m" for 60 seconds', () {
      expect(TimerService.formatDuration(Duration(seconds: 60)), '01m');
    });

    test('returns "01h" for 3600 seconds', () {
      expect(TimerService.formatDuration(Duration(seconds: 3600)), '01h');
    });

    test('returns "01m 30s" for 90 seconds (mixed units)', () {
      expect(TimerService.formatDuration(Duration(seconds: 90)), '01m 30s');
    });

    test('returns "59m 59s" for 3599 seconds (one second under an hour)', () {
      expect(TimerService.formatDuration(Duration(seconds: 3599)), '59m 59s');
    });

    test('returns "09h 09m 09s" for 9h 9m 9s (zero-padding)', () {
      expect(
        TimerService.formatDuration(Duration(hours: 9, minutes: 9, seconds: 9)),
        '09h 09m 09s',
      );
    });

    test('returns "25h 01m 01s" for 1 day, 1 hour, 1 minute, 1 second (hours accumulate)', () {
      expect(
        TimerService.formatDuration(Duration(days: 1, hours: 1, minutes: 1, seconds: 1)),
        '25h 01m 01s',
      );
    });

    test('returns "0s" for sub-second duration (milliseconds)', () {
      expect(TimerService.formatDuration(Duration(milliseconds: 500)), '0s');
    });

    test('returns "10h" for 10 hours (no zero-padded single-digit units)', () {
      expect(TimerService.formatDuration(Duration(hours: 10)), '10h');
    });

    test('omits zero-valued units (only minutes)', () {
      expect(TimerService.formatDuration(Duration(minutes: 45)), '45m');
    });
  });

  group('TimerService.generatePasswordHash', () {
    test('produces a different hash each call for the same password', () {
      const password = 'hunter2';
      final hash1 = TimerService.generatePasswordHash(password);
      final hash2 = TimerService.generatePasswordHash(password);

      expect(hash1, isNot(hash2));
      // BCrypt hashes start with '$2a$10$' by default.
      expect(hash1, startsWith(r'$2'));
    });

    test('produces a different hash for different passwords', () {
      final hash1 = TimerService.generatePasswordHash('password1');
      final hash2 = TimerService.generatePasswordHash('password2');

      expect(hash1, isNot(hash2));
    });
  });

  group('TimerService.verifyPassword', () {
    test('returns true when the password matches the hash', () {
      const password = 'correct horse battery staple';
      final hash = TimerService.generatePasswordHash(password);

      expect(TimerService.verifyPassword(password, hash), isTrue);
    });

    test('returns false when the password does not match the hash', () {
      const password = 'correct horse battery staple';
      const wrongPassword = 'wrong password';
      final hash = TimerService.generatePasswordHash(password);

      expect(TimerService.verifyPassword(wrongPassword, hash), isFalse);
    });
  });
}
