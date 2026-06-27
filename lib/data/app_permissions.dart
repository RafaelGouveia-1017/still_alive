import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_design.dart';
import '../views/app/onboarding/onboarding.dart';
import '../main.dart';

/// Tracks navigation state related to permission-related routes.
///
/// This class uses [RouteAware] to monitor when permission or onboarding
/// screens become active or inactive. It helps prevent redundant navigation
/// to permission flows when the user is already interacting with them.
class PermissionRouteTracker with RouteAware {
  static final PermissionRouteTracker instance = PermissionRouteTracker();

  bool isPermissionScreenActive = false;

  void subscribe(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  void unsubscribe() {
    routeObserver.unsubscribe(this);
  }

  @override
  void didPush() {
    isPermissionScreenActive = true;
  }

  @override
  void didPopNext() {
    isPermissionScreenActive = true;
  }

  @override
  void didPushNext() {
    isPermissionScreenActive = false;
  }

  @override
  void didPop() {
    isPermissionScreenActive = false;
  }
}

/// Centralized manager for handling application permissions.
///
/// Provides utilities to request permissions, check overall permission
/// status, and navigate the user to onboarding or permission flows when
/// required permissions are missing.
class PermissionManager {
  static final instance = PermissionManager();

  final navigatorKey = GlobalKey<NavigatorState>();

  /// Requests a specific [permission] from the user.
  ///
  /// * If the permission is permanently denied, the system settings page
  ///   is opened and the current status is returned.
  /// * Otherwise, a standard permission request dialog is shown.
  ///
  /// Returns the updated [PermissionStatus] after the operation.
  Future<PermissionStatus> requestPermission(Permission permission) async {
    var status = await permission.status;

    switch (status) {
      case PermissionStatus.permanentlyDenied:
        openAppSettings();
        return await permission.status;
      default:
        return await permission.request();
    }
  }

  /// Checks whether all required application permissions are granted.
  ///
  /// Returns `true` if all required permissions are granted,
  /// otherwise returns `false`.
  Future<bool> hasAllNeededPermissions() async {
    return await Permission.contacts.isGranted &&
        await Permission.sms.isGranted &&
        await Permission.notification.isGranted;
  }

  /// Verifies that required permissions are granted and redirects
  /// the user to onboarding if they are missing.
  ///
  /// Behavior:
  /// * If all required permissions are granted, no action is taken.
  /// * If the permission onboarding screen is already active,
  ///   no navigation occurs.
  /// * Otherwise, navigates to the onboarding flow and clears
  ///   the navigation stack.
  ///
  /// This helps ensure users cannot continue using the app
  /// without granting required permissions.
  Future<void> verifyPermissions() async {
    if (await hasAllNeededPermissions()) return;

    if (PermissionRouteTracker.instance.isPermissionScreenActive) return;

    navigatorKey.currentState?.pushAndRemoveUntil(
      AppRoute(
        page: OnboardingScreen(startPage: 2),
        transition: AppRouteTransitionType.fade,
      ),
      (route) => false,
    );
  }
}

/// Observes application lifecycle changes to re-check permission state.
///
/// When the app returns to the foreground, it triggers a permission
/// validation check to ensure required permissions are still granted.
class PermissionObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await PermissionManager.instance.verifyPermissions();
    }
  }
}
