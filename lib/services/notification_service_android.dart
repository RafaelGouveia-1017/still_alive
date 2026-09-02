import 'package:flutter/services.dart';
import 'native/method_channel.dart';

/// Provides access to the native Android notification implementation.
///
/// This service communicates with the Android application through a
/// [MethodChannel] and allows Flutter to create and display different types
/// of Android notifications.
///
/// Supported notification types include:
///
/// - [NotificationType.normal] for regular notifications.
/// - [NotificationType.fullScreen] for notifications that can launch the
///   application's full-screen activity.
/// - [NotificationType.silent] for notifications that should not actively
///   interrupt the user.
///
/// The service is intended to be used as a static API because notification
/// requests do not require an instance of this class.
///
/// Example:
///
/// ```dart
/// await AndroidNotificationService.launchNotification(
///   title: 'StillAlive',
///   description: 'Your reminder is ready.',
/// );
/// ```
class AndroidNotificationService {
  /// Displays an Android notification using the supplied configuration.
  ///
  /// The notification request is forwarded to the native Android
  /// implementation through the application's [MethodChannel].
  ///
  /// The [title] is required and represents the main notification title.
  /// [description] optionally specifies the notification body text.
  ///
  /// The [type] determines how Android should present the notification:
  ///
  /// - [NotificationType.normal] creates a regular notification.
  /// - [NotificationType.fullScreen] creates a notification with a
  ///   full-screen intent.
  /// - [NotificationType.silent] creates a low-interruption notification.
  ///
  /// [notificationId] identifies the notification on Android. Reusing the
  /// same identifier replaces the existing notification with the new one.
  ///
  /// [autoCancel] determines whether Android should automatically remove
  /// the notification when the user interacts with it.
  ///
  /// [ongoing] determines whether the notification should be treated as an
  /// ongoing notification. Ongoing notifications generally cannot be
  /// dismissed by the user with a normal swipe.
  ///
  /// [priority] controls the notification priority used by the native
  /// Android implementation.
  ///
  /// [category] specifies the Android notification category. For example,
  /// `'alarm'` can be used for alarm-related notifications.
  ///
  /// [playSound] optionally overrides whether the notification should play
  /// a sound. When omitted, the native implementation chooses a default
  /// based on the notification type.
  ///
  /// [vibrate] optionally overrides whether the notification should vibrate.
  /// When omitted, the native implementation chooses a default based on the
  /// notification type.
  ///
  /// [alarmId] optionally associates the notification with a specific alarm.
  /// This value is passed to the native full-screen activity and is useful
  /// when [type] is [NotificationType.fullScreen].
  ///
  /// Throws a [PlatformException] if the native Android implementation
  /// reports an error while creating or displaying the notification.
  ///
  /// Example of types of notifications:
  ///
  /// ```dart
  /// //Normal notification
  /// await AndroidNotificationService.launchNotification(
  ///   title: 'StillAlive',
  ///   description: 'Your timer is ready.',
  /// );
  ///
  /// //Full-screen notification
  /// await AndroidNotificationService.launchNotification(
  ///   title: 'Wake up!',
  ///   description: 'Your timer has expired.',
  ///   type: NotificationType.fullScreen,
  ///   notificationId: 1001,
  ///   autoCancel: false,
  ///   ongoing: true,
  ///   priority: NotificationPriority.max,
  ///   category: 'alarm',
  ///   alarmId: 42,
  /// );
  ///
  /// //Silent notification
  /// await AndroidNotificationService.launchNotification(
  ///   title: 'Background update',
  ///   description: 'Your data has been synchronized.',
  ///   type: NotificationType.silent,
  ///   notificationId: 3001,
  ///   autoCancel: true,
  ///   ongoing: false,
  /// );
  ///
  /// //Silent + ongoing
  /// await AndroidNotificationService.launchNotification(
  ///   title: 'StillAlive is running',
  ///   description: 'Monitoring your scheduled alarms.',
  ///   type: NotificationType.silent,
  ///   notificationId: 3002,
  ///   autoCancel: false,
  ///   ongoing: true,
  ///   playSound: false,
  ///   vibrate: false,
  /// );
  /// ```
  static Future<void> launchNotification({
    required String title,
    String description = '',
    NotificationType type = NotificationType.normal,
    int notificationId = 2000,
    bool autoCancel = true,
    bool ongoing = false,
    NotificationPriority priority = NotificationPriority.defaultPriority,
    String category = 'status',
    bool? playSound,
    bool? vibrate,
    int? alarmId,
  }) async {
    await AppMethodChannel.instance.invokeMethod('launchNotification', {
      'title': title,
      'description': description,
      'notificationType': type.value,
      'notificationId': notificationId,
      'autoCancel': autoCancel,
      'ongoing': ongoing,
      'priority': priority.value,
      'category': category,
      'playSound': playSound,
      'vibrate': vibrate,
      'alarmId': alarmId,
    });
  }
}

/// Defines the presentation behavior of an Android notification
enum NotificationType {
  /// A standard notification.
  normal,

  /// A notification that may launch the application's full-screen activity.
  fullScreen,

  /// A notification intended to be delivered without actively interrupting
  /// the user.
  silent;

  String get value {
    switch (this) {
      case NotificationType.normal:
        return 'normal';

      case NotificationType.fullScreen:
        return 'fullScreen';

      case NotificationType.silent:
        return 'silent';
    }
  }
}

/// Defines the priority of an Android notification.
///
/// The priority is converted to the corresponding Android notification
/// priority by the native implementation.
enum NotificationPriority {
  /// Lowest notification priority.
  min,

  /// Low notification priority.
  low,

  /// Default notification priority.
  defaultPriority,

  /// High notification priority.
  high,

  /// Maximum notification priority.
  max;

  String get value {
    switch (this) {
      case NotificationPriority.min:
        return 'min';

      case NotificationPriority.low:
        return 'low';

      case NotificationPriority.defaultPriority:
        return 'default';

      case NotificationPriority.high:
        return 'high';

      case NotificationPriority.max:
        return 'max';
    }
  }
}
