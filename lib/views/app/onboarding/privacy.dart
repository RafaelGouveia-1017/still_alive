import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/data/app_design.dart';
import 'package:still_alive/data/app_localization.dart';
import '../../widgets/primitives.dart';

/// Onboarding page that summarizes the application's privacy principles.
///
/// Presents key privacy commitments in a concise, easy-to-read format,
/// helping users understand how their data is handled before they
/// continue using the application.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    List<(String, String)> points = [
      (local.translate("privacy.items.0"), local.translate("privacy.items.1")),
      (local.translate("privacy.items.2"), local.translate("privacy.items.3")),
      (local.translate("privacy.items.4"), local.translate("privacy.items.5")),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.lock, size: 16, color: scheme.tertiary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                local.translate("privacy.subtitle").toUpperCase(),
                style: AppText.pillLabel.copyWith(
                  color: scheme.tertiary,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            local.translate("privacy.description"),
            style: AppText.h2(scheme),
          ),
          const SizedBox(height: AppSpacing.xxxxl),
          for (final p in points) ...[
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(top: AppSpacing.xxxs),
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withAlpha(38),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.check,
                      size: 16,
                      color: scheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.$1, style: AppText.body(scheme)),
                        const SizedBox(height: AppSpacing.xxxs),
                        Text(p.$2, style: AppText.caption(scheme)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
