import 'package:flutter/material.dart';
import '../../widgets/primitives.dart';
import 'package:still_alive/data/app_design.dart';
import 'package:still_alive/data/app_localization.dart';
import 'welcome.dart';
import 'privacy.dart';
import 'permissions.dart';
import '../home.dart';

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
class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _controller;

  int currentPage = 0;

  @override
  void initState() {
    super.initState();

    currentPage = widget.startPage;

    _controller = PageController(
      viewportFraction: 1.1,
      initialPage: widget.startPage,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (currentPage < 2) {
      _controller.nextPage(
        duration: AppMotion.fast,
        curve: AppMotion.emphasized,
      );
    } else {
      // onboarding complete
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => ScreenBase(child: HomeScreen())),
        (route) => false,
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
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
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
            const SizedBox(height: 16),
            ProgressDots(active: currentPage),
          ],
        ),
      ),
    );
  }
}
