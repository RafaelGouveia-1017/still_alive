import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';
import 'package:still_alive/src/rust/api/timer/config.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';
import 'config_fields.dart';

/// A screen for creating a new timer or editing an existing timer
/// configuration.
///
/// The screen supports two construction modes:
/// * [TimerConfigScreen.newTimer] creates a new timer configuration with
/// default values.
/// * [TimerConfigScreen.existingTimer] loads and edits an existing timer
/// identified by [timerKey].
///
/// The screen provides controls for configuring the timer name, duration,
/// grace period, security options, location and route sharing, audio
/// recording, contacts, custom destinations, and external integrations.
///
/// Changes are kept in the local [TimerConfig] instance while the user edits
/// the form. When the form is submitted, the configuration is either saved
/// as a new timer or used to replace the currently active timer when the
/// active-timer state requires it.
class TimerConfigScreen extends StatefulWidget {
  /// Creates a screen for configuring a new timer.
  ///
  /// The timer key is generated when the screen loads, and the timer
  /// configuration is initialized with the application's default values.
  const TimerConfigScreen.newTimer({super.key})
    : isNew = true,
      timerKey = null,
      timerData = null;

  /// Creates a screen for editing an existing timer.
  ///
  /// The existing timer's [timerKey] and [timerData] are used as the initial
  /// configuration values displayed by the form.
  const TimerConfigScreen.existingTimer({
    super.key,
    required String this.timerKey,
    required TimerConfig this.timerData,
  }) : isNew = false;

  /// Whether this screen is configuring a new timer.
  ///
  /// When true, the screen initializes a new [TimerConfig] and generates
  /// a unique timer key. When false, [timerKey] and [timerData] identify
  /// and contain the existing timer being edited.
  final bool isNew;

  /// The unique key identifying the timer being configured.
  ///
  /// This value is null when [isNew] is true because a key is generated
  /// when the screen initializes. When editing an existing timer, this value
  /// identifies the timer whose configuration is being modified.
  final String? timerKey;

  /// The configuration of the timer being edited.
  ///
  /// This value is null when [isNew] is true. For an existing timer,
  /// it contains the current configuration used to initialize the form.
  final TimerConfig? timerData;

  @override
  State<TimerConfigScreen> createState() => _TimerConfigScreenState();
}

/// State implementation for [TimerConfigScreen].
///
/// Manages the timer configuration being edited, including its generated or
/// existing key, form state, duration, selected contacts, and loading state.
///
/// When creating a new timer, the state obtains a unique timer key and
/// initializes a [TimerConfig] with default values. When editing an existing
/// timer, the supplied configuration is used as the initial state.
///
/// The state also determines whether saving the configuration should create
/// a new timer or replace the currently active timer. Changes made by the
/// configuration controls are applied directly to the current
/// [TimerConfig] instance and are persisted when the user submits the form.
class _TimerConfigScreenState extends State<TimerConfigScreen> {
  late String _timerKey;
  late TimerConfig _timerData;
  late final ValueNotifier<Duration> _timerDuration;
  late final ValueNotifier<List<Contact>> _timerContacts;

  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _timerDuration = ValueNotifier(const Duration(minutes: 30));
    _timerContacts = ValueNotifier([]);

