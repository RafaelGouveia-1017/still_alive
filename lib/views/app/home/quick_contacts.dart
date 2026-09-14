import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/main.dart';
import 'package:still_alive/services/contact_service.dart';

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
class _QuickContactsState extends State<QuickContacts> with RouteAware {
  late List<_QuickContactData> quickContacts = [];
  bool _isLoading = true;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    loadQuickContacts();

    _lifecycleListener = AppLifecycleListener(onResume: () => didPopNext());
  }

  void loadQuickContacts() async {
    setState(() {
      quickContacts = [];
      _isLoading = true;
    });

    final String jsonString = await selectOne(
      sql: "SELECT value FROM contacts WHERE key = 'quick'",
    );

    final Map<String, dynamic> jsonQuick = jsonDecode(jsonString);

    if (jsonQuick['count'] != 0) {
      if (!mounted) return;
      List<({List<Color> gradient, Color text})> colorOpts =
          ContactService.colorOptions(context);

      for (String id in jsonQuick['ids']) {
        try {
          Contact? contact = await FlutterContacts.get(
            id,
            properties: {ContactProperty.name, ContactProperty.photoThumbnail},
          );
          if (contact != null) {
            final colors = colorOpts[Random().nextInt(colorOpts.length)];

            quickContacts.add(
              _QuickContactData(
                id: id,
                name: contact.displayName,
                image: contact.photo,
                gradient: colors.gradient,
                textColor: colors.text,
              ),
            );
          }
        } catch (e) {
          AppLogger.log.info('Contact not found.', e);
          ContactService.deleteQuickContact(id);
          continue;
        }
      }
    }

    quickContacts.add(
      _QuickContactData(
        id: '+',
        name: '+',
        image: null,
        gradient: [Colors.transparent, Colors.transparent],
        textColor: Colors.transparent,
      ),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    loadQuickContacts();
    super.didPopNext();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    routeObserver.unsubscribe(this);
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
        if (movableContacts.isEmpty) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(
              AppRoute(
                page: ContactsScreen.showAllContacts(),
                transition: AppRouteTransitionType.slideRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                left: AppSpacing.ms,
              ),
              child: CircleIconButton(
                icon: LucideIcons.plus,
                background: scheme.surfaceContainer,
              ),
            ),
          ),
        ] else ...[
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
                  childAspectRatio: 0.75,
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
                  key: ValueKey(contact.id + contact.hashCode.toString()),
                  child: _QuickContact(data: contact),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
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
  });

  final String id;
  final String? name;
  final Photo? image;
  final List<Color> gradient;
  final Color textColor;
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

    String letter = (data.name == null || data.name == '')
        ? '?'
        : data.name![0];

    bool hasImage = data.image?.thumbnail != null;
    bool isAdd = data.name![0] == '+';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        AppRoute(
          page: (isAdd)
              ? ContactsScreen.showAllContacts()
              : ContactDetailScreen(
                  contactID: data.id,
                  heroID: 'contact-pic-${data.id}',
                  gradient: data.gradient,
                  textColor: data.textColor,
                ),
          transition: (isAdd)
              ? AppRouteTransitionType.slideRight
              : AppRouteTransitionType.slideLeft,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Hero(
            tag: 'contact-pic-${data.id}',
            flightShuttleBuilder: (context, animation, direction, from, to) =>
                AppHeader.flight(context, animation, direction, from, to),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: 56,
                height: 56,
                clipBehavior: Clip.antiAlias,
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
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          isAdd
              ? Text("", style: AppText.micro(scheme))
              : Text(
                  data.name ?? '?',
                  style: AppText.micro(scheme),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ],
      ),
    );
  }
}
