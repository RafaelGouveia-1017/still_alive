import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/services/contact_service.dart';

import 'contact_detail.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsState();
}

/// State implementation for [EmergencyContactsScreen].
class _EmergencyContactsState extends State<EmergencyContactsScreen> {
  late List<Contact> emergencyContacts = [];
  bool _isLoading = true;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    loadContacts();

    _lifecycleListener = AppLifecycleListener(onResume: () => loadContacts());
  }

  void loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    String jsonString = await selectOne(
      sql: "SELECT value FROM contacts WHERE key = 'emergency'",
    );
    Map<String, dynamic> json = jsonDecode(jsonString);
    if (json['count'] != 0) {
      for (String id in json['ids']) {
        try {
          Contact? contact = await FlutterContacts.get(
            id,
            properties: {ContactProperty.name, ContactProperty.photoThumbnail},
          );
          if (contact != null) {
            emergencyContacts.add(contact);
          }
        } catch (e) {
          AppLogger.log.info('Contact not found.', e);
          continue;
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    //TODO show contacts that are in timers and what they receive

    return ScreenBase(
      header: AppHeader(
        title: local.translate("contacts_emergency.title"),
        left: CircleIconButton(
          icon: LucideIcons.chevronLeft,
          onTap: () => Navigator.pop(context),
        ),
      ),
      child: (_isLoading)
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: CircularProgressIndicator(color: scheme.tertiary),
              ),
            )
          : (emergencyContacts.isEmpty)
          ? Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxxxl,
                    ),
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
                        Text(
                          local.translate("contacts_emergency.message"),
                          style: AppText.h2(scheme),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            local.translate("contacts_emergency.description"),
                            textAlign: TextAlign.center,
                            style: AppText.caption(scheme),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : AppCard(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  for (int i = 0; i < emergencyContacts.length; i++) ...[
                    EmergencyContactRow(contact: emergencyContacts[i]),
                    if (i < emergencyContacts.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.ms,
                        ),
                        child: Divider(height: 1, color: scheme.outlineVariant),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class EmergencyContactRow extends StatelessWidget {
  const EmergencyContactRow({super.key, required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    final colorOpts = ContactService.colorOptions(context);
    final colors = colorOpts[Random().nextInt(colorOpts.length)];

    String letter = (contact.name == null || contact.displayName == '')
        ? '?'
        : contact.displayName![0];
    bool hasImage = contact.photo?.fullSize != null;

    return Row(
      children: [
        Expanded(
          child: Pressable(
            onTap: () => Navigator.of(context).push(
              AppRoute(
                page: ContactDetailScreen(
                  contactID: contact.id!,
                  heroID: 'contact-pic-${contact.id}',
                  gradient: colors.gradient,
                  textColor: colors.text,
                ),
                transition: AppRouteTransitionType.slideLeft,
              ),
            ),
            child: Stack(
              children: [
                Row(
                  children: [
                    Hero(
                      tag: 'contact-pic-${contact.id}',
                      flightShuttleBuilder:
                          (context, animation, direction, from, to) =>
                              AppHeader.flight(
                                context,
                                animation,
                                direction,
                                from,
                                to,
                              ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                          width: 40,
                          height: 40,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: colors.gradient,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: (hasImage)
                              ? Image.memory(
                                  contact.photo!.thumbnail!,
                                  filterQuality: FilterQuality.high,
                                )
                              : Text(
                                  letter,
                                  style: AppText.bodySm(
                                    scheme,
                                  ).copyWith(color: colors.text),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  contact.displayName ?? '?',
                                  style: AppText.bodySm(scheme),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
