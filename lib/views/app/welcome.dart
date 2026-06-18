// StillAlive — 01 · Welcome (Flutter)
// Mirrors WelcomeScreen in `src/app/components/screens/Onboarding.tsx`.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/data/app_design.dart';
import 'package:still_alive/data/app_localization.dart';
import 'package:still_alive/data/custom_theme.dart';
import 'package:still_alive/views/theme_page.dart';
import '../widgets/primitives.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.onGetStarted});

  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;
    LocaleProvider localeProvider = Provider.of<LocaleProvider>(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
        child: Column(
          children: [
            Expanded(
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
                    child: Icon(
                      LucideIcons.shield,
                      size: 48,
                      color: scheme.onPrimary,
                    ),
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
                  SizedBox(
                    child: Column(
                      children: [
                        SectionTitle(
                          local.translate(
                            "settings.sections.customization.title",
                          ),
                        ),
                        GestureDetector(
                          onTap: () => {
                            Navigator.of(context).push(
                              AppRoute(
                                page: ThemePage(),
                                transition: AppRouteTransitionType.slideRight,
                              ),
                            ),
                          },
                          child: AppCard(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Column(
                              children: [
                                FutureBuilder<String>(
                                  future: CustomTheme.load(),
                                  builder: (context, snapshot) {
                                    return AppRow(
                                      icon: LucideIcons.palette,
                                      title: local.translate(
                                        "settings.sections.customization.labels.0",
                                      ),
                                      subtitle:
                                          "${local.translate("settings.sections.customization.labels.1")} ${snapshot.data!}",
                                      trailing: Icon(LucideIcons.chevronRight),
                                    );
                                  },
                                ),
                                Divider(
                                  height: 1,
                                  color: scheme.outlineVariant,
                                ),
                                AppRow(
                                  icon: LucideIcons.languages,
                                  title: local.translate(
                                    "settings.sections.customization.labels.2",
                                  ),
                                  trailing: DropdownButton<Locale>(
                                    style: AppText.caption(scheme),
                                    isDense: true,
                                    dropdownColor:
                                        scheme.surfaceContainerHighest,
                                    value: localeProvider.locale,
                                    items: const [
                                      DropdownMenuItem(
                                        value: Locale('en'),
                                        child: Text("English"),
                                      ),
                                      DropdownMenuItem(
                                        value: Locale('pt'),
                                        child: Text("Português"),
                                      ),
                                    ],
                                    onChanged: (locale) {
                                      localeProvider.setLocale(locale!);
                                    },
                                  ),
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
            ),
            PrimaryButton(
              label: local.translate("welcome.cta"),
              onPressed: onGetStarted,
            ),
            const SizedBox(height: 16),
            const ProgressDots(active: 0),
          ],
        ),
      ),
    );
  }
}
