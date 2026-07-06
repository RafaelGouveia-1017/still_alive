import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Displays the backup section of the settings screen.
///
/// Provides actions for exporting the application's data to a backup archive
/// and restoring data from a previously created backup.
class BackupSection extends StatefulWidget {
  final ColorScheme scheme;
  final AppLocalizations local;
  final VoidCallback onExport;
  final VoidCallback onImport;

  const BackupSection({
    super.key,
    required this.scheme,
    required this.local,
    required this.onExport,
    required this.onImport,
  });

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

/// State implementation for [BackupSection].
class _BackupSectionState extends State<BackupSection> {
  @override
  Widget build(BuildContext context) {
    final chevron = Icon(
      LucideIcons.chevronRight,
      size: 18,
      color: widget.scheme.onSurfaceVariant,
    );

    return Column(
      children: [
        SectionTitle(widget.local.translate("settings.sections.backup.title")),
        AppCard(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xxs,
          ),
          margin: EdgeInsets.only(bottom: AppRadius.xl),
          child: Column(
            children: [
              Pressable(
                onTap: widget.onExport,
                child: AppRow(
                  icon: LucideIcons.download,
                  title: widget.local.translate(
                    "settings.sections.backup.export.0",
                  ),
                  subtitle: widget.local.translate(
                    "settings.sections.backup.export.1",
                  ),
                  trailing: chevron,
                ),
              ),
              Divider(height: 1, color: widget.scheme.outlineVariant),
              Pressable(
                onTap: widget.onImport,
                child: AppRow(
                  icon: LucideIcons.import,
                  rotateAngle: math.pi / 2,
                  title: widget.local.translate(
                    "settings.sections.backup.import.0",
                  ),
                  subtitle: widget.local.translate(
                    "settings.sections.backup.import.1",
                  ),
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
