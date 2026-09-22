import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/services/contact_service.dart';
import 'package:still_alive/src/rust/api/timer/config.dart' as config;

import 'contact_row.dart';
import 'emergency_contacts.dart';
import '../../../data/all.dart';
import '../../../main.dart';
import '../../widgets/primitives.dart';

/// A screen for browsing, searching, and selecting device contacts.
///
/// The screen loads contacts from the device and combines them with
/// application-specific contact information, including quick-contact and
/// emergency-contact status. Contacts can be searched by name, relationship,
/// or phone number and are presented in sections based on their current
/// status.
///
/// In its normal mode, the screen provides access to the full contact list and
/// emergency contacts. When created with
/// [ContactsScreen.selectContactsForTimer], it enters timer-selection mode,
/// allowing the user to select contacts and the phone or email methods that
/// should be associated with a timer.
///
/// Contact data is refreshed when the screen becomes active again so that
/// changes made outside the screen, such as edits to device contacts, are
/// reflected in the displayed list.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen.showAllContacts({super.key}) : selectMode = false, timerContacts = null, onChanged = null;

  const ContactsScreen.selectContactsForTimer({super.key, required this.timerContacts, required this.onChanged}) : selectMode = true;

  final bool selectMode;
  final List<config.Contact>? timerContacts;
  final ValueChanged<List<config.Contact>?>? onChanged;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

/// Manages the state, contact data, and lifecycle of [ContactsScreen].
///
/// The state maintains the device contacts currently displayed by the screen,
/// application-specific contact classifications, the active search query, and
/// the contacts selected for a timer when the screen is in selection mode.
///
/// Contact information is loaded asynchronously from both the device contact
/// provider and the application's local database. The state also subscribes
/// to route and application lifecycle changes so that contact information can
/// be refreshed when the user returns to the screen or the application
/// resumes.
///
/// When timer-selection mode is active, changes to the selected contacts are
/// forwarded through the callback supplied to [ContactsScreen].
class _ContactsScreenState extends State<ContactsScreen> with RouteAware {
  late List<String> quickContacts = [];
  late List<String> emergencyContacts = [];
  late List<ContactData> contacts = [];

  late List<config.Contact> timerContacts = [];

  bool _isLoading = true;
  String searchQuery = '';

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();

    timerContacts = widget.timerContacts ?? [];
    loadContacts();

