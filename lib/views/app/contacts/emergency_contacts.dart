import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/services/contact_service.dart';
import 'package:still_alive/services/timer_service.dart';

import 'contact_detail.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// A screen that displays the contacts configured as emergency contacts.
///
/// The screen loads emergency contacts and the timers associated with each
/// contact from the local database. Contacts that have been deleted from the
/// device are automatically removed from the emergency-contact configuration
/// and from any timers that reference them.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsState();
}

/// State implementation for [EmergencyContactsScreen].
///
/// Manages loading and displaying emergency contacts and refreshes the
/// contact list whenever the application resumes.
class _EmergencyContactsState extends State<EmergencyContactsScreen> {
  late List<_EmergencyContactData> emergencyContacts = [];
  bool _isLoading = true;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    loadContacts();

    _lifecycleListener = AppLifecycleListener(onResume: () => loadContacts());
  }

  void loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    List<_EmergencyContactData> contactList = [];

    try {
      String emergencyContactsJsonString = await selectOne(
        sql: "SELECT value FROM contacts WHERE key = 'emergency'",
      );
      Map<String, dynamic> emergencyContactsJson = jsonDecode(
        emergencyContactsJsonString,
      );
      if (emergencyContactsJson['count'] != 0) {
        for (String id in emergencyContactsJson['ids']) {
          try {
            await FlutterContacts.get(id);
          } catch (e) {
            AppLogger.log.info('Contact not found.', e);
            ContactService.deleteEmergencyContact(id);
            TimerService.instance.removeDeletedContactFromActiveTimer(id);
            continue;
          }
        }
      }

      String contactsInTimersJsonString = await select(
        sql: """
          SELECT
              json_extract(contact.value, '\$.id') AS contact_id,
              json_group_array(
                  json_object(
                      'timer_name', json_extract(timers.value, '\$.name'),
                      'sms', json_extract(contact.value, '\$.sms'),
                      'email', json_extract(contact.value, '\$.email')
                  )
              ) AS timers
          FROM timers
          JOIN json_each(timers.value, '\$.contacts') AS contact
          GROUP BY json_extract(contact.value, '\$.id');
          """,
      );
      List<dynamic> listData = jsonDecode(contactsInTimersJsonString);

      for (var row in listData) {
        Contact? contact = await FlutterContacts.get(
          row["contact_id"],
          properties: {ContactProperty.name, ContactProperty.photoThumbnail},
        );

        List<(String timerName, List<String> smsNumbers, List<String> emails)>
        timers = [];

        for (Map<String, dynamic> timer in jsonDecode(row["timers"])) {
          timers.add((
            timer["timer_name"],
            List<String>.from(timer["sms"]),
            List<String>.from(timer["email"]),
          ));
        }

        contactList.add(_EmergencyContactData(contact!, timers));
      }
    } finally {
      setState(() {
        emergencyContacts = contactList;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return ScreenBase(
      header: AppHeader(
        title: local.translate("contacts_emergency.title"),
        left: CircleIconButton(
          icon: LucideIcons.chevronLeft,
          onTap: () => Navigator.pop(context),
        ),
      ),
      child: (_isLoading)
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: CircularProgressIndicator(color: scheme.tertiary),
              ),
            )
          : (emergencyContacts.isEmpty)
          ? Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxxxl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(AppRadius.xxl),
                            border: Border.all(color: const Color(0x0DFFFFFF)),
                          ),
                          child: Icon(
                            LucideIcons.shieldAlert,
                            size: 36,
                            color: scheme.error,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          local.translate("contacts_emergency.message"),
                          style: AppText.h2(scheme),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            local.translate("contacts_emergency.description"),
                            textAlign: TextAlign.center,
                            style: AppText.caption(scheme),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: AppExpandableGroup(
                children: [
                  for (int i = 0; i < emergencyContacts.length; i++)
                    emergencyContacts[i].buildExpandableCardRow(context),
                ],
              ),
            ),
    );
  }
}

/// Holds the contact and timer information displayed for an emergency contact.
///
/// Associates a device [Contact] with the timers that use the contact and
/// the communication details configured for each timer.
class _EmergencyContactData {
  /// Creates emergency-contact display data.
  ///
  /// [contact] is the device contact associated with the emergency contact.
  /// [timers] contains the timers that reference the contact, along with their
  /// configured SMS numbers and email addresses.
  const _EmergencyContactData(this.contact, this.timers);

  /// The device contact represented by this data object.
  final Contact contact;

  /// The timers associated with the contact.
  ///
  /// Each tuple contains the timer name, SMS numbers, and email addresses
  /// configured for that timer.
  final List<(String timerName, List<String> smsNumbers, List<String> emails)>
  timers;

  /// Builds the expandable card used to display this emergency contact.
  ///
  /// The card displays the contact's name, photo or initials, and the timers
  /// associated with the contact. Tapping the card opens the contact detail
  /// screen.
  AppExpandableCard buildExpandableCardRow(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    final colorOpts = ContactService.colorOptions(context);
    final colors = colorOpts[Random().nextInt(colorOpts.length)];

    String letter = (contact.name == null || contact.displayName == '')
        ? '?'
        : contact.displayName![0];
    bool hasImage = contact.photo?.thumbnail != null;

    String timerPlural = (timers.length == 1)
        ? local.translate("contacts_emergency.timers.0")
        : local.translate("contacts_emergency.timers.1");

    return AppExpandableCard(
      title: contact.displayName ?? '?',
      subtitle:
          '${local.translate("contacts_emergency.in")} ${timers.length} $timerPlural',
      iconHeroID: 'contact-pic-${contact.id}',
      iconWidget: (hasImage)
          ? Image.memory(
              contact.photo!.thumbnail!,
              filterQuality: FilterQuality.high,
            )
          : Text(
              letter,
              style: AppText.bodySm(scheme).copyWith(color: colors.text),
            ),
      iconSize: 26,
      iconColor: colors.text,
      iconGradient: colors.gradient,
      child: Pressable(
        onTap: () => Navigator.of(context).push(
          AppRoute(
            page: ContactDetailScreen(
              contactID: contact.id!,
              heroID: 'contact-pic-${contact.id}',
              gradient: colors.gradient,
              textColor: colors.text,
            ),
            transition: AppRouteTransitionType.slideLeft,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.xxs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int x = 0; x < timers.length; x++) ...[
                Text(timers[x].$1, style: AppText.body(scheme)),
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var sms in timers[x].$2) ...[
                      Text(
                        sms,
                        textAlign: TextAlign.right,
                        style: AppText.bodySm(
                          scheme,
                        ).copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                    for (var email in timers[x].$3) ...[
                      Text(
                        email,
                        textAlign: TextAlign.right,
                        style: AppText.bodySm(
                          scheme,
                        ).copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
                if (x != timers.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.ms,
                    ),
                    child: Divider(height: 1, color: scheme.outlineVariant),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
