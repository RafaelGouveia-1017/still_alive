import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';

import '../contacts/contacts.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

class QuickContacts extends StatefulWidget {
  const QuickContacts({super.key});

  @override
  State<QuickContacts> createState() => _QuickContactsState();
}

/// State implementation for [QuickContacts].
class _QuickContactsState extends State<QuickContacts> {
  late List<_QuickContactData> quickContacts;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;

    /*
      TODO get quick contacts from database
      randomise color selection or get contact image
    */

    quickContacts = [
      _QuickContactData(
        name: 'Alex',
        gradient: [scheme.primary, scheme.primaryContainer],
        textColor: scheme.onPrimary,
        onTap: null,
      ),
      _QuickContactData(
        name: 'Mia',
        gradient: [scheme.secondary, scheme.secondaryContainer],
        textColor: scheme.onSecondary,
        onTap: null,
      ),
      _QuickContactData(
        name: 'Jo',
        gradient: [scheme.tertiary, scheme.tertiaryContainer],
        textColor: scheme.onTertiary,
        onTap: null,
      ),
      _QuickContactData(
        name: '+',
        gradient: [Colors.transparent, Colors.transparent],
        textColor: scheme.onError,
        onTap: () => Navigator.of(context).push(
          AppRoute(
            page: ContactsScreen(),
            transition: AppRouteTransitionType.slideRight,
          ),
        ),
      ),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    final movableContacts = quickContacts.where((c) => c.name != '+').toList();
    final addContact = quickContacts.firstWhere((c) => c.name == '+');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(local.translate("home.quick_contacts")),
        ReorderableBuilder(
          onReorder: (ReorderedListFunction reorder) {
            setState(() {
              final reordered =
                  reorder(movableContacts) as List<_QuickContactData>;

              quickContacts = [...reordered, addContact];
            });
          },
          builder: (children) {
            return GridView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: .75,
              ),
              children: [
                ...children,

                _QuickContact(
                  name: addContact.name,
                  gradient: addContact.gradient,
                  textColor: addContact.textColor,
                  onTap: addContact.onTap,
                ),
              ],
            );
          },
          children: [
            for (final contact in movableContacts)
              KeyedSubtree(
                key: ValueKey(contact.name + contact.hashCode.toString()),
                child: _QuickContact(
                  name: contact.name,
                  gradient: contact.gradient,
                  textColor: contact.textColor,
                  onTap: contact.onTap,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickContactData {
  const _QuickContactData({
    required this.name,
    required this.gradient,
    required this.textColor,
    required this.onTap,
  });

  final String name;
  final List<Color> gradient;
  final Color textColor;
  final VoidCallback? onTap;
}

class _QuickContact extends StatelessWidget {
  const _QuickContact({
    required this.name,
    required this.gradient,
    required this.textColor,
    this.onTap,
  });

  final String name;
  final List<Color> gradient;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAdd = name == '+';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            alignment: Alignment.center,
            child: isAdd
                ? CircleIconButton(
                    icon: LucideIcons.plus,
                    background: scheme.surfaceContainer,
                  )
                : Text(
                    name[0],
                    style: AppText.title(scheme).copyWith(color: textColor),
                  ),
          ),
          const SizedBox(height: AppSpacing.xs),
          isAdd
              ? Text("", style: AppText.micro(scheme))
              : Text(name, style: AppText.micro(scheme)),
        ],
      ),
    );
  }
}
