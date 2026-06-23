import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/data/app_design.dart';
import 'package:still_alive/data/app_localization.dart';
import 'package:still_alive/data/custom_theme.dart';
import '../../widgets/primitives.dart';
import '../themes.dart';

/// Initial onboarding page introducing the application.
///
/// Displays branding, a short description of the app,
/// and quick access to personalization settings such as
/// theme selection and language preferences before the
/// user proceeds through the onboarding flow.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.secondary],
              ),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              boxShadow: AppShadows.boxShadow(scheme.primary),
            ),
            child: Icon(LucideIcons.shield, size: 48, color: scheme.onPrimary),
          ),
          const SizedBox(height: 32),
          Text(local.translate("app_name"), style: AppText.h1(scheme)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              local.translate("welcome.tagline"),
              textAlign: TextAlign.center,
              style: AppText.body(
                scheme.copyWith(onSurface: scheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            child: Column(
              children: [
                SectionTitle(
                  local.translate("settings.sections.customization.title"),
                ),
                AppCard(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).push(
                          AppRoute(
                            page: ThemesScreen(tutorial: false),
                            transition: AppRouteTransitionType.slideRight,
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
                              trailing: Icon(
                                LucideIcons.chevronRight,
                                size: 18,
                              ),
                            );
                          },
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
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

                                return ListTile(
                                  splashColor: null,
                                  tileColor: null,
                                  title: Text(
                                    lang.label,
                                    style: AppText.body(scheme),
                                  ),
                                  onTap: () {
                                    localeProvider.setLocale(lang.locale);
                                    Navigator.pop(context);
                                  },
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
                          trailing: Icon(LucideIcons.chevronRight, size: 18),
                        ),
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
