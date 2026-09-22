import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Displays the danger section of the settings screen.
///
/// Provides access to irreversible maintenance actions, such as permanently
/// deleting all application data.
class DangerSection extends StatefulWidget {
  final ColorScheme scheme;
  final AppLocalizations local;
  final VoidCallback onPurge;

  const DangerSection({super.key, required this.scheme, required this.local, required this.onPurge});

  @override
  State<DangerSection> createState() => _DangerSectionState();
}

/// State implementation for [DangerSection].
class _DangerSectionState extends State<DangerSection> {
  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SectionTitle(widget.local.translate("settings.sections.danger.title")),
        AppCard(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxs),
          margin: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Pressable(
            onTap: () {
              showBlurredBottomSheet(
                context: context,
                scheme: widget.scheme,
                marginHorizontal: 50,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.local.translate("settings.sections.danger.labels.2"),
                      style: AppText.body(widget.scheme),
                      textAlign: TextAlign.center,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.lg),
                      child: PrimaryButton(
                        label: widget.local.translate("settings.sections.danger.labels.0"),
                        color: ButtonColor.warning,
                        onPressed: widget.onPurge,
                      ),
                    ),
                  ],
                ),
              );
            },
            child: AppRow(
              icon: LucideIcons.trash2,
              iconColor: scheme.error,
              iconBackground: scheme.error.withAlpha(31),
              title: widget.local.translate("settings.sections.danger.labels.0"),
              subtitle: widget.local.translate("settings.sections.danger.labels.1"),
              trailing: Icon(LucideIcons.chevronRight, size: 18, color: widget.scheme.error),
            ),
          ),
        ),
      ],
    );
  }
}
