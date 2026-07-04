import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../data/app_design.dart';
import '../../widgets/primitives.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

/// State implementation for [ContactsScreen].
class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    return ScreenBase(
      bottomNavDestination: 'contacts',
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
                "Contacts Screen: Under construction",
                style: AppText.body(scheme),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
