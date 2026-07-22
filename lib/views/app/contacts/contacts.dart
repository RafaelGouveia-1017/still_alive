import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

import 'contact_helpers.dart';
import 'contact_row.dart';
import 'emergency_contacts.dart';
import '../../../data/all.dart';
import '../../../main.dart';
import '../../widgets/primitives.dart';

/// A screen displaying the user's contacts.
///
/// Loads contacts from the device and presents them in a searchable list.
/// Contacts are grouped into:
/// * Favorite contacts
/// * All available contacts
///
/// Features:
/// * Contact search by name, role, or phone number.
/// * Displays contact avatars or generated gradient initials.
/// * Highlights favorite contacts.
/// * Provides navigation to detailed contact information.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

/// State implementation for [ContactsScreen].
class _ContactsScreenState extends State<ContactsScreen> with RouteAware {
  late List<String> quickContacts = [];
  late List<String> emergencyContacts = [];
  late List<ContactData> contacts = [];
  bool _isLoading = true;

  String searchQuery = '';

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    loadContacts();

    _lifecycleListener = AppLifecycleListener(onResume: () => didPopNext());
  }

  void loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    String jsonString = await selectOne(
      sql: "SELECT value FROM contacts WHERE key = 'quick'",
    );
    Map<String, dynamic> json = jsonDecode(jsonString);
    if (json['count'] != 0) {
      for (String id in json['ids']) {
        quickContacts.add(id);
      }
    }

    jsonString = await selectOne(
      sql: "SELECT value FROM contacts WHERE key = 'emergency'",
    );
    json = jsonDecode(jsonString);
    if (json['count'] != 0) {
      for (String id in json['ids']) {
        emergencyContacts.add(id);
      }
    }

    jsonString = await selectOne(
      sql: "SELECT value FROM contacts WHERE key = 'preferences'",
    );
    json = jsonDecode(jsonString);
    List<Map<String, dynamic>> prefsContacts = [];
    if (json['count'] != 0) {
      for (Map<String, dynamic> c in json['contacts']) {
        prefsContacts.add(c);
      }
    }

    List<Contact> allContacts = await FlutterContacts.getAll(
      properties: {
        ContactProperty.name,
        ContactProperty.photoThumbnail,
        ContactProperty.relation,
        ContactProperty.phone,
        ContactProperty.favorite,
      },
    );

    if (allContacts.isNotEmpty) {
      if (!mounted) return;
      List<({List<Color> gradient, Color text})> colorOpts = colorOptions(
        context,
      );

      for (Contact? contact in allContacts) {
        if (contact != null) {
          final colors = colorOpts[Random().nextInt(colorOpts.length)];

          bool isFavorite = false;
          if (Platform.isAndroid) {
            isFavorite = (contact.android!.isFavorite != null)
                ? contact.android!.isFavorite!
                : false;
          }

          bool isQuick = (quickContacts.isEmpty)
              ? false
              : quickContacts.any((c) => c == contact.id);
          bool isEmergency = (emergencyContacts.isEmpty)
              ? false
              : emergencyContacts.any((c) => c == contact.id);

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

      executeSql(
        sql:
            "UPDATE contacts SET value = '${jsonEncode(json).replaceAll("'", "''")}' WHERE key = 'preferences'",
      );
    }

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

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    List<ContactData> filteredContacts = [];
    List<ContactData> starred = [];

    if (!_isLoading) {
      if (searchQuery.isNotEmpty) {
        filteredContacts = contacts
            .where(
              (c) =>
                  (c.name != null &&
                      c.name!.toLowerCase().contains(searchQuery)) ||
                  c.role.toLowerCase().contains(searchQuery) ||
                  c.phone.toLowerCase().contains(searchQuery),
            )
            .toList();
      } else {
        filteredContacts = contacts;
      }

      starred = filteredContacts.where((c) => c.favorite).toList();
    }

    return ScreenBase(
      bottomNavDestination: 'contacts',
      header: AppHeader(
        title: local.translate("contacts_list.title"),
        right: CircleIconButton(
          icon: LucideIcons.shieldAlert,
          foreground: scheme.error,
          onTap: () => Navigator.of(context).push(
            AppRoute(
              page: EmergencyContactsScreen(),
              transition: AppRouteTransitionType.slideLeft,
            ),
          ),
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
              child: Center(
                child: CircularProgressIndicator(color: scheme.tertiary),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xl,
                      bottom: AppSpacing.lg,
                    ),
                    children: [
                      if (starred.isNotEmpty) ...[
                        SectionTitle(
                          local.translate("contacts_list.sections.0"),
                          action: Text(
                            '${starred.length}',
                            style: AppText.micro(scheme),
                          ),
                        ),
                        AppCard(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            children: [
                              for (int i = 0; i < starred.length; i++) ...[
                                ContactRow(data: starred[i], compact: false),
                                if (i < starred.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.ms,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (starred.isNotEmpty)
                        const SizedBox(height: AppSpacing.xl),
                      if (filteredContacts.isEmpty) ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xxl,
                                ),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              child: Icon(
                                LucideIcons.userX,
                                size: 36,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              local.translate("contacts_list.not_found"),
                              style: AppText.bodySm(
                                scheme,
                              ).copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ] else ...[
                        SectionTitle(
                          local.translate("contacts_list.sections.1"),
                          action: Text(
                            '${filteredContacts.length}',
                            style: AppText.micro(scheme),
                          ),
                        ),
                        AppCard(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            children: [
                              for (
                                int i = 0;
                                i < filteredContacts.length;
                                i++
                              ) ...[
                                ContactRow(data: filteredContacts[i]),
                                if (i < filteredContacts.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.md,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      color: scheme.outlineVariant,
                                    ),
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
