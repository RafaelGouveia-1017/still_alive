import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:page_transition/page_transition.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/src/rust/api/timer/state.dart';

import 'package:still_alive/src/rust/frb_generated.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';

import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/data/all.dart';
import 'package:still_alive/services/native/method_channel.dart';
import 'package:still_alive/views/app/home/timer/emergency_active.dart';
import 'package:still_alive/views/app/home/timer/pre-alert/pre_alert_warning.dart';
import 'package:still_alive/views/app/screens.dart';
import 'package:still_alive/views/widgets/custom_splash.dart';

/// Application entry point.
///
/// Performs all startup initialization including but limited to:
/// * Flutter framework initialization.
/// * Native splash screen preservation.
/// * Permission observation initialization.
/// * Rust library initialization.
/// * System UI fullscreen setup.
/// * Database initialization.
/// * Theme loading and restoration.
/// * Localization provider setup.
///
/// After initialization completes, the root [MyApp] widget is launched.
void main() async {
  runZonedGuarded(
    () async {
      WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

      await AppLogger.init();
      AppLogger.log.info("AppLogger loaded.");

      await RustLib.init();
      AppLogger.log.info("RustLib loaded.");

      AppLogger.connectRustLogging();
      AppLogger.log.info("Connected Rust logger to AppLogger.");

      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      AppLogger.log.info("SystemChrome setup finish.");

      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.log.severe("Flutter Error", details.exception, details.stack);
        //GlobalErrorDialog.show();
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.log.severe("Platform Error", error, stack);
        //GlobalErrorDialog.show();
        return true;
      };
      AppLogger.log.info("GlobalError setup finish.");

      Directory documentDirectory = await getApplicationDocumentsDirectory();
      try {
        await initDatabase(path: p.join(documentDirectory.path, await getDatabaseName()));
      } catch (e, st) {
        AppLogger.log.severe('Database Error', e, st);
        return;
      }
      AppLogger.log.info("Database loaded.");

      await TimerService.initialize();
      AppLogger.log.info("TimerService initialized.");

      AppMethodChannel.instance.setMethodCallHandler(TimerService.instance.handleNativeCall);
      AppLogger.log.info("Native handler registered.");

      String label = await CustomTheme.load();
      CustomTheme theme = CustomTheme.fromLabel(label);
      ThemeData appTheme = AppThemes.getTheme(theme);
      ThemeData appDesign = AppDesign.getDesign(appTheme);
      AppLogger.log.info("App design loaded.");

      AppLogger.log.info("Starting app...");
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

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        FlutterNativeSplash.remove();

        if (GlobalErrorDialog.hasPendingError) {
          GlobalErrorDialog.show();
          return;
        }

        // Tells native platform that Flutter is now
        // ready to receive a pending alarm.
        await AppMethodChannel.instance.invokeMethod('flutterReady');
      });
    },
    (error, stack) {
      AppLogger.log.severe("Zone Error", error, stack);
      //GlobalErrorDialog.show();
    },
  );

  //TODO uncomment global error catchers
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

  late final AppLifecycleListener _lifecycleListener;

  CustomTheme get currentTheme => _currentTheme;

  @override
  void initState() {
    super.initState();
    _themeData = widget.theme;
    _currentTheme = widget.currentTheme;

    _lifecycleListener = AppLifecycleListener(onResume: () => PermissionManager.instance.verifyPermissions());
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
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
    String tutorialMode = await selectOne(sql: "SELECT value FROM settings WHERE key = 'tutorial'");

    if (tutorialMode == 'true') {
      return OnboardingScreen(startPage: 0);
    } else if (!await PermissionManager.instance.hasAllNeededPermissions()) {
      return OnboardingScreen(startPage: 2);
    } else {
      switch (TimerService.instance.activeTimer.run.state) {
        case TimerState.warning:
          return PreAlertWarningScreen();
        case TimerState.expired:
          return EmergencyActiveScreen();
        default:
          return HomeScreen();
      }
    }
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

    return MaterialApp(
      navigatorObservers: [routeObserver],
      navigatorKey: PermissionManager.instance.navigatorKey,
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
          splash: CustomSplash().splash(_themeData.colorScheme),
          screenFunction: () => getLandingPage(),
          splashTransition: SplashTransition.fadeTransition,
          pageTransitionType: PageTransitionType.rightToLeft,
          backgroundColor: _themeData.colorScheme.surface,
        ),
      ),
      builder: FToastBuilder(),
    );
  }
}

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
