import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';

/// A widget that displays and manages custom SMS and email destinations.
///
/// Tapping the widget opens [CustomDestinationInputScreen], where users can
/// add or remove custom destinations.
///
/// The current SMS and email destinations are provided through [customSms] and
/// [customEmail]. Changes made on the destination screen are propagated back
/// through [onSmsChanged] and [onEmailChanged].
class CustomDestinationInput extends StatefulWidget {
  /// Creates a custom destination input widget.
  ///
  /// [customSms] contains the currently configured SMS destinations.
  /// [customEmail] contains the currently configured email destinations.
  /// [onSmsChanged] is called whenever the SMS destination list changes.
  /// [onEmailChanged] is called whenever the email destination list changes.
  const CustomDestinationInput({
    super.key,
    required this.customSms,
    required this.customEmail,
    required this.onSmsChanged,
    required this.onEmailChanged,
  });

  /// The currently configured custom SMS destinations.
  final List<String>? customSms;

  /// The currently configured custom email destinations.
  final List<String>? customEmail;

  /// Called when the list of custom SMS destinations changes.
  ///
  /// The callback receives the updated list, or null when no list is
  /// available.
  final ValueChanged<List<String>?> onSmsChanged;

  /// Called when the list of custom email destinations changes.
  ///
  /// The callback receives the updated list, or null when no list is
  /// available.
  final ValueChanged<List<String>?> onEmailChanged;

  @override
  State<CustomDestinationInput> createState() => _CustomDestinationInputState();
}

/// State implementation for [CustomDestinationInput].
class _CustomDestinationInputState extends State<CustomDestinationInput> {
  late final ValueNotifier<List<String>> _sms, _email;

  @override
  void initState() {
    super.initState();

    _sms = ValueNotifier(widget.customSms ?? []);
    _email = ValueNotifier(widget.customEmail ?? []);

    _sms.addListener(_onCustomListChanged);
    _email.addListener(_onCustomListChanged);
  }

