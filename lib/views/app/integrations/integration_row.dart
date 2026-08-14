import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Displays a single user or channel belonging to an integration.
///
/// The row provides actions for testing the connection and deleting the
/// corresponding integration record.
///
/// The parent widget is responsible for performing the actual test and
/// deletion operations through [onTest] and [onDelete]. The row manages the
/// temporary UI state of those operations, including loading indicators and
/// the result of a connection test.
class IntegrationRow extends StatefulWidget {
  const IntegrationRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.integrationKey,
    required this.channelId,
    required this.onTest,
    required this.onDelete,
    this.onAdd,
    this.selected = true,
    this.listMode = false,
  });

  final String title;
  final String? subtitle;
  final String integrationKey;
  final String channelId;
  final bool selected;
  final bool listMode;

  /// Tests the connection for this integration record.
  ///
  /// The returned result determines whether the test state displays a
  /// successful or failed connection indicator.
  final Future<({bool canSend, String message})> Function() onTest;

  /// Deletes the integration record represented by this row.
  ///
  /// The parent widget is responsible for updating its integration list
  /// after the deletion completes.
  final Future<void> Function() onDelete;

  /// Adds/restores the integration record represented by this row.
  ///
  /// The parent widget is responsible for performing the actual persistence
  /// operation and updating its integration list after the addition.
  final Future<void> Function()? onAdd;

  @override
  State<IntegrationRow> createState() => _IntegrationRowState();
}

/// State implementation for [IntegrationRow].
///
/// Tracks whether the connection test or deletion operation is currently
/// running and stores the result of the most recent connection test.
class _IntegrationRowState extends State<IntegrationRow> {
  bool _testing = false;
  bool _deleting = false;
  bool _adding = false;
  bool? _canSend;

  late bool _selected;

  @override
  void initState() {
    _selected = widget.selected;
    super.initState();
  }

  Future<void> _handleTest() async {
    if (_testing || _deleting) return;

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

  Future<void> _handleDelete() async {
    if (_testing || _deleting) return;

    setState(() {
      _deleting = true;
    });

    try {
      await widget.onDelete();
    } finally {
      if (mounted) {
        setState(() {
          _selected = false;
          _deleting = false;
        });
      }
    }
  }

  Future<void> _handleAdd() async {
    if (_testing || _deleting || _adding || _selected) return;

    setState(() {
      _adding = true;
    });

    try {
      await widget.onAdd!();
    } finally {
      setState(() {
        _selected = true;
        _adding = false;
      });
    }
  }

  Widget _buildTestButton(ColorScheme scheme) {
    if (_deleting) return SizedBox();

    if (_testing) {
      return Padding(
        padding: EdgeInsets.only(right: 20),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: CircularProgressIndicator(color: scheme.secondary),
          ),
        ),
      );
    }

    if (_canSend != null) {
      final connected = _canSend!;

      return IconButton(
        icon: Icon(
          connected ? LucideIcons.check : LucideIcons.x,
          size: 24,
          color: connected ? scheme.secondary : scheme.error,
        ),
        onPressed: null,
      );
    }

    return IconButton(
      icon: Icon(LucideIcons.flaskConical, size: 24, color: scheme.secondary),
      onPressed: _handleTest,
    );
  }

  Widget _buildDeleteButton(ColorScheme scheme) {
    if (_deleting) {
      return Padding(
        padding: EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.md,
          right: 44,
        ),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(child: CircularProgressIndicator(color: scheme.error)),
        ),
      );
    }

    return IconButton(
      icon: Icon(LucideIcons.trash2, size: 24, color: scheme.error),
      onPressed: _handleDelete,
    );
  }

  Widget _buildAddButton(ColorScheme scheme) {
    if (_adding) {
      return Padding(
        padding: EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.md,
          right: 44,
        ),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: CircularProgressIndicator(color: scheme.primary),
          ),
        ),
      );
    }

    return Icon(LucideIcons.plus, size: 24, color: scheme.primary);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget row = AppRow(
      title: widget.title,
      subtitle: widget.subtitle,
      padding: EdgeInsets.only(left: AppSpacing.xl),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: (!_selected && widget.listMode)
            ? [_buildAddButton(scheme)]
            : [
                _buildTestButton(scheme),
                const SizedBox(width: AppSpacing.md),
                _buildDeleteButton(scheme),
              ],
      ),
    );

    if (!_selected && widget.listMode) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleAdd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            0,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: row,
        ),
      );
    } else {
      return row;
    }
  }
}
