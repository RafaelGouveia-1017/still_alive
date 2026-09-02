import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/data/all.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/views/widgets/primitives.dart';
import 'package:url_launcher/url_launcher.dart';

/// Defines the available color tone variants used for history-related UI.
///
/// Each value provides a themed foreground and background color through the
/// [foreground] and [background] methods.
enum HistoryColorTones {
  /// Uses the application's primary color.
  primary,

  /// Uses the tertiary color to indicate a safe or successful state.
  safe,

  /// Uses the secondary color to emphasize highlighted content.
  highlight,

  /// Uses the error color to indicate a critical or destructive state.
  danger,

  /// Uses the error color with a less critical semantic for warnings.
  warning,

  /// Uses a subdued color for secondary or de-emphasized content.
  muted;

  /// Returns the foreground color associated with this tone.
  ///
  /// The returned color is resolved from the current theme's [ColorScheme].
  Color foreground(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    switch (this) {
      case HistoryColorTones.safe:
        return scheme.tertiary;
      case HistoryColorTones.highlight:
        return scheme.secondary;
      case HistoryColorTones.danger:
        return scheme.error;
      case HistoryColorTones.warning:
        return scheme.error.withValues(
          green: scheme.error.g + 30,
          blue: scheme.error.b + 30,
        );
      case HistoryColorTones.muted:
        return scheme.onSurfaceVariant;
      default:
        return scheme.primary;
    }
  }

  /// Returns the background color associated with this tone.
  ///
  /// The returned color is a translucent variant of the corresponding
  /// foreground color, resolved from the current theme's [ColorScheme].
  Color background(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    switch (this) {
      case HistoryColorTones.safe:
        return scheme.tertiary.withAlpha(38);
      case HistoryColorTones.highlight:
        return scheme.secondary.withAlpha(38);
      case HistoryColorTones.danger:
        return scheme.error.withAlpha(38);
      case HistoryColorTones.warning:
        return scheme.error.withValues(
          alpha: 38,
          green: scheme.error.g + 30,
          blue: scheme.error.b + 30,
        );
      case HistoryColorTones.muted:
        return scheme.onSurfaceVariant.withAlpha(38);
      default:
        return scheme.primary.withAlpha(38);
    }
  }
}

/// Provides utility methods for managing the application's timer history.
///
/// A history record consists of one or more [HistoryEvent]s grouped by their
/// creation date. This service is responsible for:
///
/// * Parsing history events from JSON.
/// * Parsing collections of history events.
/// * Persisting new timer events into the local history database.
class HistoryService {
  const HistoryService();

  /// Creates a [HistoryEvent] from its JSON representation.
  ///
  /// The returned object is the concrete subclass corresponding to the event's
  /// `type` field.
  ///
  /// Supported event types are:
  /// * `started`
  /// * `warning`
  /// * `paused`
  /// * `cancelled`
  /// * `expired`
  ///
  /// Throws an [UnsupportedError] if the event type is unknown.
  static HistoryEvent fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'started':
        return TimerStartedEvent.fromJson(json);
      case 'warning':
        return TimerWarningEvent.fromJson(json);
      case 'paused':
        return TimerPausedEvent.fromJson(json);
      case 'cancelled':
        return TimerCancelledEvent.fromJson(json);
      case 'expired':
        return TimerExpiredEvent.fromJson(json);