    load();
  }

  void load() async {
    setState(() => _isLoading = true);

    try {
      String key = widget.timerKey ?? (await getUniqueTimerId())!;
      TimerConfig data =
          widget.timerData ??
          TimerConfig(
            name: "",
            durationSecs: 0,
            gracePeriodSecs: null,
            passwordProtected: false,
            passwordHash: null,
            locationSharingEnabled: false,
            routeSharingEnabled: false,
            locationCollectionIntervalSecs: null,
            audioRecordingEnabled: false,
            contacts: [],
            customSms: [],
            customEmail: [],
            integrations: TimerIntegrations(
              discord: TimerIntegration(accounts: []),
              telegram: TimerIntegration(accounts: []),
            ),
            createdAt: "",
            updatedAt: "",
          );

      setState(() {
        _timerKey = key;
        _timerData = data;
        _timerDuration.value = Duration(seconds: data.durationSecs);
        _timerContacts.value = data.contacts;
        _isLoading = false;
      });
    } catch (e, st) {
      AppLogger.log.severe('SQL failed:', e, st);
      if (!mounted) return;
      showGenericErrorMessage(context, null);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _timerDuration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    bool hasActiveTimer = TimerService.instance.hasActiveTimer;

    ActiveTimer activeTimer = TimerService.instance.activeTimer;
    String key = activeTimer.key;

    bool shouldReplace =
        key == 'timer0' ||
        (!hasActiveTimer && (widget.isNew || key == widget.timerKey));

    return ScreenBase(
      header: AppHeader(
        title: (widget.isNew)
            ? local.translate("timer_configuration.title_new")
            : local.translate("timer_configuration.title_edit"),
        left: (_isLoading)
            ? SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: CircularProgressIndicator(color: scheme.tertiary),
                ),
              )
            : CircleIconButton(
                icon: LucideIcons.chevronLeft,
                onTap: () => Navigator.pop(context),
              ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    if (_isLoading) ...[
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.lg),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: scheme.tertiary,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SectionTitle(
                        local.translate("timer_configuration.name.title"),
                      ),
                      NameInput(
                        name: (widget.isNew) ? null : _timerData.name,
                        onChanged: (String value) => _timerData.name = value,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      SectionTitle(
                        local.translate("timer_configuration.duration.title"),
                      ),
                      DurationInput(
                        durationTimer: (widget.isNew)
                            ? null
                            : Duration(seconds: _timerData.durationSecs),
                        onChanged: (Duration value) {
                          _timerData.durationSecs = value.inSeconds;
                          _timerDuration.value = value;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      SectionTitle(
                        local.translate(
                          "timer_configuration.grace_period.title",
                        ),
                      ),
                      GraceInput(
                        gracePeriod:
                            (widget.isNew || _timerData.gracePeriodSecs == null)
                            ? null
                            : Duration(seconds: _timerData.gracePeriodSecs!),
                        onChanged: (Duration value) =>
                            _timerData.gracePeriodSecs = (value.inSeconds == 0)
                            ? null
                            : value.inSeconds,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      SectionTitle(
                        local.translate("timer_configuration.security.title"),
                      ),
                      if (widget.isNew) ...[
                        PasswordInput.newTimer(
                          onProtectedChanged: (bool value) =>
                              _timerData.passwordProtected = value,
                          onHashChanged: (String? value) =>
                              _timerData.passwordHash = value,
                        ),
                      ] else ...[
                        PasswordInput.existingTimer(
                          protected: _timerData.passwordProtected,
                          hasHash: _timerData.passwordHash == null,
                          onProtectedChanged: (bool value) =>
                              _timerData.passwordProtected = value,
                          onHashChanged: (String? value) =>
                              _timerData.passwordHash = value,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),

                      LocationInputs(
                        timerDuration: _timerDuration,
                        locationEnabled: (widget.isNew)
                            ? null
                            : _timerData.locationSharingEnabled,
                        routeEnabled: (widget.isNew)
                            ? null
                            : _timerData.routeSharingEnabled,
                        collectionInterval:
                            (widget.isNew ||
                                _timerData.locationCollectionIntervalSecs ==
                                    null)
                            ? null
                            : _timerData.locationCollectionIntervalSecs!,
                        onLocationChanged: (bool value) =>
                            _timerData.locationSharingEnabled = value,
                        onRouteChanged: (bool value) =>
                            _timerData.routeSharingEnabled = value,
                        onCollectionIntervalChanged: (int? value) =>
                            _timerData.locationCollectionIntervalSecs = value,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      AudioInput(
                        enabled: (widget.isNew)
                            ? null
                            : _timerData.audioRecordingEnabled,
                        onChanged: (bool value) =>
                            _timerData.audioRecordingEnabled = value,
                      ),

                      const SizedBox(height: AppSpacing.lg),
                      SectionTitle(
                        local.translate("timer_configuration.contacts.title"),
                      ),
                      FormField(
                        builder: (field) => Column(
                          children: [
                            ContactSelection(
                              timerContacts: _timerContacts,
                              onChanged: (List<Contact>? value) {
                                final contacts = List<Contact>.of(value ?? []);

                                _timerData.contacts = contacts;
                                _timerContacts.value = contacts;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),

                            CustomDestinationInput(
                              customSms: [],
                              customEmail: [],
                              onSmsChanged: (List<String>? value) =>
                                  _timerData.customSms = value ?? [],
                              onEmailChanged: (List<String>? value) =>
                                  _timerData.customEmail = value ?? [],
                            ),
                            const SizedBox(height: AppSpacing.md),

                            IntegrationSelection(
                              integrations: _timerData.integrations,
                              onChanged: (TimerIntegrations value) =>
                                  _timerData.integrations = value,
                            ),

                            if (field.hasError)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                ),
                                child: Text(
                                  field.errorText!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        validator: (_) {
                          if (_timerData.contacts.isEmpty &&
                              _timerData.customSms.isEmpty &&
                              _timerData.customEmail.isEmpty &&
                              _timerData
                                  .integrations
                                  .discord
                                  .accounts
                                  .isEmpty &&
                              _timerData
                                  .integrations
                                  .telegram
                                  .accounts
                                  .isEmpty) {
                            return local.translate(
                              "timer_configuration.validation",
                            );
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppSpacing.xl),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            if (!widget.isNew) ...[
                              Pressable(
                                onTap: null,
                                child: SizedBox(
                                  width: 64,
                                  child: PrimaryButton(
                                    icon: LucideIcons.trash,
                                    color: ButtonColor.warning,
                                    onPressed: () async {
                                      setState(() => _isLoading = true);

                                      bool?
                                      deleted = await showBlurredBottomSheet<bool>(
                                        context: context,
                                        scheme: scheme,
                                        marginHorizontal: 50,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              local.translate(
                                                "timer_configuration.delete.0",
                                              ),
                                              style: AppText.body(scheme),
                                              textAlign: TextAlign.center,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: AppSpacing.xl,
                                                bottom: AppSpacing.lg,
                                              ),
                                              child: PrimaryButton(
                                                label: local.translate(
                                                  "timer_configuration.delete.1",
                                                ),
                                                color: ButtonColor.warning,
                                                onPressed: () async {
                                                  setState(
                                                    () => _isLoading = true,
                                                  );

                                                  bool
                                                  result = await TimerService
                                                      .instance
                                                      .removeTimerFromDatabase(
                                                        _timerKey,
                                                      );

                                                  if (!context.mounted) return;
                                                  Navigator.pop(
                                                    context,
                                                    result,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      deleted ??= false;
                                      setState(() => _isLoading = false);

                                      if (deleted) {
                                        showToast(
                                          scheme: scheme,
                                          toast: Text(
                                            '"${_timerData.name}" ${local.translate("timer_configuration.delete.2")}',
                                            style: AppText.bodySm(scheme),
                                            textAlign: TextAlign.center,
                                          ),
                                          gravity: ToastGravity.BOTTOM,
                                          position: (context, child, gravity) {
                                            return Positioned(
                                              bottom: 140,
                                              left: 40,
                                              right: 40,
                                              child: child,
                                            );
                                          },
                                        );
                                        if (!context.mounted) return;
                                        Navigator.pop(context);
                                      } else {
                                        if (!context.mounted) return;
                                        showGenericErrorMessage(context, null);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                            ],

                            Expanded(
                              child: Pressable(
                                onTap: null,
                                child: PrimaryButton(
                                  label: (widget.isNew)
                                      ? local.translate(
                                          "timer_configuration.create",
                                        )
                                      : local.translate(
                                          "timer_configuration.edit",
                                        ),
                                  icon: (shouldReplace)
                                      ? LucideIcons.shieldCheck
                                      : LucideIcons.shield,
                                  color: ButtonColor.tertiary,
                                  onPressed: () async {
                                    if (!_formKey.currentState!.validate()) {
                                      showToast(
                                        scheme: scheme,
                                        toast: Text(
                                          local.translate(
                                            "timer_configuration.validation_error",
                                          ),
                                          style: AppText.bodySm(scheme),
                                          textAlign: TextAlign.center,
                                        ),
                                        gravity: ToastGravity.BOTTOM,
                                        position: (context, child, gravity) {
                                          return Positioned(
                                            bottom: 140,
                                            left: 60,
                                            right: 60,
                                            child: child,
                                          );
                                        },
                                      );
                                      return;
                                    }

                                    String now = DateTime.now()
                                        .toIso8601String();
                                    if (widget.isNew) {
                                      _timerData.createdAt = now;
                                    }
                                    _timerData.updatedAt = now;

                                    try {
                                      setState(() {
                                        _isLoading = true;
                                      });

                                      if (shouldReplace) {
                                        await activeTimer.replaceActiveTimer(
                                          key: _timerKey,
                                          config: _timerData,
                                          nowMs: DateTime.now()
                                              .toUtc()
                                              .millisecondsSinceEpoch,
                                        );
                                      } else {
                                        await createTimer(config: _timerData);
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
