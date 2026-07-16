import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

import '../contacts/contacts.dart';
import '../contacts/contact_detail.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Displays a reorderable grid of pinned contacts for quick access.
///
/// The widget loads the user's configured quick contacts from the local
/// database, retrieves their contact information, and displays them as
/// interactive tiles. An additional tile is always shown for adding or
/// managing quick contacts.
class QuickContacts extends StatefulWidget {
  const QuickContacts({super.key});

  @override
  State<QuickContacts> createState() => _QuickContactsState();
}

/// State implementation for [QuickContacts].
class _QuickContactsState extends State<QuickContacts> {
  late List<_QuickContactData> quickContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();

    ColorScheme scheme = Theme.of(context).colorScheme;

    final String jsonString = await selectOne(
      sql: "SELECT value FROM contacts WHERE key = 'quick'",
    );

    final Map<String, dynamic> jsonQuick = jsonDecode(jsonString);

    if (jsonQuick['count'] != 0) {
      List<({List<Color> gradient, Color text})> colorOptions = [
        (
          gradient: [scheme.primary, scheme.primaryContainer],
          text: scheme.onPrimary,
        ),
        (
          gradient: [scheme.secondary, scheme.secondaryContainer],
          text: scheme.onSecondary,
        ),
        (
          gradient: [scheme.tertiary, scheme.tertiaryContainer],
          text: scheme.onTertiary,
        ),
        (gradient: [scheme.error, scheme.errorContainer], text: scheme.onError),
        (
          gradient: rotateHue([scheme.primary, scheme.primaryContainer]),
          text: scheme.onPrimary,
        ),
        (
          gradient: rotateHue([scheme.secondary, scheme.secondaryContainer]),
          text: scheme.onSecondary,
        ),
        (
          gradient: rotateHue([scheme.tertiary, scheme.tertiaryContainer]),
          text: scheme.onTertiary,
        ),
        (
          gradient: rotateHue([scheme.error, scheme.errorContainer]),
          text: scheme.onError,
        ),
      ];

      for (String id in jsonQuick['ids']) {
        Contact? contact = await FlutterContacts.get(
          id,
          properties: {ContactProperty.name, ContactProperty.photoThumbnail},
        );
        if (contact != null) {
          final colors = colorOptions[Random().nextInt(colorOptions.length)];

          quickContacts.add(
            _QuickContactData(
              id: id,
              name: contact.name,
              image: contact.photo,
              gradient: colors.gradient,
              textColor: colors.text,
              destination: ContactDetailScreen(contactID: id),
            ),
          );
        }
      }
    }

    quickContacts.add(
      _QuickContactData(
        id: '+',
        name: Name(first: '+'),
        image: null,
        gradient: [Colors.transparent, Colors.transparent],
        textColor: Colors.transparent,
        destination: ContactsScreen(),
      ),
    );

    setState(() {
      _isLoading = false;
    });
  }

  List<Color> rotateHue(List<Color> gradient) {
    double rand = Random().nextDouble() * 360;
    HSVColor hsv0 = HSVColor.fromColor(gradient[0]);
    HSVColor hsv1 = HSVColor.fromColor(gradient[1]);
    return [
      hsv0.withHue((hsv0.hue + rand) % 360).toColor(),
      hsv1.withHue((hsv1.hue + rand) % 360).toColor(),
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

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: scheme.tertiary));
    }

    final movableContacts = quickContacts.sublist(0, quickContacts.length - 1);
    final addContact = quickContacts[quickContacts.length - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(local.translate("home.quick_contacts")),
        ReorderableBuilder(
          onReorder: (ReorderedListFunction reorder) {
            setState(() {
              final reordered =
                  reorder(movableContacts) as List<_QuickContactData>;

              Map<String, dynamic> json = {
                'count': reordered.length,
                'ids': reordered.map((contact) => contact.id).toList(),
              };

              executeSql(
                sql:
                    "UPDATE contacts SET value = '${jsonEncode(json).replaceAll("'", "''")}' WHERE key = 'quick'",
              );

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

                _QuickContact(data: addContact),
              ],
            );
          },
          children: [
            for (final contact in movableContacts)
              KeyedSubtree(
                key: ValueKey(contact.hashCode.toString()),
                child: _QuickContact(data: contact),
              ),
          ],
        ),
      ],
    );
  }
}

/// Immutable data model describing a quick contact tile.
///
/// Stores the contact's identifier, display information, appearance,
/// and the destination screen opened when the tile is tapped.
class _QuickContactData {
  const _QuickContactData({
    required this.id,
    required this.name,
    required this.image,
    required this.gradient,
    required this.textColor,
    required this.destination,
  });

  final String id;
  final Name? name;
  final Photo? image;
  final List<Color> gradient;
  final Color textColor;
  final Widget destination;
}

/// Displays an individual quick contact tile.
///
/// The tile shows either the contact's photo, the first letter of their
/// name, or an add button, depending on the associated contact data.
class _QuickContact extends StatelessWidget {
  const _QuickContact({required this.data});

  final _QuickContactData data;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    String first = data.name?.first ?? '';
    String middle = data.name?.middle ?? '';
    String last = data.name?.last ?? '';
    String name = [first, middle, last].where((s) => s.isNotEmpty).join(' ');

    String letter = '?';

    if (first != '') {
      letter = first[0];
    } else if (middle != '') {
      letter = middle[0];
    } else if (last != '') {
      letter = last[0];
    }

    bool hasImage = data.image?.thumbnail != null;
    bool isAdd = first == '+';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        AppRoute(
          page: data.destination,
          transition: AppRouteTransitionType.slideRight,
        ),
      ),
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
                colors: data.gradient,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            alignment: Alignment.center,
            child: isAdd
                ? CircleIconButton(
                    icon: LucideIcons.plus,
                    background: scheme.surfaceContainer,
                  )
                : (hasImage)
                ? Image.memory(
                    data.image!.thumbnail!,
                    filterQuality: FilterQuality.high,
                  )
                : Text(
                    letter,
                    style: AppText.title(
                      scheme,
                    ).copyWith(color: data.textColor),
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
