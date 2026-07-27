import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:still_alive/services/contact_service.dart';

import 'contact_detail.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Immutable display model containing the data required to render a contact.
///
/// This class separates UI rendering concerns from the underlying contact
/// storage model. It contains only the information needed by widgets such as
/// [ContactRow].
class ContactData {
  const ContactData({
    required this.id,
    required this.name,
    required this.image,
    required this.role,
    required this.phone,
    required this.favorite,
    required this.emergency,
    required this.quick,
    required this.gradient,
    required this.textColor,
  });

  final String id;
  final String? name;
  final Photo? image;
  final String role;
  final String phone;
  final bool favorite;
  final bool emergency;
  final bool quick;
  final List<Color> gradient;
  final Color textColor;
}

/// Holds reactive state shared between a [ContactRow] and its associated
/// [ContactQuickSheet].
///
/// The controller exposes the contact's quick status and loading state through
/// [ValueNotifier] instances so that changes made from the bottom sheet are
/// immediately reflected in the contact row.
///
/// The controller owns the notifiers and must be disposed when no longer used.
class ContactQuickController {
  final ValueNotifier<bool> isQuick = ValueNotifier(false);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  void dispose() {
    isQuick.dispose();
    isLoading.dispose();
  }
}

/// Displays a contact entry in a list.
///
/// The row renders:
/// * Contact avatar or generated initial.
/// * Contact name.
/// * Relationship and phone information.
/// * Status indicators such as favorite, emergency, and quick contact state.
///
/// When the overflow action is pressed, a [ContactQuickSheet] is displayed
/// allowing the user to modify the contact's quick status.
class ContactRow extends StatefulWidget {
  const ContactRow({super.key, required this.data, this.compact = true});

  final ContactData data;
  final bool compact;

  @override
  State<ContactRow> createState() => _ContactRowState();
}

/// State implementation for [ContactRow].
///
/// Owns the [ContactQuickController] instance used by both the row indicators
/// and the quick contact management sheet.
class _ContactRowState extends State<ContactRow> {
  late final ContactQuickController controller;

  @override
  void initState() {
    super.initState();

    controller = ContactQuickController();
    controller.isQuick.value = widget.data.quick;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    bool compact = widget.compact;
    ContactData data = widget.data;

    double size = compact ? 40.0 : 44.0;

    String letter = (data.name == null || data.name == '')
        ? '?'
        : data.name![0];
    bool hasImage = data.image?.thumbnail != null;

    return Row(
      children: [
        Expanded(
          child: Pressable(
            onTap: () => Navigator.of(context).push(
              AppRoute(
                page: ContactDetailScreen(
                  contactID: data.id,
                  heroID: (compact)
                      ? 'contact-pic-${data.id}'
                      : 'contact-pic-${data.id}-starred',
                  gradient: data.gradient,
                  textColor: data.textColor,
                ),
                transition: AppRouteTransitionType.slideLeft,
              ),
            ),
            child: Stack(
              children: [
                if (compact && data.favorite)
                  Positioned(
                    top: 0,
                    left: 29,
                    child: Icon(
                      LucideIcons.star,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                Row(
                  children: [
                    Hero(
                      tag: (compact)
                          ? 'contact-pic-${data.id}'
                          : 'contact-pic-${data.id}-starred',
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
                          width: size,
                          height: size,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: data.gradient,
                            ),
                            borderRadius: BorderRadius.circular(
                              compact ? AppRadius.md : AppRadius.lg,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: (hasImage)
                              ? Image.memory(
                                  data.image!.thumbnail!,
                                  filterQuality: FilterQuality.high,
                                )
                              : Text(
                                  letter,
                                  style: AppText.bodySm(
                                    scheme,
                                  ).copyWith(color: data.textColor),
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
                                  data.name ?? '?',
                                  style: AppText.bodySm(scheme),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                          if (data.role.isNotEmpty || data.phone.isNotEmpty)
                            Text(
                              (data.role.isNotEmpty && data.phone.isNotEmpty)
                                  ? '${data.role} • ${data.phone}'
                                  : (data.role.isEmpty)
                                  ? data.phone
                                  : data.role,
                              style: AppText.caption(scheme),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
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
        if (compact)
          Pressable(
            onTap: () {
              showBlurredBottomSheet(
                context: context,
                scheme: scheme,
                marginHorizontal: 30,
                child: ContactQuickSheet(
                  controller: controller,
                  contactID: widget.data.id,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(left: AppSpacing.md),
              child: Row(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: controller.isQuick,
                    builder: (context, isQuick, _) {
                      return Column(
                        children: [
                          if (!data.favorite && !isQuick && !data.emergency)
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: ColoredBox(color: scheme.surfaceContainer),
                            ),
                          if (data.emergency) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xxxs,
                              ),
                              child: Icon(
                                LucideIcons.shieldAlert,
                                size: 12,
                                color: scheme.error,
                              ),
                            ),
                          ],
                          if (isQuick) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xxxs,
                              ),
                              child: Icon(
                                LucideIcons.zap,
                                size: 12,
                                color: scheme.tertiary,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    LucideIcons.ellipsisVertical,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet content used to add or remove a contact from the quick contacts
/// list.
///
/// Uses a shared [ContactQuickController] to keep its state synchronized with
/// the originating [ContactRow]. Displays a loading indicator while the
/// database operation is running and updates the quick contact state after a
/// successful operation.
///
/// The sheet performs the required database updates and handles errors by
/// displaying a user-facing toast message.
class ContactQuickSheet extends StatelessWidget {
  const ContactQuickSheet({
    super.key,
    required this.controller,
    required this.contactID,
  });

  final ContactQuickController controller;
  final String contactID;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppRadius.lg),
      child: ValueListenableBuilder<bool>(
        valueListenable: controller.isQuick,
        builder: (context, isQuick, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: controller.isLoading,
            builder: (context, isLoading, _) {
              if (isLoading) {
                return SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: CircularProgressIndicator(color: scheme.tertiary),
                  ),
                );
              }

              return SizedBox(
                height: 56,
                child: PrimaryButton(
                  icon: isQuick ? LucideIcons.trash2 : LucideIcons.plus,
                  label: isQuick
                      ? local.translate("contacts_list.is_quick.true")
                      : local.translate("contacts_list.is_quick.false"),
                  color: isQuick ? ButtonColor.warning : ButtonColor.primary,
                  onPressed: () async {
                    controller.isLoading.value = true;

                    try {
                      if (isQuick) {
                        ContactService.deleteQuickContact(contactID);
                      } else {
                        ContactService.insertQuickContact(contactID);
                      }

                      controller.isQuick.value = !isQuick;
                    } catch (e, st) {
                      AppLogger.log.severe('SQL failed', e, st);
                      if (context.mounted) {
                        showGenericErrorMessage(context, null);
                      }
                    } finally {
                      controller.isLoading.value = false;
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
