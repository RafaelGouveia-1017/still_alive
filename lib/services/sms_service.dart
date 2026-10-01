import 'package:send_message/send_message.dart';
import 'package:permission_handler/permission_handler.dart';

/// A service responsible for sending SMS messages.
///
/// This service provides a unified interface for sending SMS messages across
/// supported platforms.
///
/// Platform behavior:
/// - Android: Sends messages directly using the system SMS manager.
/// - iOS: Opens the system message composer where the user must manually send
///   the message.
///
/// Example:
/// ```dart
/// final result = await SmsService().send(
///   phoneNumbers: ['+1234567890'],
///   message: 'Hello!',
/// );
/// ```
class SmsService {
  const SmsService();

  /// Sends an SMS message to the provided phone numbers.
  ///
  /// On Android:
  /// - Checks for the `SEND_SMS` permission.
  /// - Sends the message directly using the device SMS service.
  ///
  /// On iOS:
  /// - Opens the system SMS composer.
  /// - Requires the user to confirm and send the message manually.
  ///
  /// Returns:
  /// - [SmsResult.sent] when the SMS is successfully sent.
  /// - [SmsResult.permissionDenied] if SMS permission is denied.
  /// - [SmsResult.failed] when sending fails.
  Future<SmsResult> send({required List<String> phoneNumbers, required String message}) async {
    final permission = await Permission.sms.status;
    if (!permission.isGranted) {
      return SmsResult.permissionDenied;
    }

    try {
      await sendSMS(message: message, recipients: phoneNumbers, sendDirect: true);

      return SmsResult.sent;
    } catch (e) {
      return SmsResult.failed;
    }
  }
}

/// Represents the possible outcomes of an SMS sending operation.
///
/// Values:
/// - [SmsResult.sent]: The SMS was sent successfully.
/// - [SmsResult.permissionDenied]: Required SMS permission is not granted.
/// - [SmsResult.failed]: Sending failed due to an error.
enum SmsResult {
  /// Indicates that the SMS was sent successfully.
  sent,

  /// Indicates that the required SMS permission is denied.
  permissionDenied,

  /// Indicates that sending the SMS failed.
  failed,
}
