import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/services/contact_service.dart';
import 'package:still_alive/src/rust/api/timer/config.dart' as config;

import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// A screen for viewing and managing detailed information about a contact.
///
/// The screen loads the contact directly from the device and presents its
/// profile, avatar, phone numbers, email addresses, organization or
/// relationship information, and application-specific contact settings.
///
/// In normal mode, the screen provides actions for calling, messaging, and
/// emailing the contact, as well as access to the native contact editor and
/// viewer. It also allows the contact's quick-contact status and notification
/// preferences to be managed.
///
/// When [onChanged] is provided, the screen operates in timer-selection mode.
/// In this mode, individual phone numbers and email addresses can be selected
/// or deselected for the timer, and the resulting [config.Contact] is returned
/// through the callback. The screen also provides an action for selecting or
/// clearing all available contact methods.
///
/// The [heroID], [gradient], and [textColor] parameters control the contact
/// header's appearance and allow the avatar to participate in the Hero
/// transition from [ContactRow].
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({
    super.key,
    required this.contactID,
    required this.heroID,
    required this.gradient,
    required this.textColor,
    this.timerContact,
    this.onChanged,
  });

  final String contactID;
  final String heroID;
  final List<Color> gradient;
  final Color textColor;

  final config.Contact? timerContact;
  final ValueChanged<config.Contact?>? onChanged;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailState();
}

/// Manages the contact data, preferences, selection state, and lifecycle of
/// [ContactDetailScreen].
///
/// The state loads the device contact together with application-specific
/// information such as quick-contact status, emergency status, favorite
/// status, and saved contact preferences. It keeps the original preferences
/// so that changes can be persisted when the screen is closed.
///
/// When the screen is used for timer selection, the state also maintains the
/// selected phone numbers and email addresses and reports changes through the
/// widget's callback.
///
/// Contact information is refreshed when the application resumes so that
/// edits made through the native contact application are reflected in the
/// screen. Loading and database operations are tracked separately to provide
/// appropriate feedback during asynchronous actions.
class _ContactDetailState extends State<ContactDetailScreen> {
  late bool _isQuick;
  late bool _isEmergency;
  late bool _isFavorite;
  late Contact _contact;
  late Map<String, dynamic> _preferences, _ori;
  bool _isLoading = true;
  bool _isQuickLoading = false;

  late config.Contact? _timerContact;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();

    if (widget.onChanged != null) {
      _timerContact =
          widget.timerContact ??
          config.Contact(id: widget.contactID, sms: [], email: []);
    } else {
      _timerContact = null;
    }

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

