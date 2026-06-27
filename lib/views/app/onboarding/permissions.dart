import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:still_alive/data/app_design.dart';
import 'package:still_alive/data/app_localization.dart';
import 'package:still_alive/data/app_permissions.dart';
import '../../widgets/primitives.dart';

/// Immutable model representing a single application permission.
///
/// Stores the permission icon, localized title,
/// descriptive text, and type of permission.
class _Perm {
  const _Perm(this.icon, this.title, this.subtitle, this.permission);
  final IconData icon;
  final String title;
  final String subtitle;
  final Permission permission;
}

class _PermBuilder extends StatefulWidget {
  const _PermBuilder({required this.item});

  final _Perm item;

  @override
  State<_PermBuilder> createState() => _PermBuilderState();
}

/// State implementation for [_PermBuilder].
class _PermBuilderState extends State<_PermBuilder>
    with WidgetsBindingObserver {
  _PermBuilderState();

  PermissionStatus _permissionStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPermissionStatus();
  }

  void _currentPermissionStatus() async {
    final status = await widget.item.permission.status;
    if (!mounted) return;
    setState(() => _permissionStatus = status);
  }

  void _requestStatus() async {
    final status = await PermissionManager.instance.requestPermission(
      widget.item.permission,
    );
    if (!mounted) return;
    setState(() => _permissionStatus = status);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _currentPermissionStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

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
              widget.item.icon,
              size: 20,
              color: switch (_permissionStatus) {
                PermissionStatus.granted => scheme.tertiary,
                _ => scheme.onSurface,
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item.title, style: AppText.body(scheme)),
                Text(widget.item.subtitle, style: AppText.caption(scheme)),
              ],
            ),
          ),
          if (_permissionStatus.isGranted)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: scheme.tertiary.withAlpha(38),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.check, size: 16, color: scheme.tertiary),
            )
          else
            GestureDetector(
              onTap: () => _requestStatus(),
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
                  switch (_permissionStatus) {
                    PermissionStatus.denied => local.translate(
                      "permissions.allow",
                    ),
                    _ => local.translate("settings.title"),
                  },
                  style: AppText.caption(
                    scheme,
                  ).copyWith(color: scheme.onPrimary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Onboarding page that explains and requests application permissions.
///
/// Permissions are grouped into required and optional categories
/// to help users understand which capabilities are needed for
/// core functionality and which features are optional enhancements.
class PermissionsPage extends StatelessWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    _Perm sms = _Perm(
      LucideIcons.messageSquareMore,
      local.translate("permissions.required.items.0.name"),
      local.translate("permissions.required.items.0.detail"),
      Permission.sms,
    );
    _Perm contacts = _Perm(
      LucideIcons.users,
      local.translate("permissions.required.items.1.name"),
      local.translate("permissions.required.items.1.detail"),
      Permission.contacts,
    );
    _Perm notifs = _Perm(
      LucideIcons.bell,
      local.translate("permissions.required.items.2.name"),
      local.translate("permissions.required.items.2.detail"),
      Permission.notification,
    );
    _Perm location = _Perm(
      LucideIcons.mapPin,
      local.translate("permissions.optional.items.0.name"),
      local.translate("permissions.optional.items.0.detail"),
      Permission.locationWhenInUse,
    );
    _Perm route = _Perm(
      LucideIcons.route,
      local.translate("permissions.optional.items.1.name"),
      local.translate("permissions.optional.items.1.detail"),
      Permission.locationAlways,
    );
    _Perm mic = _Perm(
      LucideIcons.mic,
      local.translate("permissions.optional.items.2.name"),
      local.translate("permissions.optional.items.2.detail"),
      Permission.microphone,
    );

    List<_Perm> required = [sms, contacts, notifs];
    List<_Perm> optional = [location, route, mic];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
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
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  SectionTitle(local.translate("permissions.required.title")),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: required.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _PermBuilder(item: required[i]),
                  ),

                  const SizedBox(height: 20),
                  SectionTitle(local.translate("permissions.optional.title")),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: optional.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _PermBuilder(item: optional[i]),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
