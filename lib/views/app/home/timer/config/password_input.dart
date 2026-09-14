import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';

/// A password protection input for timer configuration.
///
/// [PasswordInput] allows the user to enable or disable password protection
/// for a timer and, when required, enter a password. The password is hashed
/// before being passed to [onHashChanged].
///
/// Use [PasswordInput.newTimer] when configuring a new timer. In this mode,
/// the initial password protection preference is loaded from the application
/// settings.
///
/// Use [PasswordInput.existingTimer] when editing an existing timer. In this
/// mode, the existing password protection state and hash status are provided
/// directly.
class PasswordInput extends StatefulWidget {
  /// Creates a password input for a new timer.
  ///
  /// The initial password protection state is loaded from the application
  /// settings.
  ///
  /// [onProtectedChanged] is called whenever password protection is enabled
  /// or disabled.
  ///
  /// [onHashChanged] is called whenever the password hash changes. A `null`
  /// value indicates that no password is currently configured.
  const PasswordInput.newTimer({
    super.key,
    required this.onProtectedChanged,
    required this.onHashChanged,
  }) : isNew = true,
       protected = null,
       hasHash = false;

  /// Creates a password input for an existing timer.
  ///
  /// [protected] specifies whether password protection is currently enabled.
  /// [hasHash] specifies whether the timer already has a configured password.
  ///
  /// [onProtectedChanged] is called whenever password protection is enabled
  /// or disabled.
  ///
  /// [onHashChanged] is called whenever the password hash changes. A `null`
  /// value indicates that no password is currently configured.
  const PasswordInput.existingTimer({
    super.key,
    required this.protected,
    required this.hasHash,
    required this.onProtectedChanged,
    required this.onHashChanged,
  }) : isNew = false;

  /// Whether this input is being used to configure a new timer.
  ///
  /// When `true`, the initial password protection state is loaded from the
  /// application settings. When `false`, the state is taken from [protected].
  final bool isNew;

  /// Whether password protection is currently enabled.
  ///
  /// This value is provided when editing an existing timer and is `null` for
  /// new timers, where the initial value is loaded from the application
  /// settings.
  final bool? protected;

  /// Whether an existing password hash is already configured.
  ///
  /// This value is used when editing an existing timer to determine whether
  /// the password entry field should be displayed.
  final bool? hasHash;

  /// Called when the password protection state changes.
  ///
  /// The callback receives `true` when password protection is enabled and
  /// `false` when it is disabled.
  final ValueChanged<bool> onProtectedChanged;

  /// Called when the password hash changes.
  ///
  /// Receives the newly generated hash, or `null` when the password is
  /// removed or cleared.
  final ValueChanged<String?> onHashChanged;

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

/// State implementation for [PasswordInput].
///
/// Manages the password input controller, focus state, password protection
/// state, and password hash. It also loads the default password protection
/// preference when configuring a new timer.
class _PasswordInputState extends State<PasswordInput> {
  late final TextEditingController _passController;
  late final FocusNode _passFocus;

  bool _isLoading = true;
  late bool _protected;
  late bool _hasHash;

  String? _hash;

  @override
  void initState() {
    super.initState();

    _passController = TextEditingController();
    _passFocus = FocusNode();

    _hasHash = widget.hasHash ?? false;

    if (widget.isNew) {
      loadPref();
    } else {
      _protected = widget.protected!;
      _isLoading = false;
    }
  }

  void loadPref() async {
    String value = await selectOne(
      sql: "SELECT value FROM settings WHERE key = 'lock'",
    );

    bool pref = (value == "true");

    widget.onProtectedChanged(pref);

    setState(() {
      _protected = pref;
      _isLoading = false;
    });
  }

  void _setProtected(bool value) {
    if (_protected == value) return;

    setState(() {
      _protected = value;
    });

    widget.onProtectedChanged(value);

    // Turning password protection off removes the password hash.
    if (!value) {
      _setHash(null);

      _passFocus.unfocus();
      _passController.clear();
    }
  }

  void _setHash(String? value) {
    if (_hash == value && _hasHash == (value != null)) {
      return;
    }

    _hash = value;
    _hasHash = value != null;

    widget.onHashChanged(value);

    setState(() {});
  }

  void _onPasswordChanged(String value) {
    if (value.isEmpty) {
      _setHash(null);
      return;
    }

    final String hash = TimerService.generatePasswordHash(value);
    _setHash(hash);
  }

  @override
  void dispose() {
    _passController.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: (_isLoading)
          ? SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: CircularProgressIndicator(color: scheme.tertiary),
              ),
            )
          : Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _setProtected(!_protected);
                  },
                  child: AppRow(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxxs,
                      horizontal: AppSpacing.sm,
                    ),
                    title: local.translate(
                      "timer_configuration.security.password.cancel_password",
                    ),
                    subtitle: (_protected)
                        ? local.translate(
                            "timer_configuration.security.password.pin_requirement.on",
                          )
                        : local.translate(
                            "timer_configuration.security.password.pin_requirement.off",
                          ),
                    icon: (_protected)
                        ? LucideIcons.lock
                        : LucideIcons.lockOpen,
                    iconColor: scheme.secondary,
                    trailing: AppToggle(on: _protected),
                  ),
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: AppMotion.fasterer,
                    curve: AppMotion.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _protected
                        ? _buildPasswordSection(context, local, scheme)
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPasswordSection(
    BuildContext context,
    AppLocalizations local,
    ColorScheme scheme,
  ) {
    // Existing timer with an already configured password.
    if (!widget.isNew && _hasHash) {
      return SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Center(
            child: Text(
              local.translate("timer_configuration.security.password.exists"),
              style: AppText.bodySm(scheme).copyWith(color: scheme.error),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _passFocus.requestFocus(),
      child: Column(
        children: [
          TextFormField(
            controller: _passController,
            focusNode: _passFocus,
            keyboardType: TextInputType.visiblePassword,
            maxLength: 30,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            style: AppText.body(scheme),
            cursorColor: scheme.primary,
            scrollPadding: const EdgeInsets.all(0),
            inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
            decoration: InputDecoration(
              hintText: local.translate(
                "timer_configuration.security.password.password_hint",
              ),
              counterText: '',
              contentPadding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              border: InputBorder.none,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.ms),
                child: Icon(LucideIcons.keyRound, size: 18),
              ),
              prefixIconConstraints: BoxConstraints.tightFor(width: 30),
              isDense: true,
              filled: false,
              fillColor: Colors.transparent,
            ),
            onTap: () {
              _passController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _passController.text.length,
              );
            },
            onChanged: _onPasswordChanged,
            errorBuilder: (context, errorText) => Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                errorText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return local.translate(
                  "timer_configuration.security.password.validation",
                );
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            borderColor: scheme.secondary.withAlpha(64),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withAlpha(38),
                scheme.secondary.withAlpha(26),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.triangleAlert,
                  size: 20,
                  color: scheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        local.translate(
                          "timer_configuration.security.password.note.title",
                        ),
                        style: AppText.bodySm(scheme),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        local.translate(
                          "timer_configuration.security.password.note.description",
                        ),
                        style: AppText.caption(scheme),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
