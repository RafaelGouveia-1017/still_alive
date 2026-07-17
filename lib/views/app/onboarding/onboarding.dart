import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:still_alive/data/all.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import '../../widgets/primitives.dart';
import 'welcome.dart';
import 'privacy.dart';
import 'permissions.dart';
import '../home/home.dart';

/// Root onboarding flow that guides users through the initial
/// application setup experience.
///
/// Displays a paged sequence consisting of:
/// * Welcome and customization options
/// * Privacy information
/// * Permission requests
///
/// When the final page is completed, the user is navigated
/// to the main application and the onboarding route stack
/// is cleared.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.startPage = 0});

  final int startPage;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// State implementation for [OnboardingScreen].
///
/// Manages page navigation, onboarding progress,
/// swipe gestures, and completion of the onboarding flow.
class _OnboardingScreenState extends State<OnboardingScreen> with RouteAware {
  late final PageController _controller;
  final tracker = PermissionRouteTracker.instance;

  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    currentPage = widget.startPage;

    _controller = PageController(
      viewportFraction: 1.1,
      initialPage: widget.startPage,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    tracker.subscribe(context);
  }

  @override
  void dispose() {
    tracker.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  void _nextPage() async {
    if (currentPage < 2) {
      _controller.nextPage(
        duration: AppMotion.fast,
        curve: AppMotion.emphasized,
      );
    } else {
      ColorScheme scheme = Theme.of(context).colorScheme;
      AppLocalizations local = AppLocalizations.of(context)!;

      if (await PermissionManager.instance.hasAllNeededPermissions()) {
        try {
          int result = (await executeSql(
            sql: "UPDATE settings SET value = 'false' WHERE key = 'tutorial'",
          )).toInt();

          if (!mounted) return;

          if (result >= 1) {
            Navigator.pushAndRemoveUntil(
              context,
              AppRoute(
                page: HomeScreen(),
                transition: AppRouteTransitionType.slideRight,
              ),
              (route) => false,
            );
            return;
          } else {
            throw Exception("SQL didn't work somehow.");
          }
        } catch (e) {
          showToast(
            scheme: scheme,
            toast: Text(
              e.toString(),
              style: AppText.bodySm(scheme),
              textAlign: TextAlign.center,
            ),
            secs: 10,
          );
          return;
        }
      }

      if (!mounted) return;

      showToast(
        scheme: scheme,
        toast: Text(
          local.translate("permissions.error"),
          style: AppText.bodySm(scheme),
          textAlign: TextAlign.center,
        ),
        gravity: ToastGravity.BOTTOM,
        position: (context, child, gravity) {
          return Positioned(bottom: 170, left: 30, right: 30, child: child);
        },
      );
    }
  }

  void _previousPage() {
    if (currentPage > 0) {
      _controller.previousPage(
        duration: AppMotion.fast,
        curve: AppMotion.emphasized,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations local = AppLocalizations.of(context)!;

    List<String> buttonLabels = [
      local.translate("welcome.cta"),
      local.translate("privacy.cta"),
      local.translate("permissions.cta"),
    ];

    return ScreenBase(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          0,
          AppSpacing.xxxxl,
          0,
          AppSpacing.xxxxl,
        ),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  // swipe left → next
                  if (details.primaryVelocity! < 0 && currentPage < 2) {
                    _nextPage();
                  }

                  // swipe right → previous
                  if (details.primaryVelocity! > 0) {
                    _previousPage();
                  }
                },
                child: PageView(
                  controller: _controller,
                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },
                  children: const [
                    WelcomePage(),
                    PrivacyPage(),
                    PermissionsPage(),
                  ],
                ),
              ),
            ),

            PrimaryButton(
              label: buttonLabels[currentPage],
              onPressed: _nextPage,
            ),
            const SizedBox(height: AppSpacing.lg),
            ProgressDots(active: currentPage),
          ],
        ),
      ),
    );
  }
}
