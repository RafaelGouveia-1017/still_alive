import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:still_alive/data/app_design.dart';
import 'package:still_alive/data/app_localization.dart';
import 'package:still_alive/data/app_permissions.dart';
import '../../widgets/primitives.dart';

/// A [_Perm] encapsulates all presentation data required to render a
/// permission entry within [PermissionsPage], including:
///
/// * the icon displayed to the user;
/// * the localized permission name;
/// * a short description explaining why the permission is needed; and
/// * the underlying [Permission] from `permission_handler`.
class _Perm {
  const _Perm(this.icon, this.title, this.subtitle, this.permission);
  final IconData icon;
  final String title;
  final String subtitle;
  final Permission permission;
}

/// Displays and manages the UI for requesting a single application permission.
///
/// This widget observes the current permission state, updates automatically
/// when the application returns to the foreground, and allows the user to
/// request the permission by tapping the card.
///
/// For the background location permission ([Permission.locationAlways]),
/// the widget requires the foreground location permission to be granted
/// first and temporarily disables interaction until that prerequisite
/// has been satisfied.
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
  bool _locationWhenInUsePermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPermissionStatus();
  }

  void _currentPermissionStatus() async {
    bool granted = false;
    if (widget.item.permission == Permission.locationAlways) {
      granted = await Permission.locationWhenInUse.isGranted;
    }

    final status = await widget.item.permission.status;
    if (!mounted) return;
    setState(() {
      _permissionStatus = status;
      _locationWhenInUsePermissionGranted = granted;
    });
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

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: (widget.item.permission == Permission.locationAlways)
              ? !_locationWhenInUsePermissionGranted
              : false,
          child: Pressable(
            onTap: () {
              if (!_permissionStatus.isGranted) _requestStatus();
            },
            child: AppCard(
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
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item.title, style: AppText.body(scheme)),
                        Text(
                          widget.item.subtitle,
                          style: AppText.caption(scheme),
                        ),
                      ],
                    ),
                  ),
                  if (_permissionStatus.isGranted)
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
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
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
                ],
              ),
            ),
          ),
        ),
        if (widget.item.permission == Permission.locationAlways &&
            _locationWhenInUsePermissionGranted == false)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceBright.withAlpha(155),
                borderRadius: AppRadius.card,
              ),
            ),
          ),
      ],
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
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.keySquare, size: 16, color: scheme.tertiary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                local.translate("permissions.title").toUpperCase(),
                style: AppText.pillLabel.copyWith(
                  color: scheme.tertiary,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            local.translate("permissions.description"),
            style: AppText.h2(scheme),
          ),
          const SizedBox(height: AppSpacing.ms),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.ms),
                  SectionTitle(local.translate("permissions.required.title")),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: required.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.ms),
                    itemBuilder: (context, i) =>
                        _PermBuilder(item: required[i]),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  SectionTitle(local.translate("permissions.optional.title")),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: optional.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.ms),
                    itemBuilder: (context, i) =>
                        _PermBuilder(item: optional[i]),
                  ),
                  const SizedBox(height: AppSpacing.ms),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.ms),
        ],
      ),
    );
  }
}
