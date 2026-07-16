import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/app_design.dart';
import '../../widgets/primitives.dart';

class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({super.key, required this.contactID});

  final String contactID;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailState();
}

/// State implementation for [ContactDetailScreen].
class _ContactDetailState extends State<ContactDetailScreen> {
  final VoidCallback? onBack = null;
  final VoidCallback? onEdit = null;
  final VoidCallback? onRemove = null;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        AppHeader(
          title: 'Contact',
          left: CircleIconButton(icon: LucideIcons.chevronLeft, onTap: onBack),
          right: CircleIconButton(icon: LucideIcons.pencil, onTap: onEdit),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF8A65), Color(0xFFFF5252)],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x99FF5252),
                            blurRadius: 50,
                            spreadRadius: -20,
                            offset: Offset(0, 20),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text('A', style: AppText.h1(scheme)),
                    ),
                    const SizedBox(height: 12),
                    Text('Alex Chen', style: AppText.h2(scheme)),
                    const SizedBox(height: 2),
                    Text('Partner · Starred', style: AppText.caption(scheme)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        Pill(label: 'SMS', color: scheme.tertiary),
                        Pill(label: 'Email', color: scheme.primary),
                        Pill(label: 'Telegram', color: scheme.secondary),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.phone,
                      label: 'Call',
                      color: scheme.primary,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.message_outlined,
                      label: 'Text',
                      color: scheme.tertiary,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.mail_outline,
                      label: 'Email',
                      color: scheme.secondary,
                    ),
                  ),
                ],
              ),
              const SectionTitle('Contact info'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    AppRow(
                      icon: Icons.phone,
                      title: '+1 (415) 555-0142',
                      subtitle: 'Primary mobile',
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    AppRow(
                      icon: Icons.mail_outline,
                      title: 'alex@chen.co',
                      subtitle: 'Email',
                    ),
                  ],
                ),
              ),
              const SectionTitle('Alert preferences'),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Include live location',
                          style: AppText.bodySm(scheme),
                        ),
                        Pill(label: 'On', color: scheme.tertiary),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: scheme.outlineVariant),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Send audio recording',
                          style: AppText.bodySm(scheme),
                        ),
                        Pill(label: 'Off', color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFF4D5E),
                    borderRadius: AppRadius.card,
                    border: Border.all(color: const Color(0x4DFF4D5E)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: scheme.error),
                      const SizedBox(width: 8),
                      Text(
                        'Remove contact',
                        style: AppText.bodySm(
                          scheme,
                        ).copyWith(color: scheme.error),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.card,
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(label, style: AppText.micro(scheme)),
        ],
      ),
    );
  }
}
