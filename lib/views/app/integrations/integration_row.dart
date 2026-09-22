import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// A row representing a destination belonging to an integration.
///
/// The row provides actions for testing the destination connection and
/// generating a QR code that can be scanned to access the destination.
class IntegrationRow extends StatefulWidget {
  const IntegrationRow({super.key, required this.title, required this.subtitle, required this.onTest, required this.getExtLink});

  final String title;
  final String? subtitle;

  /// Tests the connection for this integration record.
  ///
  /// The returned result determines whether the test state displays a
  /// successful or failed connection indicator.
  final Future<({bool canSend, String message})> Function() onTest;

  /// Gets the URI for external link.
  final Uri Function() getExtLink;

  @override
  State<IntegrationRow> createState() => _IntegrationRowState();
}

/// State implementation for [IntegrationRow].
class _IntegrationRowState extends State<IntegrationRow> {
  bool _testing = false;
  bool? _canSend;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleTest() async {
    if (_testing) return;

    setState(() {
      _testing = true;
    });

    try {
      final result = await widget.onTest();

      if (!mounted) return;

      setState(() {
        _canSend = result.canSend;
        _testing = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _canSend = false;
        _testing = false;
      });
    }
  }

  Widget _buildTestButton(ColorScheme scheme) {
    if (_testing) {
      return Padding(
        padding: EdgeInsets.only(right: 20),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
        ),
      );
    }

    if (_canSend != null) {
      final connected = _canSend!;

      return IconButton(
        icon: Icon(connected ? LucideIcons.check : LucideIcons.x, size: 24, color: connected ? scheme.tertiary : scheme.error),
        onPressed: null,
      );
    }

    return IconButton(
      icon: Icon(LucideIcons.flaskConical, size: 24, color: scheme.tertiary),
      onPressed: _handleTest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppRow(
      title: widget.title,
      subtitle: widget.subtitle,
      padding: EdgeInsets.only(left: AppSpacing.xl),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTestButton(scheme),
          IconButton(
            icon: Icon(LucideIcons.externalLink, size: 24, color: scheme.secondary),
            onPressed: () {
              try {
                launchUrl(widget.getExtLink());
              } catch (e, st) {
                AppLogger.log.severe("Bruh has no app that can open an app schema. smh", e, st);
              }
            },
          ),
        ],
      ),
    );
  }
}
