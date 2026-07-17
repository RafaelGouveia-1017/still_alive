import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

import 'contact_detail.dart';
import 'emergency_contacts.dart';
import '../../../data/all.dart';
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
class _ContactsScreenState extends State<ContactsScreen> {
  late List<String> quickContacts = [];
  late List<String> emergencyContacts = [];
  late List<_ContactData> contacts = [];
  bool _isLoading = true;

  String searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();

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

          bool isFavourite = false;
          if (Platform.isAndroid) {
            isFavourite = (contact.android!.isFavorite != null)
                ? contact.android!.isFavorite!
                : false;
          }

          bool isQuick = (quickContacts.isEmpty)
              ? false
              : quickContacts.any((c) => c == contact.id);
          bool isEmergency = (emergencyContacts.isEmpty)
              ? false
              : emergencyContacts.any((c) => c == contact.id);

          String role = '???';
          if (contact.name?.nickname != null) {
            role = contact.name!.nickname!;
          } else if (contact.relations.isNotEmpty) {
            role = contact.relations[0].label.toString();
          }

          String phone = '???';
          if (contact.phones.isNotEmpty) {
            phone = contact.phones[0].number;
          }

          contacts.add(
            _ContactData(
              id: contact.id!,
              name: contact.displayName,
              image: contact.photo,
              role: role,
              phone: phone,
              favorite: isFavourite,
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
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    if (_isLoading) {
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
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: CircularProgressIndicator(color: scheme.tertiary),
          ),
        ),
      );
    }

    List<_ContactData> filteredContacts = [];
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

    final starred = filteredContacts.where((c) => c.favorite).toList();

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
      child: Column(
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
                          _ContactRow(data: starred[i], compact: false),
                          if (i < starred.length - 1)
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
                if (starred.isNotEmpty) const SizedBox(height: AppSpacing.xl),
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
                        for (int i = 0; i < filteredContacts.length; i++) ...[
                          _ContactRow(data: filteredContacts[i]),
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

/// Immutable display data used to render a contact row.
///
/// Contains the contact information required by the UI without depending
/// directly on the underlying device contact model.
class _ContactData {
  const _ContactData({
    required this.id,
    required this.name,
    required this.image,
    required this.role,
    required this.phone,
    required this.favorite,
    required this.emergency,
    required this.quick,
    required this.gradient,
    required this.textColor,
  });

  final String id;
  final String? name;
  final Photo? image;
  final String role;
  final String phone;
  final bool favorite;
  final bool emergency;
  final bool quick;
  final List<Color> gradient;
  final Color textColor;
}

/// A compact contact list item.
///
/// Displays:
/// * Contact avatar or generated initial.
/// * Contact name.
/// * Relationship and phone information.
/// * Favorite indicator.
///
/// Tapping the row navigates to the contact details screen.
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.data, this.compact = true});

  final _ContactData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    double size = compact ? 40.0 : 44.0;

    String letter = (data.name == null || data.name == '')
        ? '?'
        : data.name![0];

    bool hasImage = data.image?.thumbnail != null;

    return Row(
      children: [
        Expanded(
          child: Pressable(
            onTap: () => Navigator.of(context).push(
              AppRoute(
                page: ContactDetailScreen(contactID: data.id),
                transition: AppRouteTransitionType.slideLeft,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: size,
                  height: size,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: data.gradient,
                    ),
                    borderRadius: BorderRadius.circular(
                      data.favorite ? AppRadius.md : AppRadius.lg,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: (hasImage)
                      ? Image.memory(
                          data.image!.thumbnail!,
                          filterQuality: FilterQuality.high,
                        )
                      : Text(
                          letter,
                          style: AppText.bodySm(
                            scheme,
                          ).copyWith(color: data.textColor),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              data.name ?? '?',
                              style: AppText.bodySm(scheme),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${data.role} • ${data.phone}',
                        style: AppText.caption(scheme),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Pressable(
          onTap: () {
            //TODO open help dialog
          },
          child: Container(
            margin: const EdgeInsets.only(left: AppSpacing.ms),
            child: Row(
              children: [
                Column(
                  children: [
                    if (data.favorite) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxxs,
                        ),
                        child: Icon(
                          LucideIcons.star,
                          size: 12,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                    if (data.emergency) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxxs,
                        ),
                        child: Icon(
                          LucideIcons.shieldAlert,
                          size: 12,
                          color: scheme.error,
                        ),
                      ),
                    ],
                    if (data.quick) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxxs,
                        ),
                        child: Icon(
                          LucideIcons.zap,
                          size: 12,
                          color: scheme.tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  LucideIcons.ellipsisVertical,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Returns a collection of predefined gradient/text color combinations.
///
/// The returned list is typically used to assign visually distinct accent
/// colors to UI elements such as avatars, cards, or category chips.
///
/// Includes:
/// * Theme-derived primary, secondary, tertiary, and error gradients.
/// * Random hue-rotated variants of each gradient to increase visual variety.
///
/// The accompanying `text` color is chosen to provide appropriate contrast
/// against each gradient.
List<({List<Color> gradient, Color text})> colorOptions(BuildContext context) {
  ColorScheme scheme = Theme.of(context).colorScheme;
  return [
    (
      gradient: [scheme.primary, scheme.primaryContainer],
      text: scheme.onPrimary,
    ),
    (
      gradient: [scheme.secondary, scheme.secondaryContainer],
      text: scheme.onSecondary,
    ),
    (
      gradient: [scheme.tertiary, scheme.tertiaryContainer],
      text: scheme.onTertiary,
    ),
    (gradient: [scheme.error, scheme.errorContainer], text: scheme.onError),
    (
      gradient: rotateHue([scheme.primary, scheme.primaryContainer]),
      text: scheme.onPrimary,
    ),
    (
      gradient: rotateHue([scheme.secondary, scheme.secondaryContainer]),
      text: scheme.onSecondary,
    ),
    (
      gradient: rotateHue([scheme.tertiary, scheme.tertiaryContainer]),
      text: scheme.onTertiary,
    ),
    (
      gradient: rotateHue([scheme.error, scheme.errorContainer]),
      text: scheme.onError,
    ),
  ];
}

/// Returns a new gradient with its hue randomly rotated.
///
/// Both colors are shifted by the same random hue offset, preserving the
/// original relationship between the gradient colors while producing a
/// visually distinct variation.
///
/// Useful for generating themed color variants without manually defining
/// additional palettes.
List<Color> rotateHue(List<Color> gradient) {
  double rand = Random().nextDouble() * 360;
  HSVColor hsv0 = HSVColor.fromColor(gradient[0]);
  HSVColor hsv1 = HSVColor.fromColor(gradient[1]);
  return [
    hsv0.withHue((hsv0.hue + rand) % 360).toColor(),
    hsv1.withHue((hsv1.hue + rand) % 360).toColor(),
  ];
}
