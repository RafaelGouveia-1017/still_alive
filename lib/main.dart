import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:still_alive/src/rust/frb_generated.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:still_alive/src/rust/api/main.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/src/rust/api/data/theme.dart';
import 'package:still_alive/data/app_design.dart';
import 'package:still_alive/data/app_themes.dart';
import 'package:still_alive/views/theme_page.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await RustLib.init();

  Directory documentDirectory = await getApplicationDocumentsDirectory();
  await initDatabase(
    path: p.join(documentDirectory.path, await getDatabaseName()),
  );

  String label = await CustomTheme.load();
  CustomTheme theme = await CustomTheme.fromLabel(s: label);
  ThemeData appTheme = AppThemes.getTheme(theme);
  ThemeData appDesign = AppDesign.getDesign(appTheme);

  runApp(MyApp(theme: appDesign));
}

class MyApp extends StatefulWidget {
  final ThemeData theme;

  const MyApp({super.key, required this.theme});

  @override
  State<MyApp> createState() => MyAppState();

  static MyAppState of(BuildContext context) {
    return context.findAncestorStateOfType<MyAppState>()!;
  }
}

class MyAppState extends State<MyApp> {
  late ThemeData _themeData;

  @override
  void initState() {
    super.initState();
    _themeData = widget.theme;
  }

  Future<void> changeTheme(CustomTheme theme) async {
    setState(() {
      _themeData = AppThemes.getTheme(theme);
    });

    await CustomTheme.save(label: await theme.label());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StillAlive',
      theme: _themeData,
      home: const MyHomePage(title: 'Dashboard'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    initialization();
  }

  void initialization() async {
    //do stuff...
    FlutterNativeSplash.remove();
  }

  int _counter = 0;
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _slideTransition() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ThemePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('You have pushed the button this many times:'),
            Text('$_counter', style: TextStyle(fontWeight: FontWeight.bold)),
            FutureBuilder<String>(
              future: greet(name: "Tom"),
              builder: (context, snapshot) {
                return Text(
                  'Action: Call Rust `greet("Tom")`\nResult: `${snapshot.data ?? "..."}`',
                );
              },
            ),
            Icon(LucideIcons.shield, size: 50.0),
            FilledButton.icon(
              icon: const Icon(LucideIcons.palette),
              label: const Text("Themes"),
              onPressed: _slideTransition,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(LucideIcons.plus),
      ),
    );
  }
}
