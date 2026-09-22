import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';

/// A text input widget for entering and editing a name.
///
/// The [NameInput] widget displays a single-line text field and notifies
/// [onChanged] whenever the entered name changes.
class NameInput extends StatefulWidget {
  const NameInput({super.key, required this.name, required this.onChanged});

  final String? name;
  final ValueChanged<String> onChanged;

  @override
  State<NameInput> createState() => _NameInputState();
}

/// State implementation for [NameInput].
///
/// Manages the text editing controller and focus node used by the name
/// input field.
class _NameInputState extends State<NameInput> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;

  late String _name;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _nameFocus = FocusNode();

    _name = widget.name ?? '';
    _nameController.text = _name;
    widget.onChanged(_name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.ms),
      child: TextFormField(
        controller: _nameController,
        focusNode: _nameFocus,
        keyboardType: TextInputType.visiblePassword,
        maxLength: 250,
        minLines: 1,
        maxLines: null,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        style: AppText.body(scheme),
        cursorColor: scheme.primary,
        scrollPadding: const EdgeInsets.all(0),
        inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
        decoration: InputDecoration(
          hintText: (_name.isNotEmpty) ? '' : local.translate("timer_configuration.name.hint"),
          hintStyle: AppText.body(scheme).copyWith(color: scheme.onSurfaceVariant),
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          filled: false,
          fillColor: Colors.transparent,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(LucideIcons.pencil, size: 18),
          ),
          prefixIconConstraints: BoxConstraints.tightFor(width: 30),
          isDense: true,
        ),
        onChanged: (value) {
          widget.onChanged.call(value);
          setState(() => _name = value);
        },
        onTap: () {
          _nameController.selection = TextSelection(baseOffset: 0, extentOffset: _nameController.text.length);
        },
        errorBuilder: (context, errorText) => Align(
          alignment: Alignment.bottomCenter,
          child: Text(
            errorText,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return local.translate("timer_configuration.name.validation");
          }
          return null;
        },
      ),
    );
  }
}
