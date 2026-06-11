import 'package:flutter/material.dart';
import 'package:still_alive/src/rust/api/simple.dart';
import 'package:still_alive/src/rust/frb_generated.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

Future<void> main() async {
  await RustLib.init();
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Quickstart')),
        body: Center(
          child: Column(
            mainAxisAlignment: .center,
            children: [
              Text(
                'Action: Call Rust `greet("Tom")`\nResult: `${greet(name: "Tom")}`',
              ),
              Icon(LucideIcons.shield, size: 50.0),
            ],
          ),
        ),
      ),
    );
  }
}
