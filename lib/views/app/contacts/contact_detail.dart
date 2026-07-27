import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/services/contact_service.dart';

import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// A screen that displays detailed information about a contact.
///
/// This screen shows the contact's profile information, contact methods,
/// preference settings, and quick-contact actions. It also manages updates
/// to contact preferences and synchronizes changes when the screen is closed.
///
/// The [contactID] identifies the contact to display. The [heroID],
/// [gradient], and [textColor] are used to configure the profile header
/// appearance and hero transition animation.
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({
    super.key,
    required this.contactID,
    required this.heroID,
    required this.gradient,
    required this.textColor,
  });

  final String contactID;
  final String heroID;
  final List<Color> gradient;
  final Color textColor;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailState();
}

/// State implementation for [ContactDetailScreen].
class _ContactDetailState extends State<ContactDetailScreen> {
  late bool _isQuick;
  late bool _isEmergency;
  late bool _isFavorite;
  late Contact _contact;
  late Map<String, dynamic> _preferences, _ori;
  bool _isLoading = true;
  bool _isQuickLoading = false;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    loadContact();

    _lifecycleListener = AppLifecycleListener(onResume: () => loadContact());
  }

  void loadContact() async {
    setState(() {
      _isLoading = true;
    });

    Contact? contact = await FlutterContacts.get(
      widget.contactID,
      properties: {
        ContactProperty.name,
        ContactProperty.photoFullRes,
        ContactProperty.relation,
        ContactProperty.organization,
        ContactProperty.phone,
        ContactProperty.email,
        ContactProperty.favorite,
      },
    );

    if (contact != null) {
      bool isFavorite = false;
      if (Platform.isAndroid) {
        isFavorite = (contact.android!.isFavorite != null)
            ? contact.android!.isFavorite!
            : false;
      }

      try {
        bool isQuick =
            (await selectOne(
              sql:
                  """
                  SELECT CASE
                      WHEN EXISTS (
                          SELECT 1
                          FROM contacts,
                              json_each(contacts.value, '\$.ids')
                          WHERE contacts.key = 'quick'
                            AND json_each.value = '${widget.contactID}'
                      )
                      THEN 'true'
                      ELSE 'false'
                  END AS is_quick;
                  """,
            ) ==
            "true");

        bool isEmergency =
            (await selectOne(
              sql:
                  """
                  SELECT CASE
                      WHEN EXISTS (
                          SELECT 1
                          FROM contacts,
                              json_each(contacts.value, '\$.ids')
                          WHERE contacts.key = 'emergency'
                            AND json_each.value = '${widget.contactID}'
                      )
                      THEN 'true'
                      ELSE 'false'
                  END AS is_emergency;
                  """,
            ) ==
            "true");

        String result = await selectOne(
          sql:
              """
              SELECT j.value
              FROM contacts c,
                  json_each(c.value, '\$.contacts') AS j
              WHERE c.key = 'preferences'
                AND json_extract(j.value, '\$.id') = '${widget.contactID}';
              """,
        );
        Map<String, dynamic> preferences = (result == "None")
            ? {
                "id": widget.contactID,
                "sms": true,
                "email": true,
                "location": true,
                "audio": true,
              }
            : jsonDecode(result);

        setState(() {
          _isQuick = isQuick;
          _isEmergency = isEmergency;
          _isFavorite = isFavorite;
          _contact = contact;
          _preferences = preferences;
          _ori = Map<String, dynamic>.from(preferences);
          _isLoading = false;
        });
      } catch (e, st) {
        AppLogger.log.severe('SQL failed', e, st);
        if (!mounted) return;
        showGenericErrorMessage(context, null);
      }
    }
  }

  void checkIfAllPrefsTrue() async {
    try {
      if (_preferences["sms"] == true &&
          _preferences["email"] == true &&
          _preferences["location"] == true &&
          _preferences["audio"] == true) {
        ContactService.deleteContactPrefs(widget.contactID);
      } else {
        ContactService.insertContactPrefs(_preferences);
      }
    } catch (e, st) {
      AppLogger.log.severe('SQL failed', e, st);
      if (!mounted) return;
      showGenericErrorMessage(context, null);
    }
  }

  @override
  void dispose() {
    bool isSame = const DeepCollectionEquality().equals(_preferences, _ori);
    if (!isSame) checkIfAllPrefsTrue();
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    bool hasImage = false;
    String letter = '', role = '';
    if (!_isLoading) {
      letter = (_contact.name == null || _contact.displayName == '')
          ? '?'
          : _contact.displayName![0];

      hasImage = _contact.photo?.fullSize != null;

      if (_contact.name?.nickname != null) {
        role = _contact.name!.nickname!;
      } else if (_contact.relations.isNotEmpty) {
        role = _contact.relations[0].name;
      }
    }

    return ScreenBase(
      header: AppHeader(
        title: local.translate("contact_detail.title"),
        left: CircleIconButton(
          icon: LucideIcons.chevronLeft,
          onTap: () => Navigator.pop(context),
        ),
        right: CircleIconButton(
          icon: LucideIcons.pencil,
          onTap: () async {
            await FlutterContacts.native.showEditor(widget.contactID);
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
                bottom: AppSpacing.xl,
              ),
              children: [
                Center(
                  child: Pressable(
                    onTap: () async {
                      await FlutterContacts.native.showViewer(widget.contactID);
                    },
                    child: Column(
                      children: [
                        Hero(
                          tag: widget.heroID,
                          flightShuttleBuilder:
                              (context, animation, direction, from, to) =>
                                  AppHeader.flight(
                                    context,
                                    animation,
                                    direction,
                                    from,
                                    to,
                                  ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: Container(
                              width: 96,
                              height: 96,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: widget.gradient,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xxl,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.gradient.last.withAlpha(153),
                                    blurRadius: 50,
                                    spreadRadius: -20,
                                    offset: Offset(0, AppSpacing.md),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: (hasImage)
                                  ? Image.memory(
                                      _contact.photo!.fullSize!,
                                      filterQuality: FilterQuality.high,
                                    )
                                  : Text(
                                      letter,
                                      style: AppText.h1(
                                        scheme,
                                      ).copyWith(color: widget.textColor),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_isLoading) ...[
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: scheme.tertiary,
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            _contact.displayName ?? '?',
                            style: AppText.h2(scheme),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xxxs),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (role.isNotEmpty)
                                Text(
                                  (_isQuick || _isEmergency || _isFavorite)
                                      ? '$role • '
                                      : role,
                                  style: AppText.caption(scheme),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),

                              if (_contact.organizations.isNotEmpty)
                                Text(
                                  (_isQuick || _isEmergency || _isFavorite)
                                      ? (role.isNotEmpty)
                                            ? ' • ${_contact.organizations[0].name!} • '
                                            : '${_contact.organizations[0].name!} • '
                                      : (role.isNotEmpty)
                                      ? ' • ${_contact.organizations[0].name!}'
                                      : _contact.organizations[0].name!,
                                  style: AppText.caption(scheme),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),

                              if (_isFavorite)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xxxs,
                                  ),
                                  child: Icon(
                                    LucideIcons.star,
                                    size: 12,
                                    color: scheme.primary,
                                  ),
                                ),
                              if (_isEmergency)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xxxs,
                                  ),
                                  child: Icon(
                                    LucideIcons.shieldAlert,
                                    size: 12,
                                    color: scheme.error,
                                  ),
                                ),
                              if (_isQuick)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xxxs,
                                  ),
                                  child: Icon(
                                    LucideIcons.zap,
                                    size: 12,
                                    color: scheme.tertiary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!_isLoading) ...[
                  if (_contact.phones.isNotEmpty ||
                      _contact.emails.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        if (_contact.phones.isNotEmpty) ...[
                          Expanded(
                            child: Pressable(
                              onTap: () {
                                Phone? primary =
                                    _contact.phones.firstWhereOrNull(
                                      (p) => p.isPrimary ?? false,
                                    ) ??
                                    _contact.phones.first;
                                String number =
                                    (Platform.isAndroid &&
                                        primary.normalizedNumber != null)
                                    ? primary.normalizedNumber!
                                    : primary.number;
                                launchUrl(Uri.parse('tel:$number'));
                              },
                              child: _QuickAction(
                                icon: LucideIcons.phone,
                                label: local.translate(
                                  "contact_detail.actions.0",
                                ),
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.xxs),
                        ],
                        if (_contact.phones.isNotEmpty) ...[
                          SizedBox(width: AppSpacing.xxs),
                          Expanded(
                            child: Pressable(
                              onTap: () {
                                Phone? primary =
                                    _contact.phones.firstWhereOrNull(
                                      (p) => p.isPrimary ?? false,
                                    ) ??
                                    _contact.phones.first;
                                String number =
                                    (Platform.isAndroid &&
                                        primary.normalizedNumber != null)
                                    ? primary.normalizedNumber!
                                    : primary.number;
                                launchUrl(Uri.parse('sms:$number'));
                              },
                              child: _QuickAction(
                                icon: LucideIcons.messageSquare,
                                label: local.translate(
                                  "contact_detail.actions.1",
                                ),
                                color: scheme.tertiary,
                              ),
                            ),
                          ),
                          if (_contact.emails.isNotEmpty)
                            SizedBox(width: AppSpacing.xxs),
                        ],
                        if (_contact.emails.isNotEmpty) ...[
                          if (_contact.phones.isNotEmpty)
                            SizedBox(width: AppSpacing.xxs),
                          Expanded(
                            child: Pressable(
                              onTap: () {
                                Email? primary =
                                    _contact.emails.firstWhereOrNull(
                                      (p) => p.isPrimary ?? false,
                                    ) ??
                                    _contact.emails.first;
                                launchUrl(
                                  Uri.parse('mailto:${primary.address}'),
                                );
                              },
                              child: _QuickAction(
                                icon: LucideIcons.mail,
                                label: local.translate(
                                  "contact_detail.actions.2",
                                ),
                                color: scheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  if (_contact.phones.isNotEmpty ||
                      _contact.emails.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    SectionTitle(local.translate("contact_detail.sections.0")),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < _contact.phones.length; i++) ...[
                            Pressable(
                              onTap: () {
                                String number;
                                if (Platform.isAndroid &&
                                    _contact.phones[i].normalizedNumber !=
                                        null) {
                                  number = _contact.phones[i].normalizedNumber!;
                                } else {
                                  number = _contact.phones[i].number;
                                }
                                launchUrl(Uri.parse('tel:$number'));
                              },
                              child: AppRow(
                                icon: LucideIcons.phone,
                                title: _contact.phones[i].number,
                                subtitle:
                                    _contact.phones[i].label.customLabel ??
                                    _contact.phones[i].label.label.name[0]
                                            .toUpperCase() +
                                        _contact.phones[i].label.label.name
                                            .substring(1),
                              ),
                            ),
                            if (i < _contact.phones.length - 1)
                              Divider(height: 1, color: scheme.outlineVariant),
                          ],
                          if (_contact.emails.isNotEmpty)
                            Divider(height: 1, color: scheme.outlineVariant),
                          for (int i = 0; i < _contact.emails.length; i++) ...[
                            Pressable(
                              onTap: () => launchUrl(
                                Uri.parse(
                                  'mailto:${_contact.emails[i].address}',
                                ),
                              ),
                              child: AppRow(
                                icon: LucideIcons.mail,
                                title: _contact.emails[i].address,
                                subtitle:
                                    _contact.emails[i].label.customLabel ??
                                    _contact.emails[i].label.label.name[0]
                                            .toUpperCase() +
                                        _contact.emails[i].label.label.name
                                            .substring(1),
                              ),
                            ),
                            if (i < _contact.emails.length - 1)
                              Divider(height: 1, color: scheme.outlineVariant),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                  SectionTitle(local.translate("contact_detail.sections.1")),
                  AppCard(
                    child: Column(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _preferences["sms"] = !_preferences["sms"];
                            });
                          },
                          child: AppRow(
                            title: local.translate(
                              "contact_detail.preferences.0",
                            ),
                            trailing: AppToggle(on: _preferences["sms"]),
                          ),
                        ),
                        Divider(height: 1, color: scheme.outlineVariant),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _preferences["email"] = !_preferences["email"];
                            });
                          },
                          child: AppRow(
                            title: local.translate(
                              "contact_detail.preferences.1",
                            ),
                            trailing: AppToggle(on: _preferences["email"]),
                          ),
                        ),
                        Divider(height: 1, color: scheme.outlineVariant),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _preferences["location"] =
                                  !_preferences["location"];
                            });
                          },
                          child: AppRow(
                            title: local.translate(
                              "contact_detail.preferences.2",
                            ),
                            trailing: AppToggle(on: _preferences["location"]),
                          ),
                        ),
                        Divider(height: 1, color: scheme.outlineVariant),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _preferences["audio"] = !_preferences["audio"];
                            });
                          },
                          child: AppRow(
                            title: local.translate(
                              "contact_detail.preferences.3",
                            ),
                            trailing: AppToggle(on: _preferences["audio"]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Pressable(
                    onTap: () async {
                      setState(() {
                        _isQuickLoading = true;
                      });

                      try {
                        if (_isQuick) {
                          ContactService.deleteQuickContact(widget.contactID);
                        } else {
                          ContactService.insertQuickContact(widget.contactID);
                        }

                        setState(() {
                          _isQuick = !_isQuick;
                        });
                      } catch (e, st) {
                        AppLogger.log.severe('SQL failed', e, st);
                        if (context.mounted) {
                          showGenericErrorMessage(context, null);
                        }
                      } finally {
                        setState(() {
                          _isQuickLoading = false;
                        });
                      }
                    },
                    child: (_isQuickLoading)
                        ? SizedBox(
                            width: 56,
                            height: 56,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: scheme.tertiary,
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 56,
                            child: PrimaryButton(
                              icon: _isQuick
                                  ? LucideIcons.trash2
                                  : LucideIcons.plus,
                              label: _isQuick
                                  ? local.translate(
                                      "contacts_list.is_quick.true",
                                    )
                                  : local.translate(
                                      "contacts_list.is_quick.false",
                                    ),
                              color: _isQuick
                                  ? ButtonColor.warning
                                  : ButtonColor.primary,
                            ),
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

/// A compact action button used for contact interactions.
///
/// Displays an icon and label inside a styled container. Typically used for
/// actions such as calling, messaging, or emailing a contact.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.card,
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(label, style: AppText.micro(scheme)),
        ],
      ),
    );
  }
}
