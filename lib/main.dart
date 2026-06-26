import 'dart:io';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:page_transition/page_transition.dart';

import 'package:still_alive/src/rust/frb_generated.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';

import 'package:still_alive/src/rust/api/data/db.dart';

import 'package:still_alive/data/app_design.dart';
import 'package:still_alive/data/app_localization.dart';
import 'package:still_alive/data/app_themes.dart';
import 'package:still_alive/data/custom_theme.dart';

import 'package:still_alive/views/app/screens.dart';
import 'package:still_alive/views/widgets/custom_splash.dart';

/// Application entry point.
///
/// Performs all startup initialization including:
/// * Flutter framework initialization.
/// * Native splash screen preservation.
/// * Rust library initialization.
/// * Database initialization.
/// * Theme loading and restoration.
/// * Localization provider setup.
///
/// After initialization completes, the root [MyApp] widget is launched.
void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await RustLib.init();

  SystemChrome.setEnabledSystemUIMode(.immersive);

  Directory documentDirectory = await getApplicationDocumentsDirectory();
  try {
    await initDatabase(
      path: p.join(documentDirectory.path, await getDatabaseName()),
    );
  } catch (e) {
    log('Database Error: $e');
  }

  //TODO Delete this line when in production
  //await purgeDatabase();

  String label = await CustomTheme.load();
  CustomTheme theme = CustomTheme.fromLabel(label);
  ThemeData appTheme = AppThemes.getTheme(theme);
  ThemeData appDesign = AppDesign.getDesign(appTheme);

  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final provider = LocaleProvider();
        provider.loadSavedLocale();
        return provider;
      },
      child: MyApp(theme: appDesign, currentTheme: theme),
    ),
  );
}

/// Root widget of the application.
///
/// Responsible for:
/// * Initializing the application UI.
/// * Providing localization support.
/// * Managing the active theme through [MyAppState].
/// * Displaying the splash screen and loading the initial route.
///
/// The initial theme is supplied during application startup and can
/// be changed at runtime through [MyAppState.changeTheme].
class MyApp extends StatefulWidget {
  /// The theme applied to the application when it starts.
  final ThemeData theme;
  final CustomTheme currentTheme;

  /// Creates the root application widget.
  const MyApp({super.key, required this.theme, required this.currentTheme});

  @override
  State<MyApp> createState() => MyAppState();

  /// Returns the nearest [MyAppState] instance in the widget tree.
  ///
  /// This can be used by descendant widgets to access application-level
  /// functionality such as changing the active theme.
  static MyAppState of(BuildContext context) {
    return context.findAncestorStateOfType<MyAppState>()!;
  }
}

/// State implementation for [MyApp].
///
/// Manages:
/// * The currently active application theme.
/// * Splash screen loading state.
/// * Runtime theme changes.
/// * Resolution of the application's landing page.
/// * Computing system UI overlay style based on the active theme
/// * Ensuring correct icon contrast for status/navigation bars
/// * Building a layout that supports edge-to-edge rendering on Android 15+
///
/// This state object serves as the central controller for app-wide
/// visual configuration.
class MyAppState extends State<MyApp> {
  late ThemeData _themeData;
  late CustomTheme _currentTheme;
  bool _showLoader = false;

  CustomTheme get currentTheme => _currentTheme;

  @override
  void initState() {
    super.initState();
    _themeData = widget.theme;
    _currentTheme = widget.currentTheme;

    Future.delayed(Duration(milliseconds: 1300), () {
      if (mounted) {
        setState(() {
          _showLoader = true;
        });
      }
    });
  }

  /// Updates the application's active theme.
  ///
  /// The selected theme is applied immediately and persisted so it
  /// can be restored during future application launches.
  Future<void> changeTheme(CustomTheme theme) async {
    setState(() {
      _themeData = AppThemes.getTheme(theme);
      _currentTheme = theme;
    });

    await CustomTheme.save(theme.label());
  }

  /// Determines the first screen displayed after the splash screen.
  ///
  /// Intended to evaluate onboarding, permissions, and application
  /// state before routing the user to the appropriate destination.
  Future<Widget> getLandingPage() async {
    /* 
    if tutorial = false => WelcomeScreen();
    else if permissons not OK => PermissionsScreen();
    else => HomeDashboardScreen();
    */

    return OnboardingScreen(startPage: 0);
  }

  /// Configures the system UI appearance based on the current theme.
  ///
  /// This method ensures the status bar color and icon brightness match
  /// the active [ColorScheme].
  SystemUiOverlayStyle _buildSystemUiStyle(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    return SystemUiOverlayStyle(
      statusBarIconBrightness: scheme.brightness,
      systemNavigationBarIconBrightness: scheme.brightness,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    MaterialApp root = MaterialApp(
      debugShowCheckedModeBanner: false,

      locale: localeProvider.locale,
      supportedLocales: AppLocalizationsDelegate.supportedLocales.map((lang) {
        return lang.locale;
      }).toList(),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      title: 'StillAlive',
      theme: _themeData,
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _buildSystemUiStyle(context),
        child: AnimatedSplashScreen.withScreenFunction(
          splashIconSize: MediaQuery.of(context).size.longestSide,
          splash: CustomSplash().splash(_showLoader, _themeData.colorScheme),
          screenFunction: () => getLandingPage(),
          splashTransition: SplashTransition.fadeTransition,
          pageTransitionType: PageTransitionType.rightToLeft,
          backgroundColor: _themeData.colorScheme.surface,
        ),
      ),
    );
    FlutterNativeSplash.remove();
    return root;
  }
}
