import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/data/app_design.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primary, scheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    boxShadow: AppShadows.boxShadow(scheme.primary),
                  ),
                  child: Icon(
                    LucideIcons.shield,
                    size: 48,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "Home Screen: Under construction",
                  style: AppText.body(scheme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