  void _onCustomListChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _sms.removeListener(_onCustomListChanged);
    _email.removeListener(_onCustomListChanged);
    _sms.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _getSubtitle() {
    AppLocalizations local = AppLocalizations.of(context)!;

    String subtitle = '';
    if (_sms.value.isEmpty && _email.value.isEmpty) {
      return null;
    } else {
      String part1, part2;
      int customSms = _sms.value.length;
      int customEmail = _email.value.length;

      switch (customSms) {
        case 0:
          part1 = '';
          break;
        case 1:
          part1 =
              '$customSms '
              '${local.translate("timer_configuration.contacts.sms.0")}';
          break;
        default:
          part1 =
              '$customSms '
              '${local.translate("timer_configuration.contacts.sms.1")}';
          break;
      }

      switch (customEmail) {
        case 0:
          part2 = '';
          break;
        case 1:
          part2 =
              ' • $customEmail '
              '${local.translate("timer_configuration.contacts.email.0")}';
          break;
        default:
          part2 =
              ' • $customEmail '
              '${local.translate("timer_configuration.contacts.email.1")}';
          break;
      }

      subtitle = part1 + part2;
    }

    return subtitle;
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return AppCard(
      child: Pressable(
        onTap: () => Navigator.of(context).push(
          AppRoute(
            page: CustomDestinationInputScreen(
              customSms: _sms,
              customEmail: _email,
              onSmsChanged: (value) {
                _sms.value = List<String>.of(value ?? []);
                widget.onSmsChanged(value);
              },
              onEmailChanged: (value) {
                _email.value = List<String>.of(value ?? []);
                widget.onEmailChanged(value);
              },
            ),
            transition: AppRouteTransitionType.slideLeft,
          ),
        ),
        child: AppRow(
          padding: EdgeInsets.zero,
          title: switch (_sms.value.length + _email.value.length) {
            0 => local.translate("timer_configuration.custom.none"),
            1 => '1 ${local.translate("timer_configuration.custom.subtitle.0")}',
            _ =>
              '${_sms.value.length + _email.value.length} '
                  '${local.translate("timer_configuration.custom.subtitle.1")}',
          },
          subtitle: _getSubtitle(),
          icon: (_sms.value.length + _email.value.length != 0) ? LucideIcons.user : LucideIcons.userX,
          iconColor: scheme.secondary,
          trailing: Icon(LucideIcons.chevronRight, size: 18, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// A screen for adding and managing custom SMS and email destinations.
///
/// The screen displays the currently configured destinations and allows users
/// to add new destinations or remove existing ones.
///
/// Changes are communicated to the parent through [onSmsChanged] and
/// [onEmailChanged]. The supplied [customSms] and [customEmail] listenables
/// are used to keep the screen synchronized with the current destination
/// state.
class CustomDestinationInputScreen extends StatefulWidget {
  /// Creates a screen for managing custom destinations.
  ///
  /// [customSms] provides the current SMS destinations.
  /// [customEmail] provides the current email destinations.
  /// [onSmsChanged] is called whenever an SMS destination is added or removed.
  /// [onEmailChanged] is called whenever an email destination is added or
  /// removed.
  const CustomDestinationInputScreen({
    super.key,
    required this.customSms,
    required this.customEmail,
    required this.onSmsChanged,
    required this.onEmailChanged,
  });

  /// Listenable containing the current custom SMS destinations.
  final ValueListenable<List<String>> customSms;

  /// Listenable containing the current custom email destinations.
  final ValueListenable<List<String>> customEmail;

  /// Called when the custom SMS destination list changes.
  final ValueChanged<List<String>?> onSmsChanged;

  /// Called when the custom email destination list changes.
  final ValueChanged<List<String>?> onEmailChanged;

  @override
  State<CustomDestinationInputScreen> createState() => _CustomDestinationInputScreenState();
}

/// State implementation for [CustomDestinationInputScreen].
class _CustomDestinationInputScreenState extends State<CustomDestinationInputScreen> {
  late List<String> _sms, _email;

  @override
  void initState() {
    super.initState();

    _sms = widget.customSms.value;
    _email = widget.customEmail.value;

    widget.customSms.addListener(_onCustomListChanged);
    widget.customEmail.addListener(_onCustomListChanged);
  }

  void _onCustomListChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.customSms.removeListener(_onCustomListChanged);
    widget.customEmail.removeListener(_onCustomListChanged);
    super.dispose();
  }

  String? _getSubtitle() {
    AppLocalizations local = AppLocalizations.of(context)!;

    String subtitle = '';
    if (_sms.isEmpty && _email.isEmpty) {
      return null;
    } else {
      String part1, part2;
      int customSms = _sms.length;
      int customEmail = _email.length;

      switch (customSms) {
        case 0:
          part1 = '';
          break;
        case 1:
          part1 =
              '$customSms '
              '${local.translate("timer_configuration.contacts.sms.0")}';
          break;
        default:
          part1 =
              '$customSms '
              '${local.translate("timer_configuration.contacts.sms.1")}';
          break;
      }

      switch (customEmail) {
        case 0:
          part2 = '';
          break;
        case 1:
          part2 =
              ' • $customEmail '
              '${local.translate("timer_configuration.contacts.email.0")}';
          break;
        default:
          part2 =
              ' • $customEmail '
              '${local.translate("timer_configuration.contacts.email.1")}';
          break;
      }

      subtitle = part1 + part2;
    }

    return subtitle;
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return ScreenBase(
      header: AppHeader(
        title: local.translate("timer_configuration.custom.title"),
        subtitle: _getSubtitle(),
        left: CircleIconButton(icon: LucideIcons.chevronLeft, onTap: () => Navigator.pop(context)),
        right: CircleIconButton(
          icon: LucideIcons.plus,
          onTap: () {
            showBlurredBottomSheet(
              scheme: scheme,
              context: context,
              marginHorizontal: 50,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: Pressable(
                            factory: InkSparkle.splashFactory,
                            onTap: () async {
                              Navigator.of(context).pop();

                              String? sms = await _showTextPrompt(context);
                              if (sms == null) return;

                              if (!_sms.contains(sms)) {
                                _sms.add(sms);
                                widget.onSmsChanged(_sms);
                              }
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.messageSquare, size: AppSpacing.xxxxl, color: scheme.primary),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  local.translate("timer_configuration.custom.phone.title"),
                                  style: AppText.caption(scheme).copyWith(color: scheme.onSurface),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        /* //add the below SizedBox for email support
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: Pressable(
                            factory: InkSparkle.splashFactory,
                            onTap: () async {
                              Navigator.of(context).pop();

                              String? email = await _showTextPrompt(
                                context,
                                mode: "email",
                              );
                              if (email == null) return;

                              if (!_email.contains(email)) {
                                _email.add(email);
                                widget.onEmailChanged(_email);
                              }
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.mail,
                                  size: AppSpacing.xxxxl,
                                  color: scheme.tertiary,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  local.translate(
                                    "timer_configuration.custom.email.title",
                                  ),
                                  style: AppText.caption(
                                    scheme,
                                  ).copyWith(color: scheme.onSurface),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        */
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.lg),
              children: [
                if (_sms.isEmpty && _email.isEmpty) ...[
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
                        child: Icon(LucideIcons.userX, size: 36, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        local.translate("timer_configuration.custom.none"),
                        style: AppText.bodySm(scheme).copyWith(color: scheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ] else ...[
                  if (_sms.isNotEmpty) ...[
                    SectionTitle(local.translate("timer_configuration.contacts.sms.1"), action: Text('${_sms.length}', style: AppText.micro(scheme))),
                    AppCard(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          for (int i = 0; i < _sms.length; i++) ...[
                            Pressable(
                              onTap: () {
                                _sms.remove(_sms[i]);
                                widget.onSmsChanged(_sms);
                              },
                              child: AppRow(title: _sms[i], trailing: Icon(LucideIcons.trash, size: 20)),
                            ),
                            if (i < _sms.length - 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                child: Divider(height: 1, color: scheme.outlineVariant),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (_email.isNotEmpty) ...[
                    SectionTitle(
                      local.translate("timer_configuration.contacts.email.1"),
                      action: Text('${_email.length}', style: AppText.micro(scheme)),
                    ),
                    AppCard(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          for (int i = 0; i < _email.length; i++) ...[
                            Pressable(
                              onTap: () {
                                _email.remove(_email[i]);
                                widget.onEmailChanged(_email);
                              },
                              child: AppRow(title: _email[i], trailing: Icon(LucideIcons.trash, size: 20)),
                            ),
                            if (i < _email.length - 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                child: Divider(height: 1, color: scheme.outlineVariant),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays a bottom-sheet prompt for entering a custom destination.
///
/// The prompt supports SMS/phone and email destinations, depending on [mode].
/// The entered value is validated before the bottom sheet is dismissed.
///
/// Returns the entered and validated value, or null if the prompt is
/// dismissed without submitting a valid value.
Future<String?> _showTextPrompt(BuildContext context, {String mode = 'sms'}) async {
  ColorScheme scheme = Theme.of(context).colorScheme;
  AppLocalizations local = AppLocalizations.of(context)!;

  final TextEditingController valueController = TextEditingController();
  final FocusNode valueFocus = FocusNode();

  bool isValidEmail(String value) {
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return regex.hasMatch(value);
  }

  bool isValidPhone(String value) {
    final regex = RegExp(r'^\+?[0-9\s\-\(\)]{7,20}$');
    return regex.hasMatch(value);
  }

  void valueWritten() {
    if (valueController.text.isEmpty) return;

    bool result = false;
    switch (mode) {
      case 'email':
        result = isValidEmail(valueController.text);
        break;
      default:
        result = isValidPhone(valueController.text);
        break;
    }

    if (result) {
      valueFocus.unfocus();
      Navigator.of(context).pop(valueController.text);
      valueController.dispose();
      valueFocus.dispose();
    } else {
      showToast(
        scheme: scheme,
        toast: Text(
          switch (mode) {
            'email' => local.translate("timer_configuration.custom.email.validation"),
            _ => local.translate("timer_configuration.custom.phone.validation"),
          },
          style: AppText.bodySm(scheme),
          textAlign: TextAlign.center,
        ),
        gravity: ToastGravity.TOP,
        position: (context, child, gravity) {
          return Positioned(top: (valueFocus.hasFocus) ? 38 : null, bottom: (valueFocus.hasFocus) ? null : 160, left: 60, right: 60, child: child);
        },
      );
    }
  }

  return showBlurredBottomSheet<String>(
    context: context,
    scheme: scheme,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => valueFocus.requestFocus(),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: valueController,
              focusNode: valueFocus,
              keyboardType: switch (mode) {
                'email' => TextInputType.emailAddress,
                _ => TextInputType.phone,
              },
              maxLength: 255,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              style: AppText.body(scheme),
              cursorColor: scheme.primary,
              scrollPadding: const EdgeInsets.all(0),
              inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
              decoration: InputDecoration(
                hintText: switch (mode) {
                  'email' => local.translate("timer_configuration.custom.email.hint"),
                  _ => local.translate("timer_configuration.custom.phone.hint"),
                },
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                border: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
              ),
              obscureText: false,
              onTap: () {
                valueController.selection = TextSelection(baseOffset: 0, extentOffset: valueController.text.length);
              },
              onSubmitted: (_) => valueWritten(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: SizedBox(
              height: 64,
              child: PrimaryButton(
                width: 64,
                icon: switch (mode) {
                  'email' => LucideIcons.mailCheck,
                  _ => LucideIcons.messageSquareCheck,
                },
                onPressed: () => valueWritten(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
