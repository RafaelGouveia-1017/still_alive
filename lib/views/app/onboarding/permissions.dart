import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/data/app_design.dart';
import 'package:still_alive/data/app_localization.dart';
import '../../widgets/primitives.dart';

class _Perm {
  const _Perm(this.icon, this.title, this.subtitle, this.granted);
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
}

class _PermBuilder extends StatelessWidget {
  const _PermBuilder({required this.items});

  final List<_Perm> items;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = items[i];
        return AppCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  p.icon,
                  size: 20,
                  color: p.granted ? scheme.tertiary : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: AppText.body(scheme)),
                    Text(p.subtitle, style: AppText.caption(scheme)),
                  ],
                ),
              ),
              if (p.granted)
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: scheme.tertiary.withAlpha(38),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.check,
                    size: 16,
                    color: scheme.tertiary,
                  ),
                )
              else
                GestureDetector(
                  onTap: () => {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: AppRadius.chip,
                    ),
                    child: Text(
                      local.translate("permissions.allow"),
                      style: AppText.caption(
                        scheme,
                      ).copyWith(color: scheme.onPrimary),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class PermissionsContent extends StatelessWidget {
  const PermissionsContent({super.key});

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    _Perm sms = _Perm(
      LucideIcons.messageSquareMore,
      local.translate("permissions.required.items.0.name"),
      local.translate("permissions.required.items.0.detail"),
      true,
    );
    _Perm contacts = _Perm(
      LucideIcons.users,
      local.translate("permissions.required.items.1.name"),
      local.translate("permissions.required.items.1.detail"),
      false,
    );
    _Perm notifs = _Perm(
      LucideIcons.bell,
      local.translate("permissions.required.items.2.name"),
      local.translate("permissions.required.items.2.detail"),
      false,
    );
    _Perm location = _Perm(
      LucideIcons.mapPin,
      local.translate("permissions.optional.items.0.name"),
      local.translate("permissions.optional.items.0.detail"),
      true,
    );

    List<_Perm> required = [sms, contacts, notifs];
    List<_Perm> optional = [location];

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.keySquare, size: 16, color: scheme.tertiary),
              const SizedBox(width: 8),
              Text(
                local.translate("permissions.title").toUpperCase(),
                style: AppText.pillLabel.copyWith(
                  color: scheme.tertiary,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            local.translate("permissions.description"),
            style: AppText.h2(scheme),
          ),
          const SizedBox(height: 20),
          SectionTitle(local.translate("permissions.required.title")),
          _PermBuilder(items: required),
          const SizedBox(height: 20),
          SectionTitle(local.translate("permissions.optional.title")),
          _PermBuilder(items: optional),
        ],
      ),
    );
  }
}
