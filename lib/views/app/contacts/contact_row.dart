import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:still_alive/services/contact_service.dart';
import 'package:still_alive/src/rust/api/timer/config.dart' as config;

import 'contact_detail.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Immutable presentation data for rendering a contact in the application.
///
/// [ContactData] contains the subset of device contact information and
/// application-specific status needed by the contact list UI. In addition to
/// the contact's identity and display information, it stores whether the
/// contact is marked as a favorite, emergency contact, or quick contact.
///
/// The model also contains the avatar image and generated gradient information
/// used to render a consistent contact header or avatar without requiring
/// widgets to access the underlying device contact object directly.
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

/// Holds reactive state shared by a [ContactRow] and its
/// [ContactQuickSheet].
///
/// The controller keeps the quick-contact status and the loading state of
/// quick-contact operations in [ValueNotifier] instances. This allows both
/// the contact row and the bottom sheet to react immediately when the quick
/// contact status changes without requiring either widget to own the other's
/// state.
///
/// The controller owns both notifiers and is therefore responsible for their
/// lifecycle. Call [dispose] when the controller is no longer used.
class ContactQuickController {
  final ValueNotifier<bool> isQuick = ValueNotifier(false);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  void dispose() {
    isQuick.dispose();
    isLoading.dispose();
  }
}

/// A list item that displays a contact and provides access to contact actions.
///
/// The row displays the contact's avatar, name, relationship or role, and
/// phone number. Depending on the contact state, it can also display
/// indicators for favorite, emergency, and quick-contact status.
///
/// In compact mode, an overflow action opens [ContactQuickSheet], allowing the
/// user to add or remove the contact from the application's quick contacts.
///
/// When [timerContact] and [onChanged] are provided, the row additionally
/// represents the contact's current timer-selection state and propagates
/// changes to the selected contact methods through the supplied callback.
///
/// Tapping the main contact area opens [ContactDetailScreen] while preserving
/// the contact avatar through a Hero transition.
class ContactRow extends StatefulWidget {
  const ContactRow({
    super.key,
    required this.data,
    required this.heroID,
    this.compact = true,
    this.timerContact,
    this.onChanged,
  });

  final ContactData data;
  final String heroID;
  final bool compact;

  final config.Contact? timerContact;
  final ValueChanged<config.Contact?>? onChanged;

  @override
  State<ContactRow> createState() => _ContactRowState();
}

/// Manages the state and quick-contact interactions for [ContactRow].
///
/// The state creates and owns a [ContactQuickController], initializing its
/// quick-contact state from the supplied [ContactData]. The controller is
/// shared with [ContactQuickSheet] when the quick-contact action is opened.
///
/// The controller is disposed together with the row so that its reactive
/// resources do not outlive the widget.
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
                  heroID: widget.heroID,
                  gradient: data.gradient,
                  textColor: data.textColor,
                  timerContact: widget.timerContact,
                  onChanged: widget.onChanged,
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
                      tag: widget.heroID,
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

/// Displays the quick-contact management action for a contact.
///
/// The sheet allows the user to add the contact to or remove the contact from
/// the application's quick contacts. While the database operation is in
/// progress, the action is replaced by a loading indicator and further
/// interaction is temporarily prevented.
///
/// The sheet shares a [ContactQuickController] with the originating
/// [ContactRow]. This keeps the quick-contact indicator in the row synchronized
/// with the result of the operation performed in the sheet.
///
/// Database failures are logged and presented using the application's
/// standard error message UI.
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
