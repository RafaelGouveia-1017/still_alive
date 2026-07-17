import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'quick_contacts.dart';
import 'phone_status.dart';
import '../history.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';
import '../../widgets/countdown_ring.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// State implementation for [HomeScreen].
class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return ScreenBase(
      bottomNavDestination: 'home',
      header: AppHeader(
        title: local.translate('app_name'),
        left: CircleIconButton(
          icon: LucideIcons
              .shieldOff, //TODO change to LucideIcons.shield while timer is active
          foreground: scheme.primary,
        ),
        right: CircleIconButton(
          icon: LucideIcons.list,
          onTap: () {
            showBlurredBottomSheet(
              scheme: scheme,
              context: context,
              marginHorizontal: 40,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: 25, //TODO number of timers created
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: scheme.outlineVariant),
                itemBuilder: (context, index) {
                  return Pressable(
                    factory: InkSparkle.splashFactory,
                    onTap: () => Navigator.of(context).push(
                      AppRoute(
                        page: HistoryScreen(),
                        transition: AppRouteTransitionType.slideRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text("Timer $index", style: AppText.body(scheme)),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ListView(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                children: [
                  Center(
                    child: Pill(
                      label: local.translate(
                        "home.inactive",
                      ), //TODO change to local.translate("home.active") while timer is active
                      color: scheme
                          .onSurfaceVariant, //TODO change to scheme.tertiary while timer is active
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CountdownRing(
                    time: '00:30:00',
                    label: 'Safety Timer',
                    color: scheme.primary,
                    progress: 1.0,
                    caption: 'Tap to configure',
                    //onTap: onConfigureTimer,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  PhoneStatus(
                    contacts: 0,
                    integrations: 0,
                  ), //TODO get number of contacts & plugins in timer
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Start safety timer',
                    icon: LucideIcons.play,
                    //onPressed: onConfigureTimer,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  QuickContacts(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