      default:
        throw UnsupportedError('Unknown history event type: ${json['type']}');
    }
  }

  /// Parses a JSON document containing a collection of history events.
  ///
  /// The JSON is expected to contain an `events` array whose elements represent
  /// individual timer events.
  ///
  /// Returns a list of strongly-typed [HistoryEvent] instances.
  static List<HistoryEvent> listFromJson(String jsonString) {
    final json = jsonDecode(jsonString);

    final events = (json['events'] as List).cast<Map<String, dynamic>>();

    return events.map(fromJson).toList();
  }

  /// Persists a timer event into the database.
  ///
  /// Events are grouped by calendar day. If a history record already exists for
  /// today's date, the event is appended to its `events` array and the `count`
  /// field is updated accordingly.
  ///
  /// Otherwise, a new history record is created containing only the supplied
  /// event.
  static Future<void> insertHistoryRecord(HistoryEvent event) async {
    String date = DateTime.now()
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0)
        .toIso8601String()
        .split('T')
        .first;

    final eventJson = event.toJson();
    final value = jsonEncode({
      'count': 1,
      'events': [eventJson],
    });

    await executeBatchSql(
      sql:
          """
          INSERT INTO history (created_at, value)
          VALUES (
              '$date',
              json('$value')
          )
          ON CONFLICT(created_at)
          DO UPDATE SET value = json_set(
              json_set(
                  history.value,
                  '\$.events',
                  (
                      SELECT json_group_array(value)
                      FROM (
                          SELECT json_each.value AS value
                          FROM json_each(history.value, '\$.events')

                          UNION ALL

                          SELECT json('${jsonEncode(eventJson)}')
                      )
                  )
              ),
              '\$.count',
              json_array_length(
                  json_extract(
                      json_set(
                          history.value,
                          '\$.events',
                          (
                              SELECT json_group_array(value)
                              FROM (
                                  SELECT json_each.value AS value
                                  FROM json_each(history.value, '\$.events')

                                  UNION ALL

                                  SELECT json('${jsonEncode(eventJson)}')
                              )
                          )
                      ),
                      '\$.events'
                  )
              )
          );
          """,
    );
  }
}

/// Represents a single timer-related event recorded in the application's
/// history.
///
/// Every event stores common metadata shared by all timer events, including:
///
/// * [icon] - The icon that represents the timer event.
/// * [type] - The type of timer event.
/// * [tone] - The semantic severity associated with the event.
/// * [timerName] - The name of the timer that generated the event.
/// * [startedAt] - The timestamp at which the event began.
/// * [endedAt] - The timestamp at which the event completed, if applicable.
///
/// The currently supported event types are:
///
/// | Type | Description | Concrete class |
/// | ---- | ----------- | -------------- |
/// | `started` | A timer was started. | [TimerStartedEvent] |
/// | `warning` | A pre-expiration warning was issued. | [TimerWarningEvent] |
/// | `paused` | A timer was temporarily paused. | [TimerPausedEvent] |
/// | `cancelled` | A timer was cancelled before expiration. | [TimerCancelledEvent] |
/// | `expired` | A timer expired and the emergency protocol was executed. | [TimerExpiredEvent] |
///
/// Instances of this class are created through [HistoryService.fromJson],
/// which returns the appropriate concrete subclass based on the event's
/// `type` field.
abstract class HistoryEvent {
  IconData get icon;
  String get type;
  HistoryColorTones get tone;

  final String timerName;
  final DateTime startedAt;
  final DateTime? endedAt;

  const HistoryEvent({
    required this.timerName,
    required this.startedAt,
    required this.endedAt,
  });