    _lifecycleListener = AppLifecycleListener(onResume: () => didPopNext());
  }

  void loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    String jsonString = await selectOne(sql: "SELECT value FROM contacts WHERE key = 'quick'");
    Map<String, dynamic> json = jsonDecode(jsonString);
    if (json['count'] != 0) {
      for (String id in json['ids']) {
        quickContacts.add(id);
      }
    }

    jsonString = await selectOne(sql: "SELECT value FROM contacts WHERE key = 'emergency'");
    json = jsonDecode(jsonString);
    if (json['count'] != 0) {
      for (String id in json['ids']) {
        emergencyContacts.add(id);
      }
    }

    if (widget.selectMode && timerContacts.isNotEmpty) {
      for (var contact in timerContacts) {
        if (!emergencyContacts.contains(contact.id)) {
          emergencyContacts.add(contact.id);
        }
      }
    }

    jsonString = await selectOne(sql: "SELECT value FROM contacts WHERE key = 'preferences'");
    json = jsonDecode(jsonString);
    List<Map<String, dynamic>> prefsContacts = [];
    if (json['count'] != 0) {
      for (Map<String, dynamic> c in json['contacts']) {
        prefsContacts.add(c);
      }
    }

    List<Contact> allContacts = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.photoThumbnail, ContactProperty.relation, ContactProperty.phone, ContactProperty.favorite},
    );

    if (allContacts.isNotEmpty) {
      if (!mounted) return;
      List<({List<Color> gradient, Color text})> colorOpts = ContactService.colorOptions(context);

      for (Contact? contact in allContacts) {
        if (contact != null) {
          if (contact.name == null || contact.displayName == null) continue;

          final colors = colorOpts[Random().nextInt(colorOpts.length)];

          bool isFavorite = false;
          if (Platform.isAndroid) {
            isFavorite = (contact.android!.isFavorite != null) ? contact.android!.isFavorite! : false;
          }

          bool isQuick = (quickContacts.isEmpty) ? false : quickContacts.any((c) => c == contact.id);
          bool isEmergency = (emergencyContacts.isEmpty) ? false : emergencyContacts.any((c) => c == contact.id);

          String role = '';
          if (contact.name?.nickname != null) {
            role = contact.name!.nickname!;
          } else if (contact.relations.isNotEmpty) {
            role = contact.relations[0].name;
          }

          String phone = '';
          if (contact.phones.isNotEmpty) {
            phone = contact.phones[0].number;
          }

          contacts.add(
            ContactData(
              id: contact.id!,
              name: contact.displayName,
              image: contact.photo,
              role: role,
              phone: phone,
              favorite: isFavorite,
              emergency: isEmergency,
              quick: isQuick,
              gradient: colors.gradient,
              textColor: colors.text,
            ),
          );
        }
      }
      contacts.sort((a, b) {
        if (a.name == null) return -1;
        if (b.name == null) return 1;
        return a.name!.toLowerCase().compareTo(b.name!.toLowerCase());
      });

      final currentIds = allContacts.map((c) => c.id).toSet();
      prefsContacts.removeWhere((pref) => !currentIds.contains(pref['id']));

      json['contacts'] = prefsContacts;
      json['count'] = prefsContacts.length;

      executeSql(sql: "UPDATE contacts SET value = '${jsonEncode(json).replaceAll("'", "''")}' WHERE key = 'preferences'");
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    setState(() {
      quickContacts = [];
      emergencyContacts = [];
      contacts = [];
      _isLoading = true;
      searchQuery = searchQuery;
    });
    loadContacts();

    super.didPopNext();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  String _getSubtitle() {
    AppLocalizations local = AppLocalizations.of(context)!;

    String subtitle = '';
    if (timerContacts.isEmpty) {
      subtitle =
          '0 '
          '${local.translate("timer_configuration.contacts.contact.1")} '
          '${local.translate("timer_configuration.contacts.selected.1")}';
    } else {
      String part1, part2, part3;
      int contactsLength = timerContacts.length;
      int contactsSms = 0;
      int contactsEmail = 0;

      for (var contact in timerContacts) {
        contactsSms += contact.sms.length;
        contactsEmail += contact.email.length;
      }

      part1 = (contactsLength == 1)
          ? '1 ${local.translate("timer_configuration.contacts.contact.0")}'
          : '$contactsLength '
                '${local.translate("timer_configuration.contacts.contact.1")}';

      switch (contactsSms) {
        case 0:
          part2 = '';
          break;
        case 1:
          part2 =
              ' • $contactsSms '
              '${local.translate("timer_configuration.contacts.sms.0")}';
          break;
        default:
          part2 =
              ' • $contactsSms '
              '${local.translate("timer_configuration.contacts.sms.1")}';
          break;
      }

      switch (contactsEmail) {
        case 0:
          part3 = '';
          break;
        case 1:
          part3 =
              ' • $contactsEmail '
              '${local.translate("timer_configuration.contacts.email.0")}';
          break;
        default:
          part3 =
              ' • $contactsEmail '
              '${local.translate("timer_configuration.contacts.email.1")}';
          break;
      }

      subtitle = part1 + part2 + part3;
    }

    return subtitle;
  }

  Widget _getContactRow(String heroID, ContactData data, {bool compact = true}) {
    if (widget.selectMode) {
      return ContactRow(
        heroID: heroID,
        data: data,
        compact: compact,
        timerContact: timerContacts.firstWhereOrNull((c) => c.id == data.id),
        onChanged: (contact) {
          if (contact == null) {
            timerContacts.removeWhere((c) => c.id == data.id);
          } else {
            int index = timerContacts.indexWhere((c) => c.id == contact.id);
            if (index != -1) {
              timerContacts.removeAt(index);
            }
            timerContacts.add(contact);
          }
          widget.onChanged!(timerContacts);
        },
      );
    } else {
      return ContactRow(heroID: heroID, data: data, compact: compact);
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    List<ContactData> filteredContacts = [];
    List<ContactData> starred = [];
    List<ContactData> timerFilteredContacts = [];

    if (!_isLoading) {
      if (searchQuery.isNotEmpty) {
        filteredContacts = contacts
            .where(
              (c) =>
                  (c.name != null && c.name!.toLowerCase().contains(searchQuery)) ||
                  c.role.toLowerCase().contains(searchQuery) ||
                  c.phone.toLowerCase().contains(searchQuery),
            )
            .toList();
      } else {
        filteredContacts = contacts;
      }

      starred = filteredContacts.where((c) => c.favorite).toList();

      if (widget.selectMode) {
        List<String> ids = timerContacts.map((c) => c.id).toList();
        timerFilteredContacts = filteredContacts.where((c) => ids.contains(c.id)).toList();
      }
    }

    return ScreenBase(
      bottomNavDestination: (widget.selectMode) ? '' : 'contacts',
      header: AppHeader(
        title: local.translate("contacts_list.title"),
        subtitle: (widget.selectMode) ? _getSubtitle() : null,
        left: (widget.selectMode) ? CircleIconButton(icon: LucideIcons.chevronLeft, onTap: () => Navigator.pop(context)) : null,
        right: (widget.selectMode)
            ? null
            : CircleIconButton(
                icon: LucideIcons.shieldAlert,
                foreground: scheme.error,
                onTap: () => Navigator.of(context).push(AppRoute(page: EmergencyContactsScreen(), transition: AppRouteTransitionType.slideLeft)),
              ),
        searchBar: AppSearchBar(
          hint: local.translate("contacts_list.search"),
          onChanged: (value) {
            setState(() {
              searchQuery = value.toLowerCase();
            });
          },
        ),
      ),
      child: (_isLoading)
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.lg),
                    children: [
                      if (widget.selectMode && timerFilteredContacts.isNotEmpty) ...[
                        SectionTitle(
                          local.translate("contacts_list.sections.2"),
                          action: Text('${timerFilteredContacts.length}', style: AppText.micro(scheme)),
                        ),
                        AppCard(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            children: [
                              for (int i = 0; i < timerFilteredContacts.length; i++) ...[
                                _getContactRow('contact-pic-${timerFilteredContacts[i].id}-timer', timerFilteredContacts[i], compact: false),

                                if (i < timerFilteredContacts.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                    child: Divider(height: 1, color: scheme.outlineVariant),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],

                      if (starred.isNotEmpty) ...[
                        SectionTitle(local.translate("contacts_list.sections.0"), action: Text('${starred.length}', style: AppText.micro(scheme))),
                        AppCard(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            children: [
                              for (int i = 0; i < starred.length; i++) ...[
                                _getContactRow('contact-pic-${starred[i].id}-starred', starred[i], compact: false),

                                if (i < starred.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.ms),
                                    child: Divider(height: 1, color: scheme.outlineVariant),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],

                      if (filteredContacts.isEmpty) ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(AppRadius.xxl),
                                border: Border.all(color: scheme.outlineVariant),
                              ),
                              child: Icon((widget.selectMode) ? LucideIcons.bookX : LucideIcons.userX, size: 36, color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              local.translate("contacts_list.not_found"),
                              style: AppText.bodySm(scheme).copyWith(color: scheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ] else ...[
                        SectionTitle(
                          local.translate("contacts_list.sections.1"),
                          action: Text('${filteredContacts.length}', style: AppText.micro(scheme)),
                        ),
                        AppCard(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            children: [
                              for (int i = 0; i < filteredContacts.length; i++) ...[
                                _getContactRow('contact-pic-${filteredContacts[i].id}', filteredContacts[i]),

                                if (i < filteredContacts.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                    child: Divider(height: 1, color: scheme.outlineVariant),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
