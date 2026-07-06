import 'dart:math' as math;
import 'dart:developer';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:restart_app/restart_app.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../src/rust/api/data/db.dart';
import '../../../src/rust/api/backup.dart';

import '../../../data/all.dart';
import '../../widgets/primitives.dart';
import 'themes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// State implementation for [SettingsScreen].
class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  PermissionStatus _locationWhenInUsePermissionStatus = PermissionStatus.denied;
  PermissionStatus _locationAlwaysPermissionStatus = PermissionStatus.denied;
  PermissionStatus _microphonePermissionStatus = PermissionStatus.denied;

  bool _locationFeature = true;
  bool _routeFeature = true;
  bool _microphoneFeature = true;
  bool _lockFeature = true;

  int _volumeFeature = 100;

  String _messageFeature = "";
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionsStatuses();
    _featureStatuses();
  }

  void _permissionsStatuses() async {
    final locationWhenInUseGranted = await Permission.locationWhenInUse.status;
    final locationAlwaysGranted = await Permission.locationAlways.status;
    final microphoneGranted = await Permission.microphone.status;

    if (!mounted) return;
    setState(() {
      _locationWhenInUsePermissionStatus = locationWhenInUseGranted;
      _locationAlwaysPermissionStatus = locationAlwaysGranted;
      _microphonePermissionStatus = microphoneGranted;
    });
  }

  void _featureStatuses() async {
    final jsonStr = await select(
      sql:
          "SELECT value FROM settings WHERE key IN ('location', 'route', 'microphone', 'lock', 'volume', 'message') ORDER BY key",
    );
    final List data = jsonDecode(jsonStr);

    if (!mounted) return;
    setState(() {
      _locationFeature = data[0]['value'].toString().toLowerCase() == "true";
      _lockFeature = data[1]['value'].toString().toLowerCase() == "true";
      _messageFeature = data[2]['value'].toString();
      _microphoneFeature = data[3]['value'].toString().toLowerCase() == "true";
      _routeFeature = data[4]['value'].toString().toLowerCase() == "true";
      _volumeFeature = int.parse(data[5]['value'].toString());
    });
  }

  void _requestPermissionStatus(Permission p) async {
    final status = await PermissionManager.instance.requestPermission(p);
    if (!mounted) return;
    if (p == Permission.locationWhenInUse) {
      setState(() => _locationWhenInUsePermissionStatus = status);
    }
    if (p == Permission.locationAlways) {
      setState(() => _locationAlwaysPermissionStatus = status);
    }
    if (p == Permission.microphone) {
      setState(() => _microphonePermissionStatus = status);
    }
  }

  Widget permissionState(
    ColorScheme scheme,
    AppLocalizations local,
    Permission p,
    PermissionStatus status,
  ) {
    return status.isGranted
        ? switch (p) {
            Permission.locationWhenInUse => AppToggle(on: _locationFeature),
            Permission.locationAlways => AppToggle(on: _routeFeature),
            _ => AppToggle(on: _microphoneFeature),
          }
        : Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: AppRadius.chip,
            ),
            child: Text(
              switch (status) {
                PermissionStatus.denied => local.translate("permissions.allow"),
                _ => local.translate("settings.title"),
              },
              style: AppText.caption(scheme).copyWith(color: scheme.onPrimary),
            ),
          );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _permissionsStatuses();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;
    LocaleProvider localeProvider = Provider.of<LocaleProvider>(context);

    AppLanguage currentLanguage = AppLocalizationsDelegate.supportedLocales
        .firstWhere(
          (l) => l.locale == localeProvider.locale,
          orElse: () => AppLocalizationsDelegate.supportedLocales.first,
        );

    Icon chevron = Icon(
      LucideIcons.chevronRight,
      size: 18,
      color: scheme.onSurfaceVariant,
    );

    return ScreenBase(
      bottomNavDestination: 'settings',
      child: Column(
        children: [
          AppHeader(title: local.translate('settings.title')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.lg),
              children: [
                SectionTitle(
                  local.translate("settings.sections.customization.title"),
                ),
                AppCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xxs,
                  ),
                  margin: EdgeInsets.only(bottom: AppRadius.xl),
                  child: Column(
                    children: [
                      Pressable(
                        onTap: () => Navigator.of(context).push(
                          AppRoute(
                            page: ThemesScreen(),
                            transition: AppRouteTransitionType.slideLeft,
                          ),
                        ),
                        child: FutureBuilder<String>(
                          future: CustomTheme.load(),
                          builder: (context, snapshot) {
                            return AppRow(
                              icon: LucideIcons.palette,
                              title: local.translate(
                                "settings.sections.customization.labels.0",
                              ),
                              subtitle:
                                  "${local.translate("settings.sections.customization.labels.1")} ${snapshot.data}",
                              trailing: chevron,
                            );
                          },
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      Pressable(
                        onTap: () {
                          showBlurredBottomSheet(
                            scheme: scheme,
                            context: context,
                            marginHorizontal: 75,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: AppLocalizationsDelegate
                                  .supportedLocales
                                  .length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: scheme.outlineVariant,
                              ),
                              itemBuilder: (context, index) {
                                final lang = AppLocalizationsDelegate
                                    .supportedLocales[index];

                                return Pressable(
                                  factory: InkSparkle.splashFactory,
                                  onTap: () {
                                    localeProvider.setLocale(lang.locale);
                                    Navigator.pop(context);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.lg,
                                    ),
                                    child: Text(
                                      lang.label,
                                      style: AppText.body(scheme),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        child: AppRow(
                          icon: LucideIcons.languages,
                          title: local.translate(
                            "settings.sections.customization.labels.2",
                          ),
                          subtitle:
                              "${local.translate("settings.sections.customization.labels.1")} ${currentLanguage.label}",
                          trailing: chevron,
                        ),
                      ),
                    ],
                  ),
                ),

                SectionTitle(local.translate("settings.sections.alerts.title")),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xxs,
                  ),
                  margin: EdgeInsets.only(bottom: AppRadius.xl),
                  child: Column(
                    children: [
                      Pressable(
                        onTap: () {
                          _messageController.text = _messageFeature;
                          showBlurredBottomSheet(
                            scheme: scheme,
                            context: context,
                            marginHorizontal: 15,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  local.translate(
                                    "settings.sections.alerts.labels.2",
                                  ),
                                  style: AppText.micro(
                                    scheme,
                                  ).copyWith(color: scheme.onSurface),
                                  textAlign: TextAlign.center,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.xs,
                                  ),
                                  child: TextFormField(
                                    controller: _messageController,
                                    style: AppText.caption(
                                      scheme,
                                    ).copyWith(color: scheme.onSurface),
                                    cursorColor: scheme.primary,
                                    scrollPadding: const EdgeInsets.all(0),
                                    maxLines: 12,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xxxs,
                                            vertical: AppSpacing.xxxs,
                                          ),
                                      border: OutlineInputBorder(),
                                      hintText: local.translate(
                                        "settings.sections.alerts.labels.3",
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).then((res) async {
                            final tempMessage = _messageController.text;
                            if (tempMessage == _messageFeature) return;

                            await executeSql(
                              sql:
                                  "UPDATE settings SET value = '$tempMessage' WHERE key = 'message'",
                            );

                            setState(() {
                              _messageFeature = tempMessage;
                            });

                            showToast(
                              scheme: scheme,
                              toast: Text(
                                local.translate(
                                  "settings.sections.alerts.labels.4",
                                ),
                                style: AppText.bodySm(scheme),
                                textAlign: TextAlign.center,
                              ),
                              gravity: ToastGravity.BOTTOM,
                              position: (context, child, gravity) {
                                return Positioned(
                                  bottom: 170,
                                  left: 60,
                                  right: 60,
                                  child: child,
                                );
                              },
                              secs: 5,
                            );
                          });
                        },
                        child: AppRow(
                          icon: LucideIcons.messageSquare,
                          title: local.translate(
                            "settings.sections.alerts.labels.0",
                          ),
                          subtitle: local.translate(
                            "settings.sections.alerts.labels.1",
                          ),
                          trailing: chevron,
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      Pressable(
                        onTap: () {
                          int tempVolume = _volumeFeature;
                          showBlurredBottomSheet(
                            scheme: scheme,
                            context: context,
                            marginHorizontal: 25,
                            child: StatefulBuilder(
                              builder: (context, setState) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(height: AppSpacing.xxl),
                                    Slider(
                                      // ignore: deprecated_member_use
                                      year2023: true,
                                      activeColor: scheme.primary,
                                      inactiveColor: scheme.surfaceContainerLow,
                                      secondaryActiveColor: scheme.primary
                                          .withAlpha(155),
                                      thumbColor: scheme.onSurface,
                                      value: tempVolume.toDouble(),
                                      secondaryTrackValue: _volumeFeature
                                          .toDouble(),
                                      max: 100,
                                      divisions: 10,
                                      label: switch (tempVolume) {
                                        100 => local.translate(
                                          "settings.sections.alerts.labels.6",
                                        ),
                                        0 => local.translate(
                                          "settings.sections.alerts.labels.7",
                                        ),
                                        _ => "$tempVolume%",
                                      },
                                      onChanged: (double value) {
                                        setState(() {
                                          tempVolume = value.round();
                                        });
                                      },
                                      showValueIndicator:
                                          ShowValueIndicator.alwaysVisible,
                                    ),
                                    SizedBox(height: AppSpacing.xxl),
                                  ],
                                );
                              },
                            ),
                          ).then((res) async {
                            await executeSql(
                              sql:
                                  "UPDATE settings SET value = '$tempVolume' WHERE key = 'volume'",
                            );
                            setState(() {
                              _volumeFeature = tempVolume;
                            });
                          });
                        },
                        child: AppRow(
                          icon: (_volumeFeature > 0)
                              ? (_volumeFeature > 50)
                                    ? LucideIcons.volume2
                                    : LucideIcons.volume1
                              : LucideIcons.volumeX,
                          title: local.translate(
                            "settings.sections.alerts.labels.5",
                          ),
                          subtitle: switch (_volumeFeature) {
                            100 => local.translate(
                              "settings.sections.alerts.labels.6",
                            ),
                            0 => local.translate(
                              "settings.sections.alerts.labels.7",
                            ),
                            _ => "$_volumeFeature%",
                          },
                          trailing: chevron,
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          await executeSql(
                            sql:
                                "UPDATE settings SET value = '${!_lockFeature}' WHERE key = 'lock'",
                          );
                          setState(() {
                            _lockFeature = !_lockFeature;
                          });
                        },
                        child: AppRow(
                          icon: _lockFeature
                              ? LucideIcons.lock
                              : LucideIcons.lockOpen,
                          title: local.translate(
                            "settings.sections.alerts.labels.8",
                          ),
                          subtitle: local.translate(
                            "settings.sections.alerts.labels.9",
                          ),
                          trailing: AppToggle(on: _lockFeature),
                        ),
                      ),
                    ],
                  ),
                ),

                SectionTitle(
                  local.translate("settings.sections.privacy.title"),
                ),
                AppCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xxs,
                  ),
                  margin: EdgeInsets.only(bottom: AppRadius.xl),
                  child: Column(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          if (!_locationWhenInUsePermissionStatus.isGranted) {
                            _requestPermissionStatus(
                              Permission.locationWhenInUse,
                            );
                          } else {
                            await executeSql(
                              sql:
                                  "UPDATE settings SET value = '${!_locationFeature}' WHERE key = 'location'",
                            );
                            setState(() {
                              _locationFeature = !_locationFeature;
                            });
                          }
                        },
                        child: AppRow(
                          icon:
                              (_locationWhenInUsePermissionStatus.isGranted &&
                                  _locationFeature)
                              ? LucideIcons.mapPin
                              : LucideIcons.mapPinOff,
                          title: local.translate(
                            "settings.sections.privacy.labels.0",
                          ),
                          subtitle: local.translate(
                            "settings.sections.privacy.labels.1",
                          ),
                          trailing: permissionState(
                            scheme,
                            local,
                            Permission.locationWhenInUse,
                            _locationWhenInUsePermissionStatus,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      Stack(
                        children: [
                          AbsorbPointer(
                            absorbing:
                                !_locationWhenInUsePermissionStatus.isGranted,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                if (!_locationAlwaysPermissionStatus
                                    .isGranted) {
                                  _requestPermissionStatus(
                                    Permission.locationAlways,
                                  );
                                } else {
                                  await executeSql(
                                    sql:
                                        "UPDATE settings SET value = '${!_routeFeature}' WHERE key = 'route'",
                                  );
                                  setState(() {
                                    _routeFeature = !_routeFeature;
                                  });
                                }
                              },
                              child: AppRow(
                                icon:
                                    (_locationAlwaysPermissionStatus
                                            .isGranted &&
                                        _routeFeature)
                                    ? LucideIcons.route
                                    : LucideIcons.routeOff,
                                title: local.translate(
                                  "settings.sections.privacy.labels.2",
                                ),
                                subtitle: local.translate(
                                  "settings.sections.privacy.labels.3",
                                ),
                                trailing: permissionState(
                                  scheme,
                                  local,
                                  Permission.locationAlways,
                                  _locationAlwaysPermissionStatus,
                                ),
                              ),
                            ),
                          ),
                          if (_locationWhenInUsePermissionStatus.isGranted ==
                              false)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceBright.withAlpha(155),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          if (!_microphonePermissionStatus.isGranted) {
                            _requestPermissionStatus(Permission.microphone);
                          } else {
                            await executeSql(
                              sql:
                                  "UPDATE settings SET value = '${!_microphoneFeature}' WHERE key = 'microphone'",
                            );
                            setState(() {
                              _microphoneFeature = !_microphoneFeature;
                            });
                          }
                        },
                        child: AppRow(
                          icon:
                              (_microphonePermissionStatus.isGranted &&
                                  _microphoneFeature)
                              ? LucideIcons.mic
                              : LucideIcons.micOff,
                          title: local.translate(
                            "settings.sections.privacy.labels.4",
                          ),
                          subtitle: local.translate(
                            "settings.sections.privacy.labels.5",
                          ),
                          trailing: permissionState(
                            scheme,
                            local,
                            Permission.microphone,
                            _microphonePermissionStatus,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SectionTitle(local.translate("settings.sections.backup.title")),
                AppCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xxs,
                  ),
                  margin: EdgeInsets.only(bottom: AppRadius.xl),
                  child: Column(
                    children: [
                      Pressable(
                        onTap: () async {
                          final packageInfo = await PackageInfo.fromPlatform();

                          Uint8List bytes;
                          try {
                            bytes = await exportBackup(
                              appVersion: packageInfo.version,
                            );
                          } catch (e) {
                            log('Export Error: $e');
                            showToast(
                              scheme: scheme,
                              toast: Text(
                                local.translate("generic_error"),
                                style: AppText.bodySm(scheme),
                                textAlign: TextAlign.center,
                              ),
                              gravity: ToastGravity.BOTTOM,
                              position: (context, child, gravity) {
                                return Positioned(
                                  bottom: 170,
                                  left: 100,
                                  right: 100,
                                  child: child,
                                );
                              },
                            );
                            return;
                          }

                          final destination = await FilePicker.saveFile(
                            dialogTitle: local.translate(
                              "settings.sections.backup.export.2",
                            ),
                            fileName:
                                'StillAlive_Backup_${DateTime.now().toIso8601String()}.zip',
                            type: FileType.custom,
                            allowedExtensions: ['zip'],
                            bytes: bytes,
                          );

                          if (destination == null) return;

                          showToast(
                            scheme: scheme,
                            toast: Text(
                              local.translate(
                                "settings.sections.backup.export.3",
                              ),
                              style: AppText.bodySm(scheme),
                              textAlign: TextAlign.center,
                            ),
                            gravity: ToastGravity.BOTTOM,
                            position: (context, child, gravity) {
                              return Positioned(
                                bottom: 170,
                                left: 60,
                                right: 60,
                                child: child,
                              );
                            },
                            secs: 5,
                          );
                        },
                        child: AppRow(
                          icon: LucideIcons.download,
                          title: local.translate(
                            "settings.sections.backup.export.0",
                          ),
                          subtitle: local.translate(
                            "settings.sections.backup.export.1",
                          ),
                          trailing: chevron,
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      Pressable(
                        onTap: () async {
                          final result = await FilePicker.pickFiles(
                            dialogTitle: local.translate(
                              "settings.sections.backup.import.2",
                            ),
                            type: FileType.custom,
                            allowedExtensions: ['zip'],
                          );

                          if (result == null) return;

                          final packageInfo = await PackageInfo.fromPlatform();

                          try {
                            await importBackup(
                              zipPath: result.files.single.path!,
                              appVersion: packageInfo.version,
                            );
                          } catch (e) {
                            log('Import Error: $e');
                            showToast(
                              scheme: scheme,
                              toast: Text(
                                local.translate("generic_error"),
                                style: AppText.bodySm(scheme),
                                textAlign: TextAlign.center,
                              ),
                              gravity: ToastGravity.BOTTOM,
                              position: (context, child, gravity) {
                                return Positioned(
                                  bottom: 170,
                                  left: 100,
                                  right: 100,
                                  child: child,
                                );
                              },
                            );
                            return;
                          }

                          showToast(
                            scheme: scheme,
                            toast: Text(
                              local.translate(
                                "settings.sections.backup.import.3",
                              ),
                              style: AppText.bodySm(scheme),
                              textAlign: TextAlign.center,
                            ),
                            gravity: ToastGravity.BOTTOM,
                            position: (context, child, gravity) {
                              return Positioned(
                                bottom: 170,
                                left: 60,
                                right: 60,
                                child: child,
                              );
                            },
                            secs: 5,
                          );

                          Future.delayed(AppMotion.slow);
                          Restart.restartApp(mode: RestartMode.process);
                        },
                        child: AppRow(
                          icon: LucideIcons.import,
                          rotateAngle: math.pi / 2,
                          title: local.translate(
                            "settings.sections.backup.import.0",
                          ),
                          subtitle: local.translate(
                            "settings.sections.backup.import.1",
                          ),
                          trailing: chevron,
                        ),
                      ),
                    ],
                  ),
                ),

                SectionTitle(local.translate("settings.sections.danger.title")),
                AppCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xxs,
                  ),
                  margin: EdgeInsets.only(bottom: AppRadius.xl),
                  child: Pressable(
                    onTap: () {
                      showBlurredBottomSheet(
                        context: context,
                        scheme: scheme,
                        marginHorizontal: 50,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              local.translate(
                                "settings.sections.danger.labels.2",
                              ),
                              style: AppText.body(scheme),
                              textAlign: TextAlign.center,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xl,
                                bottom: AppRadius.lg,
                              ),
                              child: PrimaryButton(
                                label: local.translate(
                                  "settings.sections.danger.labels.0",
                                ),
                                color: ButtonColor.warning,
                                onPressed: () async {
                                  try {
                                    await purgeDatabase();
                                  } catch (e) {
                                    log('Purge Error: $e');
                                    showToast(
                                      scheme: scheme,
                                      toast: Text(
                                        local.translate("generic_error"),
                                        style: AppText.bodySm(scheme),
                                        textAlign: TextAlign.center,
                                      ),
                                      gravity: ToastGravity.BOTTOM,
                                      position: (context, child, gravity) {
                                        return Positioned(
                                          bottom: 210,
                                          left: 100,
                                          right: 100,
                                          child: child,
                                        );
                                      },
                                    );
                                    return;
                                  }

                                  final tempDir = await getTemporaryDirectory();
                                  if (tempDir.existsSync()) {
                                    tempDir.deleteSync(recursive: true);
                                  }

                                  final appDir =
                                      await getApplicationDocumentsDirectory();
                                  if (appDir.existsSync()) {
                                    appDir.deleteSync(recursive: true);
                                  }

                                  showToast(
                                    scheme: scheme,
                                    toast: Text(
                                      local.translate(
                                        "settings.sections.danger.labels.3",
                                      ),
                                      style: AppText.bodySm(scheme),
                                      textAlign: TextAlign.center,
                                    ),
                                    gravity: ToastGravity.BOTTOM,
                                    position: (context, child, gravity) {
                                      return Positioned(
                                        bottom: 210,
                                        left: 60,
                                        right: 60,
                                        child: child,
                                      );
                                    },
                                    secs: 5,
                                  );

                                  Future.delayed(AppMotion.slow);
                                  Restart.restartApp(mode: RestartMode.process);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: AppRow(
                      danger: true,
                      icon: LucideIcons.trash2,
                      title: local.translate(
                        "settings.sections.danger.labels.0",
                      ),
                      subtitle: local.translate(
                        "settings.sections.danger.labels.1",
                      ),
                      trailing: Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: scheme.error,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      if (snapshot.data == null) {
                        return Text(
                          local.translate('app_name'),
                          style: AppText.micro(scheme),
                        );
                      } else {
                        return Text(
                          '${local.translate('app_name')} v${snapshot.data!.version} · Build ${snapshot.data!.buildNumber}',
                          style: AppText.micro(scheme),
                        );
                      }
                    },
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
