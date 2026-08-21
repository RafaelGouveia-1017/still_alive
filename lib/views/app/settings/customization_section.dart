import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Displays the customization section of the settings screen.
///
/// Provides controls for changing the application's theme and language, while
/// reflecting the currently selected options.
class CustomizationSection extends StatefulWidget {
  final ColorScheme scheme;
  final AppLocalizations local;
  final LocaleProvider localeProvider;
  final VoidCallback onThemePress;
  final VoidCallback onLanguagePress;

  const CustomizationSection({
    super.key,
    required this.scheme,
    required this.local,
    required this.localeProvider,
    required this.onThemePress,
    required this.onLanguagePress,
  });

  @override
  State<CustomizationSection> createState() => _CustomizationSectionState();
}

/// State implementation for [CustomizationSection].
class _CustomizationSectionState extends State<CustomizationSection> {
  @override
  Widget build(BuildContext context) {
    final currentLanguage = AppLocalizationsDelegate.supportedLocales
        .firstWhere(
          (l) => l.locale == widget.localeProvider.locale,
          orElse: () => AppLocalizationsDelegate.supportedLocales.first,
        );

    final chevron = Icon(
      LucideIcons.chevronRight,
      size: 18,
      color: widget.scheme.onSurfaceVariant,
    );

    return Column(
      children: [
        SectionTitle(
          widget.local.translate("settings.sections.customization.title"),
        ),
        AppCard(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xxs,
          ),
          margin: EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            children: [
              Pressable(
                onTap: widget.onThemePress,
                child: FutureBuilder<String>(
                  future: CustomTheme.load(),
                  builder: (context, snapshot) {
                    return AppRow(
                      icon: LucideIcons.palette,
                      title: widget.local.translate(
                        "settings.sections.customization.labels.0",
                      ),
                      subtitle:
                          "${widget.local.translate("settings.sections.customization.labels.1")} ${snapshot.data}",
                      trailing: chevron,
                    );
                  },
                ),
              ),
              Divider(height: 1, color: widget.scheme.outlineVariant),
              Pressable(
                onTap: widget.onLanguagePress,
                child: AppRow(
                  icon: LucideIcons.languages,
                  title: widget.local.translate(
                    "settings.sections.customization.labels.2",
                  ),
                  subtitle:
                      "${widget.local.translate("settings.sections.customization.labels.1")} ${currentLanguage.label}",
                  trailing: chevron,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
