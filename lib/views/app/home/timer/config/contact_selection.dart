import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/src/rust/api/timer/config.dart';
import 'package:still_alive/views/app/contacts/contacts.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';

/// A widget that displays the contacts currently selected for a timer.
///
/// The widget presents a compact summary of the current timer contact
/// selection and provides navigation to [ContactsScreen] for managing the
/// selection. The displayed summary adapts to the number of selected
/// contacts and uses the application's localized strings.
///
/// The current selection is provided through [timerContacts], which is
/// observed for changes so that the summary stays synchronized with the
/// underlying value. Changes made in the contact selection screen are
/// propagated through [onChanged].
class ContactSelection extends StatefulWidget {
  const ContactSelection({
    super.key,
    required this.timerContacts,
    required this.onChanged,
  });

  final ValueListenable<List<Contact>> timerContacts;
  final ValueChanged<List<Contact>?> onChanged;

  @override
  State<ContactSelection> createState() => _ContactSelectionState();
}

/// Manages the reactive state for [ContactSelection].
///
/// The state listens to [ContactSelection.timerContacts] and rebuilds the
/// selection summary whenever the list of selected contacts changes. When the
/// widget receives a different [ValueListenable], the old listener is removed
/// and the new listener is registered.
///
/// The listener is also removed when the state is disposed to prevent
/// callbacks from being delivered after the widget has been removed.
class _ContactSelectionState extends State<ContactSelection> {
  @override
  void initState() {
    super.initState();

    widget.timerContacts.addListener(_onTimerContactsChanged);
  }

  void _onTimerContactsChanged() {
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant ContactSelection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.timerContacts != widget.timerContacts) {
      oldWidget.timerContacts.removeListener(_onTimerContactsChanged);
      widget.timerContacts.addListener(_onTimerContactsChanged);

      _onTimerContactsChanged();
    }
  }

  @override
  void dispose() {
    widget.timerContacts.removeListener(_onTimerContactsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return AppCard(
      child: Pressable(
        onTap: () => Navigator.of(context).push(
          AppRoute(
            page: ContactsScreen.selectContactsForTimer(
              timerContacts: widget.timerContacts.value,
              onChanged: (value) => widget.onChanged(value),
            ),
            transition: AppRouteTransitionType.slideLeft,
          ),
        ),
        child: AppRow(
          padding: EdgeInsets.zero,
          title: switch (widget.timerContacts.value.length) {
            0 => local.translate("timer_configuration.contacts.none"),
            1 =>
              '1 ${local.translate("timer_configuration.contacts.contact.0")} '
                  '${local.translate("timer_configuration.contacts.selected.0")}',
            _ =>
              '${widget.timerContacts.value.length} '
                  '${local.translate("timer_configuration.contacts.contact.1")} '
                  '${local.translate("timer_configuration.contacts.selected.1")}',
          },
          icon: (widget.timerContacts.value.isNotEmpty)
              ? LucideIcons.bookUser
              : LucideIcons.book,
          iconColor: scheme.secondary,
          trailing: Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