  /// Converts this history event into its JSON representation.
  ///
  /// The returned map contains the common event fields and any
  /// event-specific data required to reconstruct the event with
  /// [HistoryService.fromJson].
  ///
  /// The resulting map is suitable for passing to [jsonEncode].
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'timer_name': timerName,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'details': detailsToJson(),
    };
  }

  /// Converts the event-specific properties into a JSON-compatible map.
  ///
  /// The returned map is stored under the `details` field of the event's
  /// JSON representation by [toJson].
  ///
  /// Subclasses must include all event-specific data required by their
  /// corresponding `fromJson` factory.
  Map<String, dynamic> detailsToJson();

  /// Returns the localized title describing this history event.
  String getTitle(AppLocalizations local);

  /// Returns a short summary describing the event.
  String getSubtitle(bool is24HourFormat, AppLocalizations local);

  /// Builds a widget displaying all information associated with this event.
  ///
  /// Implementations should present every event-specific property in a readable
  /// tabular format suitable for inspection by the user.
  Widget toTable(BuildContext context);

  /// Formats a [DateTime] as a localized 12-hour or 24-hour time string.
  ///
  /// When [is24HourFormat] is `true`, the returned value uses the `HH:mm`
  /// format. Otherwise, it uses the `hh:mm AM/PM` format.
  ///
  /// Midnight is represented as `12:00 AM` and noon as `12:00 PM` when using
  /// the 12-hour format.
  ///
  /// ## Examples
  ///
  /// ```dart
  /// _formatTime(
  ///   DateTime(2026, 1, 1, 9, 5),
  ///   true,
  /// ); // '09:05'
  ///
  /// _formatTime(
  ///   DateTime(2026, 1, 1, 9, 5),
  ///   false,
  /// ); // '09:05 AM'
  ///
  /// _formatTime(
  ///   DateTime(2026, 1, 1, 12, 30),
  ///   false,
  /// ); // '12:30 PM'
  /// ```
  String _formatTime(DateTime dateTime, bool is24HourFormat) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;

    if (is24HourFormat) {
      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';
    }

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '${displayHour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} $period';
  }

  /// Creates a table row containing a label and its associated value.
  ///
  /// This helper is intended for subclasses when implementing [toTable].
  ///
  /// If [value] is `null`, a dash (`-`) is displayed instead.
  TableRow _row(
    String label,
    Object? value,
    ColorScheme scheme,
    VoidCallback? onTap,
  ) {
    Widget child = Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        value?.toString() ?? "-",
        style: AppText.caption(scheme),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            label,
            style: AppText.micro(scheme).copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (onTap != null) Pressable(onTap: onTap, child: child) else child,
      ],
    );
  }
}

/// Represents the creation or activation of a timer.
///
/// This event is recorded whenever a timer starts and contains the timer's
/// initial configuration, including its duration, grace period and whether
/// password protection was enabled.
class TimerStartedEvent extends HistoryEvent {
  @override
  IconData get icon => LucideIcons.play;

  @override
  String get type => 'started';

  @override
  HistoryColorTones get tone => HistoryColorTones.primary;

  final int durationSeconds;
  final int? gracePeriodSeconds;
  final bool passwordProtected;

  TimerStartedEvent({
    required super.timerName,
    required super.startedAt,
    required super.endedAt,
    required this.durationSeconds,
    required this.gracePeriodSeconds,
    required this.passwordProtected,
  });

  factory TimerStartedEvent.fromJson(Map<String, dynamic> json) {
    final details = json['details'] as Map<String, dynamic>;

    return TimerStartedEvent(
      timerName: json['timer_name'],
      startedAt: DateTime.parse(json['started_at']),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at']),
      durationSeconds: details['duration_seconds'],
      gracePeriodSeconds: details['grace_period_seconds'],
      passwordProtected: details['password_protected'],
    );
  }

  @override
  Map<String, dynamic> detailsToJson() {
    return {
      'duration_seconds': durationSeconds,
      'grace_period_seconds': gracePeriodSeconds,
      'password_protected': passwordProtected,
    };
  }

  @override
  String getTitle(AppLocalizations local) =>
      local.translate("history_logs.events.started");

  @override
  String getSubtitle(bool is24HourFormat, AppLocalizations local) =>
      _formatTime(startedAt, is24HourFormat);

  @override
  Widget toTable(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      border: TableBorder.all(color: scheme.outline),
      children: [
        _row(
          local.translate("history_logs.events.details.type"),
          type,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.timer"),
          timerName,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.started"),
          startedAt,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.ended"),
          endedAt,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.duration"),
          '${durationSeconds}s',
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.grace"),
          '${gracePeriodSeconds}s',
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.pin_protected"),
          passwordProtected,
          scheme,
          null,
        ),
      ],
    );
  }
}

/// Represents a pre-expiration warning emitted by a timer.
///
/// This event indicates that the timer is approaching expiration and records
/// the remaining time when the warning was issued.
class TimerWarningEvent extends HistoryEvent {
  @override
  IconData get icon => LucideIcons.shieldAlert;

