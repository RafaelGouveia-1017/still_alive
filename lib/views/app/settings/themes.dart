import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:still_alive/data/app_themes.dart';
import 'package:still_alive/data/app_design.dart';
import 'package:still_alive/data/app_localization.dart';
import 'package:still_alive/data/custom_theme.dart';
import '../../widgets/primitives.dart';
import 'package:still_alive/main.dart';

/// Represents a selectable theme option in the theme picker UI.
///
/// This model groups together:
/// * a [CustomTheme] identifier,
/// * its resolved [ThemeData],
/// * a set of representative color swatches for preview,
/// * and whether it is currently active.
///
/// It is primarily used by [ThemesScreen] to render a list of available
/// themes with visual previews and selection state.
class _AppThemeOption {
  const _AppThemeOption(
    this.theme,
    this.themeData,
    this.swatches, {
    this.active = false,
  });
  final CustomTheme theme;
  final ThemeData themeData;
  final List<Color> swatches;
  final bool active;
}

/// A screen that displays all available application themes and allows
/// the user to switch between them.
///
/// The screen renders a list of [AppThemeOption] entries, each showing:
/// * the theme name,
/// * a light/dark indicator,
/// * a color preview palette,
/// * and selection state.
///
/// When a theme is tapped, it updates the global app theme via [MyApp].
///
/// If [tutorial] is true, the bottom navigation bar is hidden.
class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

/// State implementation for [ThemesScreen].
class _ThemesScreenState extends State<ThemesScreen> {
  final ItemScrollController scrollController = ItemScrollController();
  final ItemPositionsListener positionsListener =
      ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveTheme();
    });
  }

  void _scrollToActiveTheme() async {
    final currentTheme = MyApp.of(context).currentTheme;
    final index = CustomTheme.values.indexOf(currentTheme);

    if (index == -1) return;
    await Future.delayed(Duration.zero);

    if (!scrollController.isAttached) return;

    scrollController.scrollTo(
      index: index,
      duration: AppMotion.fast,
      curve: AppMotion.easeInOut,
      alignment: 0.4,
    );
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    List<_AppThemeOption> themeOptions = [];
    for (var theme in CustomTheme.values) {
      ThemeData themeData = AppThemes.getTheme(theme);
      ColorScheme colorScheme = themeData.colorScheme;
      themeOptions.add(
        _AppThemeOption(theme, themeData, [
          colorScheme.surface,
          colorScheme.surfaceContainer,
          colorScheme.primary,
          colorScheme.secondary,
          colorScheme.tertiary,
          colorScheme.onSurface,
        ], active: MyApp.of(context).currentTheme == theme ? true : false),
      );
    }

    return ScreenBase(
      header: AppHeader(
        title: local.translate("themes.title"),
        subtitle: local.translate("themes.subtitle"),
        left: CircleIconButton(
          icon: LucideIcons.chevronLeft,
          onTap: () => Navigator.of(context).pop(),
        ),
        right: CircleIconButton(
          icon: LucideIcons.palette,
          background: scheme.secondary.withAlpha(38),
          foreground: scheme.secondary,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ScrollablePositionedList.builder(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              physics: const ClampingScrollPhysics(),
              itemCount: themeOptions.length + 1,
              itemScrollController: scrollController,
              itemBuilder: (context, index) {
                if (index == themeOptions.length) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.ms,
                      bottom: AppSpacing.xl,
                    ),
                    child: Center(
                      child: Text(
                        local.translate("themes.footer"),
                        style: AppText.micro(scheme),
                      ),
                    ),
                  );
                }

                final t = themeOptions[index];

                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!t.active) {
                          MyApp.of(context).changeTheme(t.theme);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: t.active
                              ? scheme.tertiary.withAlpha(15)
                              : scheme.surfaceContainer,
                          borderRadius: AppRadius.card,
                          border: Border.all(
                            color: t.active
                                ? scheme.tertiary.withAlpha(153)
                                : scheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      t.theme.label(),
                                      style: AppText.body(scheme),
                                    ),
                                    if (t.active) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      Pill(
                                        label: local.translate("themes.status"),
                                        backColor: scheme.tertiary,
                                      ),
                                    ],
                                  ],
                                ),
                                Icon(
                                  t.themeData.brightness == Brightness.dark
                                      ? LucideIcons.moon
                                      : LucideIcons.sun,
                                  color: scheme.onSurface.withAlpha(175),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                for (int i = 0; i < t.swatches.length; i++) ...[
                                  if (i > 0)
                                    const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Container(
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: t.swatches[i],
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        border: Border.all(
                                          color: scheme.outline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.ms),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