        bool isEmergency = (widget.onChanged != null)
            ? true
            : (await selectOne(
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
            ? {"id": widget.contactID, "location": true, "audio": true}
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
      if (_preferences["location"] == true && _preferences["audio"] == true) {
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

  String getPhoneNumber(Phone phone) {
    return (Platform.isAndroid && phone.normalizedNumber != null)
        ? phone.normalizedNumber!
        : phone.number;
  }

  bool isNumberInTimer(String number) {
    return _timerContact!.sms.contains(number);
  }

  bool isEmailInTimer(String address) {
    return _timerContact!.email.contains(address);
  }

  void selectSms(String number) {
    if (_timerContact!.sms.contains(number)) return;
    _timerContact!.sms.add(number);

    updateTimerContact();
  }

  void deselectSms(String number) {
    if (!_timerContact!.sms.contains(number)) return;
    _timerContact!.sms.remove(number);

    updateTimerContact();
  }

  void selectEmail(String address) {
    if (_timerContact!.email.contains(address)) return;
    _timerContact!.email.add(address);

    updateTimerContact();
  }

  void deselectEmail(String address) {
    if (!_timerContact!.email.contains(address)) return;
    _timerContact!.email.remove(address);

    updateTimerContact();
  }

  void updateTimerContact() {
    if (_timerContact!.sms.isEmpty && _timerContact!.email.isEmpty) {
      widget.onChanged!(null);
    } else {
      widget.onChanged!(_timerContact);
    }

    setState(() {});
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
        right: (widget.onChanged != null)
            ? (!_isLoading)
                  ? (_contact
                            .phones
                            .isEmpty) //add _contact.emails.isEmpty check for email support
                        ? null
                        : CircleIconButton(
                            icon:
                                (_contact.phones.length ==
                                    _timerContact!
                                        .sms
                                        .length) //add _contact.emails.length check for email support
                                ? LucideIcons.squareCheckBig
                                : LucideIcons.square,
                            onTap: () {
                              if (_contact.phones.length ==
                                  _timerContact!
                                      .sms
                                      .length) //add _contact.emails.length check for email support
                              {
                                _timerContact!.sms.clear();
                                _timerContact!.email.clear();
                              } else {
                                _timerContact!.sms.clear();
                                _timerContact!.email.clear();

                                for (var phone in _contact.phones) {
                                  String number = getPhoneNumber(phone);
                                  _timerContact!.sms.add(number);
                                }
                                /*
                                for (var email in _contact.emails) {
                                  _timerContact!.email.add(email.address);
                                }
                                */
                              }

                              updateTimerContact();
                            },
                          )
                  : SizedBox(
                      width: 30,
                      height: 30,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: scheme.tertiary,
                        ),
                      ),
                    )
            : CircleIconButton(
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
                                      ? '${_contact.organizations[0].name!} • '
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
                  if (widget.onChanged == null &&
                      (_contact.phones.isNotEmpty ||
                          _contact.emails.isNotEmpty)) ...[
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

                                String number = getPhoneNumber(primary);
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
                                String number = getPhoneNumber(primary);
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
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.xxs,
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < _contact.phones.length; i++) ...[
                            Pressable(
                              onTap: () {
                                String number = getPhoneNumber(
                                  _contact.phones[i],
                                );
                                if (widget.onChanged != null) {
                                  if (isNumberInTimer(number)) {
                                    deselectSms(number);
                                  } else {
                                    selectSms(number);
                                  }
                                } else {
                                  launchUrl(Uri.parse('tel:$number'));
                                }
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
                                trailing: (widget.onChanged != null)
                                    ? Icon(
                                        (isNumberInTimer(
                                              getPhoneNumber(
                                                _contact.phones[i],
                                              ),
                                            ))
                                            ? LucideIcons.squareCheck
                                            : LucideIcons.square,
                                        size: 20,
                                        color: scheme.onSurface,
                                      )
                                    : null,
                              ),
                            ),
                            if (i < _contact.phones.length - 1)
                              Divider(height: 1, color: scheme.outlineVariant),
                          ],
                          if (_contact.emails.isNotEmpty &&
                              widget.onChanged ==
                                  null) //delete widget.onChanged check for email support
                            Divider(height: 1, color: scheme.outlineVariant),
                          for (int i = 0; i < _contact.emails.length; i++) ...[
                            if (widget.onChanged ==
                                null) //delete widget.onChanged check for email support
                            ...[
                              Pressable(
                                onTap: (widget.onChanged != null)
                                    ? () {
                                        if (isEmailInTimer(
                                          _contact.emails[i].address,
                                        )) {
                                          deselectEmail(
                                            _contact.emails[i].address,
                                          );
                                        } else {
                                          selectEmail(
                                            _contact.emails[i].address,
                                          );
                                        }
                                      }
                                    : () => launchUrl(
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
                                  trailing: (widget.onChanged != null)
                                      ? Icon(
                                          (isEmailInTimer(
                                                _contact.emails[i].address,
                                              ))
                                              ? LucideIcons.squareCheck
                                              : LucideIcons.square,
                                          size: 20,
                                          color: scheme.onSurface,
                                        )
                                      : null,
                                ),
                              ),
                              if (i < _contact.emails.length - 1)
                                Divider(
                                  height: 1,
                                  color: scheme.outlineVariant,
                                ),
                            ],
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

/// A compact action control for common contact interactions.
///
/// The control presents an icon above a short localized label inside a styled
/// container. It is used by [ContactDetailScreen] for actions such as calling,
/// sending an SMS message, or sending an email.
///
/// The supplied [color] is applied to the icon so that each action can use
/// the appropriate semantic or theme color while sharing the same layout and
/// visual treatment.
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