  @override
  String get type => 'warning';

  @override
  HistoryColorTones get tone => HistoryColorTones.warning;

  final int remainingSeconds;

  TimerWarningEvent({
    required super.timerName,
    required super.startedAt,
    required super.endedAt,
    required this.remainingSeconds,
  });

  factory TimerWarningEvent.fromJson(Map<String, dynamic> json) {
    final details = json['details'] as Map<String, dynamic>;

    return TimerWarningEvent(
      timerName: json['timer_name'],
      startedAt: DateTime.parse(json['started_at']),
      endedAt: DateTime.parse(json['ended_at']),
      remainingSeconds: details['remaining_seconds'],
    );
  }

  @override
  Map<String, dynamic> detailsToJson() {
    return {'remaining_seconds': remainingSeconds};
  }

  @override
  String getTitle(AppLocalizations local) =>
      local.translate("history_logs.events.warning");

  @override
  String getSubtitle(bool is24HourFormat, AppLocalizations local) =>
      '${_formatTime(startedAt, is24HourFormat)} • ${remainingSeconds}s';

  @override
  Widget toTable(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      border: TableBorder.all(color: scheme.outline),
      children: [
        _row(
          local.translate("history_logs.events.details.type"),
          type,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.timer"),
          timerName,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.started"),
          startedAt,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.ended"),
          endedAt,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.remaining"),
          '${remainingSeconds}s',
          scheme,
          null,
        ),
      ],
    );
  }
}

/// Represents the temporary suspension of an active timer.
///
/// This event is recorded whenever a running timer is paused by the user.
/// It stores the amount of time remaining at the moment the timer was paused,
/// allowing the timer to be resumed later.
class TimerPausedEvent extends HistoryEvent {
  @override
  IconData get icon => LucideIcons.pause;

  @override
  String get type => 'paused';

  @override
  HistoryColorTones get tone => HistoryColorTones.muted;

  /// The remaining duration, in seconds, when the timer was paused.
  final int remainingSeconds;

  TimerPausedEvent({
    required super.timerName,
    required super.startedAt,
    required super.endedAt,
    required this.remainingSeconds,
  });

  factory TimerPausedEvent.fromJson(Map<String, dynamic> json) {
    final details = json['details'] as Map<String, dynamic>;

    return TimerPausedEvent(
      timerName: json['timer_name'],
      startedAt: DateTime.parse(json['started_at']),
      endedAt: DateTime.parse(json['ended_at']),
      remainingSeconds: details['remaining_seconds'],
    );
  }

  @override
  Map<String, dynamic> detailsToJson() {
    return {'remaining_seconds': remainingSeconds};
  }

  @override
  String getTitle(AppLocalizations local) =>
      local.translate("history_logs.events.paused");

  @override
  String getSubtitle(bool is24HourFormat, AppLocalizations local) =>
      _formatTime(endedAt!, is24HourFormat);

  @override
  Widget toTable(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      border: TableBorder.all(color: scheme.outline),
      children: [
        _row(
          local.translate("history_logs.events.details.type"),
          type,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.timer"),
          timerName,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.started"),
          startedAt,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.ended"),
          endedAt,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.remaining"),
          '${remainingSeconds}s',
          scheme,
          null,
        ),
      ],
    );
  }
}

/// Represents the manual cancellation of an active timer.
///
/// This event records the amount of time remaining when the timer was
/// cancelled, as well as whether password verification was successfully
/// performed when required.
class TimerCancelledEvent extends HistoryEvent {
  @override
  IconData get icon => LucideIcons.shieldCheck;

  @override
  String get type => 'cancelled';

  @override
  HistoryColorTones get tone => HistoryColorTones.safe;

  final int remainingSeconds;
  final bool passwordVerified;

  TimerCancelledEvent({
    required super.timerName,
    required super.startedAt,
    required super.endedAt,
    required this.remainingSeconds,
    required this.passwordVerified,
  });

