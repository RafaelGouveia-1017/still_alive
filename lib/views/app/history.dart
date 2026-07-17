import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/app_design.dart';
import '../widgets/primitives.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

/// State implementation for [HistoryScreen].
class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    return ScreenBase(
      bottomNavDestination: 'history',
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
              const SizedBox(height: AppSpacing.xxxxl),
              Text(
                "History Screen: Under construction",
                style: AppText.body(scheme),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
