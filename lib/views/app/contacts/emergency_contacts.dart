import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

import '../contacts/contact_detail.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsState();
}

/// State implementation for [EmergencyContactsScreen].
class _EmergencyContactsState extends State<EmergencyContactsScreen> {
  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return ScreenBase(
      header: AppHeader(
        title: 'Emergency Contacts',
        left: CircleIconButton(
          icon: LucideIcons.chevronLeft,
          onTap: () => Navigator.pop(context),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      border: Border.all(color: const Color(0x0DFFFFFF)),
                    ),
                    child: Icon(
                      LucideIcons.shieldAlert,
                      size: 36,
                      color: scheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('No contacts yet', style: AppText.h2(scheme)),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      "Add at least one person you trust.\nThey'll be alerted in an emergency.",
                      textAlign: TextAlign.center,
                      style: AppText.caption(scheme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