  factory TimerCancelledEvent.fromJson(Map<String, dynamic> json) {
    final details = json['details'] as Map<String, dynamic>;

    return TimerCancelledEvent(
      timerName: json['timer_name'],
      startedAt: DateTime.parse(json['started_at']),
      endedAt: DateTime.parse(json['ended_at']),
      remainingSeconds: details['remaining_seconds'],
      passwordVerified: details['password_verified'],
    );
  }

  @override
  Map<String, dynamic> detailsToJson() {
    return {
      'remaining_seconds': remainingSeconds,
      'password_verified': passwordVerified,
    };
  }

  @override
  String getTitle(AppLocalizations local) =>
      local.translate("history_logs.events.cancelled");

  @override
  String getSubtitle(bool is24HourFormat, AppLocalizations local) {
    int howLong = endedAt!.difference(startedAt).inSeconds;
    int hours = howLong ~/ 3600;
    int minutes = (howLong % 3600) ~/ 60;
    int seconds = howLong % 60;
    List<String> parts = [];

    if (hours > 0) {
      parts.add('${hours.toString().padLeft(2, '0')}h');
    }
    if (minutes > 0) {
      parts.add('${minutes.toString().padLeft(2, '0')}m');
    }
    if (seconds > 0 || parts.isEmpty) {
      parts.add('${seconds.toString().padLeft(2, '0')}s');
    }

    final formatted = parts.join(' ');

    return '${_formatTime(endedAt!, is24HourFormat)} • $formatted';
  }

  @override
  Widget toTable(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      border: TableBorder.all(color: scheme.outline),
      children: [
        _row(
          local.translate("history_logs.events.details.type"),
          type,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.timer"),
          timerName,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.started"),
          startedAt,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.ended"),
          endedAt,
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.remaining"),
          '${remainingSeconds}s',
          scheme,
          null,
        ),
        _row(
          local.translate("history_logs.events.details.pin_verified"),
          passwordVerified,
          scheme,
          null,
        ),
      ],
    );
  }
}

/// Represents the expiration of a timer and the execution of the emergency
/// protocol.
///
/// Besides the common event information, this event contains details about
/// the actions performed after expiration, such as:
///
/// * the location shared with emergency contacts;
/// * SMS messages sent;
/// * emails sent;
/// * third-party communication channels notified;
/// * whether the offline alarm was triggered;
/// * whether ambient audio recording was started.
class TimerExpiredEvent extends HistoryEvent {
  @override
  IconData get icon => LucideIcons.triangleAlert;

  @override
  String get type => 'expired';

  @override
  HistoryColorTones get tone => HistoryColorTones.danger;

  final Map<String, dynamic>? location;
  final String? polyline;
  final List<dynamic> sms;
  final List<dynamic> emails;
  final List<dynamic> channels;
  final bool alarmTriggered;
  final bool audioRecorded;

  TimerExpiredEvent({
    required super.timerName,
    required super.startedAt,
    required super.endedAt,
    required this.location,
    required this.polyline,
    required this.sms,
    required this.emails,
    required this.channels,
    required this.alarmTriggered,
    required this.audioRecorded,
  });

  factory TimerExpiredEvent.fromJson(Map<String, dynamic> json) {
    final details = json['details'] as Map<String, dynamic>;

    return TimerExpiredEvent(
      timerName: json['timer_name'],
      startedAt: DateTime.parse(json['started_at']),
      endedAt: DateTime.parse(json['ended_at']),
      location: details['location'],
      polyline: details['polyline'],
      sms: List<dynamic>.from(details['sms'] ?? []),
      emails: List<dynamic>.from(details['emails'] ?? []),
      channels: List<dynamic>.from(details['channels'] ?? []),
      alarmTriggered: details['alarm_triggered'] ?? false,
      audioRecorded: details['audio_recorded'] ?? false,
    );
  }

  @override
  Map<String, dynamic> detailsToJson() {
    return {
      'location': location,
      'polyline': polyline,
      'sms': sms,
      'emails': emails,
      'channels': channels,
      'alarm_triggered': alarmTriggered,
      'audio_recorded': audioRecorded,
    };
  }

