import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/data/app_themes.dart';
import 'package:still_alive/main.dart';
import 'package:still_alive/src/rust/api/data/theme.dart';

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Themes")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: CustomTheme.values.length,
        itemBuilder: (context, index) {
          final theme = CustomTheme.values[index];
          final themeData = AppThemes.themeData(theme);

          return AbsorbPointer(
            absorbing: MyApp.of(context).widget.theme == themeData
                ? true
                : false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton(
                onPressed: () {
                  MyApp.of(context).changeTheme(theme);
                },
                child: FutureBuilder<String>(
                  future: theme.label(),
                  builder: (context, snapshot) {
                    return Text(snapshot.data ?? '...');
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
