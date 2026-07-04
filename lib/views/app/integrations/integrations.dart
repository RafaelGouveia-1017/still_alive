import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../data/app_design.dart';
import '../../widgets/primitives.dart';

class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

/// State implementation for [IntegrationsScreen].
class _IntegrationsScreenState extends State<IntegrationsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    return ScreenBase(
      bottomNavDestination: 'integrations',
      child: Row(
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
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                "Integrations Screen: Under construction",
                style: AppText.body(scheme),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