  @override
  String getTitle(AppLocalizations local) =>
      local.translate("history_logs.events.expired");

  @override
  String getSubtitle(bool is24HourFormat, AppLocalizations local) {
    final successfulAlerts = [
      ...sms,
      ...emails,
      ...channels,
    ].where((e) => e['status'] == 'sent').length;

    String alerts = successfulAlerts == 1
        ? local.translate("history_logs.events.alert.0")
        : local.translate("history_logs.events.alert.1");

    String sent = successfulAlerts == 1
        ? local.translate("history_logs.events.sent.0")
        : local.translate("history_logs.events.sent.1");

    return '${_formatTime(endedAt!, is24HourFormat)} • $successfulAlerts $alerts $sent';
  }

  @override
  Widget toTable(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        border: TableBorder.all(color: scheme.outline),
        children: [
          _row(
            local.translate("history_logs.events.details.type"),
            type,
            scheme,
            null,
          ),
          _row(
            local.translate("history_logs.events.details.timer"),
            timerName,
            scheme,
            null,
          ),
          _row(
            local.translate("history_logs.events.details.started"),
            startedAt,
            scheme,
            null,
          ),
          _row(
            local.translate("history_logs.events.details.ended"),
            endedAt,
            scheme,
            null,
          ),
          _row(
            local.translate("history_logs.events.details.alarm"),
            alarmTriggered,
            scheme,
            null,
          ),
          _row(
            local.translate("history_logs.events.details.audio"),
            audioRecorded,
            scheme,
            null,
          ),

          _row(
            local.translate("history_logs.events.details.location"),
            location == null
                ? "-"
                : '${location!["latitude"]}, ${location!["longitude"]}',
            scheme,
            location == null
                ? null
                : () {
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            '${location!["latitude"]}, ${location!["longitude"]}',
                      ),
                    );
                    launchUrl(
                      Uri.parse(
                        'https://www.google.com/search?q=google+maps+${location!["latitude"]}+${location!["longitude"]}',
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                  },
          ),
          _row(
            "${local.translate("history_logs.events.details.route")} (Polyline)",
            polyline == null ? "-" : polyline!,
            scheme,
            polyline == null
                ? null
                : () {
                    Clipboard.setData(
                      ClipboardData(text: polyline!),
                    ).whenComplete(() {
                      showToast(
                        scheme: scheme,
                        toast: Text(
                          local.translate("history_logs.events.polyline_copy"),
                          style: AppText.bodySm(scheme),
                          textAlign: TextAlign.center,
                        ),
                        gravity: ToastGravity.BOTTOM,
                        position: (context, child, gravity) {
                          return Positioned(
                            bottom: 170,
                            left: 30,
                            right: 30,
                            child: child,
                          );
                        },
                      );
                      launchUrl(
                        Uri.parse(
                          'https://tools.nextbillion.ai/polyline-decoder',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                    });
                  },
          ),

          _row(
            local.translate("history_logs.events.details.sms_length"),
            sms.length,
            scheme,
            null,
          ),
          _row(
            local.translate("history_logs.events.details.emails_length"),
            emails.length,
            scheme,
            null,
          ),
          _row(
            local.translate("history_logs.events.details.channels_length"),
            channels.length,
            scheme,
            null,
          ),

          ...sms.asMap().entries.map(
            (e) => _row(
              "SMS ${e.key + 1}",
              "${e.value['recipient']} (${e.value['status']})",
              scheme,
              null,
            ),
          ),

          ...emails.asMap().entries.map(
            (e) => _row(
              "Email ${e.key + 1}",
              "${e.value['recipient']} (${e.value['status']})",
              scheme,
              null,
            ),
          ),

          ...channels.asMap().entries.map(
            (e) => _row(
              "${local.translate("history_logs.events.details.channel")} ${e.key + 1}",
              "${e.value['platform']} (${e.value['status']})",
              scheme,
              null,
            ),
          ),
        ],
      ),
    );
  }
}
