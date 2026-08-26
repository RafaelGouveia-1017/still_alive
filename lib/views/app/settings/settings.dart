import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:restart_app/restart_app.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../src/rust/api/data/db.dart';
import '../../../src/rust/api/backup.dart';

import '../../../main.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';
import 'themes.dart';
import 'customization_section.dart';
import 'alerts_section.dart';
import 'privacy_section.dart';
import 'backup_section.dart';
import 'danger_section.dart';

/// Displays the application's settings screen.
///
/// This screen serves as the central hub for configuring the application,
/// including appearance, localization, privacy, alerts, backup management,
/// and destructive maintenance actions.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// State implementation for [SettingsScreen].
///
/// Manages the current settings state, synchronizes feature preferences with
/// the local database, monitors permission changes, and coordinates user
/// interactions across each settings section.
class _SettingsScreenState extends State<SettingsScreen> with RouteAware {
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

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _permissionsStatuses();
    _featureStatuses();

    _lifecycleListener = AppLifecycleListener(
      onResume: () => _permissionsStatuses(),
    );
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
    _permissionsStatuses();
    super.didPopNext();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    routeObserver.unsubscribe(this);
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;
    LocaleProvider localeProvider = Provider.of<LocaleProvider>(context);

    return ScreenBase(
      bottomNavDestination: 'settings',
      header: AppHeader(title: local.translate('settings.title')),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppSpacing.lg,
                0,
                AppSpacing.lg,
              ),
              children: [
                // Customization Section
                CustomizationSection(
                  scheme: scheme,
                  local: local,
                  localeProvider: localeProvider,
                  onThemePress: () => Navigator.of(context).push(
                    AppRoute(
                      page: ThemesScreen(),
                      transition: AppRouteTransitionType.slideLeft,
                    ),
                  ),
                  onLanguagePress: () {
                    showBlurredBottomSheet(
                      scheme: scheme,
                      context: context,
                      marginHorizontal: 75,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount:
                            AppLocalizationsDelegate.supportedLocales.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1, color: scheme.outlineVariant),
                        itemBuilder: (context, index) {
                          final lang =
                              AppLocalizationsDelegate.supportedLocales[index];

                          return Pressable(
                            factory: InkSparkle.splashFactory,
                            onTap: () {
                              localeProvider.setLocale(lang.locale);
                              Navigator.pop(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
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
                ),

                // Alerts Section
                AlertsSection(
                  scheme: scheme,
                  local: local,
                  messageFeature: _messageFeature,
                  volumeFeature: _volumeFeature,
                  lockFeature: _lockFeature,
                  onMessageUpdate: (String value) {
                    setState(() {
                      _messageFeature = value;
                    });
                  },
                  onVolumeUpdate: (int value) {
                    setState(() {
                      _volumeFeature = value;
                    });
                  },
                  onLockUpdate: (bool value) {
                    setState(() {
                      _lockFeature = value;
                    });
                  },
                ),

                // Privacy Section
                PrivacySection(
                  scheme: scheme,
                  local: local,
                  locationFeature: _locationFeature,
                  routeFeature: _routeFeature,
                  microphoneFeature: _microphoneFeature,
                  locationWhenInUsePermissionStatus:
                      _locationWhenInUsePermissionStatus,
                  locationAlwaysPermissionStatus:
                      _locationAlwaysPermissionStatus,
                  microphonePermissionStatus: _microphonePermissionStatus,
                  onRequestPermission: _requestPermissionStatus,
                  onLocationUpdate: (bool value) {
                    setState(() {
                      _locationFeature = value;
                    });
                  },
                  onRouteUpdate: (bool value) {
                    setState(() {
                      _routeFeature = value;
                    });
                  },
                  onMicrophoneUpdate: (bool value) {
                    setState(() {
                      _microphoneFeature = value;
                    });
                  },
                ),

                // Backup Section
                BackupSection(
                  scheme: scheme,
                  local: local,
                  onExport: () async {
                    final packageInfo = await PackageInfo.fromPlatform();

                    Uint8List bytes;
                    try {
                      bytes = await exportBackup(
                        appVersion: packageInfo.version,
                      );
                    } catch (e, st) {
                      AppLogger.log.warning('Export Error', e, st);
                      if (context.mounted) {
                        showGenericErrorMessage(context, null);
                      }
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
                        local.translate("settings.sections.backup.export.3"),
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
                  onImport: () async {
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
                    } catch (e, st) {
                      AppLogger.log.warning('Import Error', e, st);
                      if (context.mounted) {
                        showGenericErrorMessage(context, null);
                      }
                      return;
                    }

                    showToast(
                      scheme: scheme,
                      toast: Text(
                        local.translate("settings.sections.backup.import.3"),
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
                ),

                // Danger Section
                DangerSection(
                  scheme: scheme,
                  local: local,
                  onPurge: () async {
                    try {
                      await purgeDatabase();
                    } catch (e, st) {
                      AppLogger.log.severe('Purge Error', e, st);
                      if (context.mounted) {
                        showGenericErrorMessage(context, null);
                      }
                      return;
                    }

                    final tempDir = await getTemporaryDirectory();
                    if (tempDir.existsSync()) {
                      tempDir.deleteSync(recursive: true);
                    }

                    final appDir = await getApplicationDocumentsDirectory();
                    if (appDir.existsSync()) {
                      appDir.deleteSync(recursive: true);
                    }

                    showToast(
                      scheme: scheme,
                      toast: Text(
                        local.translate("settings.sections.danger.labels.3"),
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

                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => launchUrl(
                    Uri.parse("https://buymeacoffee.com/rafaelgouveia"),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FutureBuilder<PackageInfo>(
                              future: PackageInfo.fromPlatform(),
                              builder: (context, snapshot) {
                                if (snapshot.data == null) {
                                  return Text(
                                    local.translate('app_name'),
                                    style: AppText.micro(scheme),
                                  );
                                } else {
                                  return Text(
                                    '${local.translate('app_name')} v${snapshot.data!.version} • Build ${snapshot.data!.buildNumber}',
                                    style: AppText.micro(scheme),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              local.translate("settings.footer"),
                              style: AppText.micro(scheme),
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Image.asset(
                              "lib/assets/bmc-logo.png",
                              height: 20,
                              filterQuality: FilterQuality.high,
                            ),
                          ],
                        ),
                      ],
                    ),
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
