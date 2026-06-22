import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/primitives.dart';
import 'package:still_alive/data/app_design.dart';
import 'package:still_alive/data/app_localization.dart';
import 'welcome.dart';
import 'privacy.dart';
import 'permissions.dart';
import '../home.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController(viewportFraction: 1.1);

  int currentPage = 0;

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
        MaterialPageRoute(builder: (_) => HomeScreen()),
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
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    SystemChrome.setEnabledSystemUIMode(.edgeToEdge);

    List<String> buttonLabels = [
      local.translate("welcome.cta"),
      local.translate("privacy.cta"),
      local.translate("permissions.cta"),
    ];

    return SafeArea(
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
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
                      WelcomeContent(),
                      PrivacyContent(),
                      PermissionsContent(),
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
      ),
    );
  }
}
