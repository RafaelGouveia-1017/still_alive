import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
/*
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../src/rust/api/data/db.dart';
*/
import '../../../data/all.dart';
import '../../widgets/primitives.dart';
import 'themes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// State implementation for [SettingsScreen].
class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
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
                  margin: EdgeInsets.only(bottom: AppRadius.lg),
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
                /*
                SectionTitle('Alerts'),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Column(
                    children: [
                      AppRow(
                        icon: Icons.message_outlined,
                        title: 'Custom emergency message',
                        subtitle: 'Edit the text contacts receive',
                        trailing: chevron,
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      AppRow(
                        icon: Icons.notifications_outlined,
                        title: 'Pre-alert warnings',
                        subtitle: 'Vibrate + sound at expiry',
                        trailing: AppToggle(on: true),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      AppRow(
                        icon: Icons.volume_up_outlined,
                        title: 'Offline siren volume',
                        subtitle: 'Maximum',
                        trailing: chevron,
                      ),
                    ],
                  ),
                ),
                SectionTitle('Privacy & Location'),
                AppCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Column(
                    children: [
                      AppRow(
                        icon: Icons.place_outlined,
                        title: 'Share live location',
                        subtitle: 'During active emergency',
                        trailing: AppToggle(on: true),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      AppRow(
                        icon: Icons.volume_up_outlined,
                        title: 'Auto audio recording',
                        subtitle: '60s after trigger',
                        trailing: AppToggle(on: false),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      AppRow(
                        icon: Icons.lock_outline,
                        title: 'App lock',
                        subtitle: 'Face ID + PIN',
                        trailing: AppToggle(on: true),
                      ),
                    ],
                  ),
                ),
                SectionTitle('Backup'),
                AppCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Column(
                    children: [
                      AppRow(
                        icon: Icons.download,
                        title: 'Export data',
                        subtitle: 'Events, contacts, settings',
                        trailing: chevron,
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      AppRow(
                        icon: Icons.smartphone,
                        title: 'Sync across devices',
                        subtitle: 'Encrypted iCloud backup',
                        trailing: AppToggle(on: true),
                      ),
                    ],
                  ),
                ),
                SectionTitle('Danger zone'),
                GestureDetector(
                  onTap: () {
                    showBlurredBottomSheet(
                      context: context,
                      scheme: scheme,
                      child: Column(
                        children: [
                          Text(
                            "Are you sure? All your data will be PERMENANTLY deleted.",
                            style: AppText.body(scheme),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 50),
                            child: GestureDetector(
                              onTap: () {
                                purgeDatabase().then(
                                  (result) => showToast(
                                    scheme: scheme,
                                    toast: Text(
                                      local.translate("permissions.error"),
                                      style: AppText.bodySm(scheme),
                                      textAlign: TextAlign.center,
                                    ),
                                    gravity: ToastGravity.BOTTOM,
                                    position: (context, child, gravity) {
                                      return Positioned(
                                        bottom: 170,
                                        left: 30,
                                        right: 30,
                                        child: child,
                                      );
                                    },
                                  ),
                                );
                              },
                              child: PrimaryButton(
                                label: 'Delete ALL data',
                                color: ButtonColor.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: AppCard(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xxs,
                    ),
                    child: AppRow(
                      danger: true,
                      icon: Icons.delete_outline,
                      title: 'Delete all data',
                      subtitle: 'Cannot be undone',
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: scheme.error,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.xl),
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
                */
              ],
            ),
          ),
        ],
      ),
    );
  }
}
