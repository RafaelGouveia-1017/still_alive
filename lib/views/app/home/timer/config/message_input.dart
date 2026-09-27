import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';

class MessageInput extends StatefulWidget {
  const MessageInput({super.key, required this.isNew, required this.message, required this.onChanged});

  final bool isNew;
  final String? message;
  final ValueChanged<String?> onChanged;

  @override
  State<MessageInput> createState() => _MessageInputState();
}

/// State implementation for [MessageInput].
class _MessageInputState extends State<MessageInput> {
  late final TextEditingController _messageController;
  late final FocusNode _messageFocus;

  bool _isLoading = true;
  late bool _wantMessage;

  @override
  void initState() {
    super.initState();

    _messageController = TextEditingController();
    _messageFocus = FocusNode();

    _messageFocus.addListener(() {
      if (_messageFocus.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_messageFocus.context != null) {
            Scrollable.ensureVisible(_messageFocus.context!, duration: AppMotion.fasterer, alignment: 0.3);
          }
        });
      }
    });

    if (widget.isNew) {
      _wantMessage = true;
      loadPref();
    } else {
      _wantMessage = (widget.message != null && widget.message!.isNotEmpty);
      _messageController.text = widget.message ?? '';
      _isLoading = false;
    }
  }

  void loadPref() async {
    String value = await selectOne(sql: "SELECT value FROM settings WHERE key = 'message'");

    widget.onChanged(value);

    setState(() {
      _messageController.text = value;
      _isLoading = false;
    });
  }

  void _setWantMessage(bool value) {
    if (_wantMessage == value) return;

    setState(() {
      _wantMessage = value;
    });

    if (!value) {
      _onMessageChanged('');
      _messageFocus.unfocus();
    }
  }

  void _onMessageChanged(String value) {
    String? text = value;
    if (text.isEmpty) text = null;

    widget.onChanged(text);

    setState(() {});
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: (_isLoading)
          ? SizedBox(
              width: 40,
              height: 40,
              child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
            )
          : Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => (_messageFocus.hasFocus) ? _messageFocus.unfocus() : _setWantMessage(!_wantMessage),
                  child: AppRow(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs, horizontal: AppSpacing.sm),
                    title: (_wantMessage)
                        ? local.translate("timer_configuration.message.requirement.on")
                        : local.translate("timer_configuration.message.requirement.off"),
                    icon: (_wantMessage) ? LucideIcons.lock : LucideIcons.lockOpen,
                    iconColor: scheme.secondary,
                    trailing: (_messageFocus.hasFocus)
                        ? Container(
                            width: 35,
                            height: 35,
                            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Icon(LucideIcons.check, size: 24, color: scheme.tertiary),
                          )
                        : AppToggle(on: _wantMessage),
                  ),
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: AppMotion.fasterer,
                    curve: AppMotion.easeInOut,
                    alignment: Alignment.topCenter,
                    child: !_wantMessage
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _messageFocus.requestFocus(),
                            child: Column(
                              children: [
                                const SizedBox(height: AppSpacing.md),
                                TextFormField(
                                  controller: _messageController,
                                  focusNode: _messageFocus,
                                  keyboardType: TextInputType.multiline,
                                  maxLines: 15,
                                  maxLength: 800,
                                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                                  style: AppText.caption(scheme).copyWith(color: scheme.onSurface),
                                  cursorColor: scheme.primary,
                                  scrollPadding: const EdgeInsets.all(0),
                                  decoration: InputDecoration(
                                    hintText: local.translate("timer_configuration.message.hint"),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxs, vertical: AppSpacing.xxxs),
                                    border: OutlineInputBorder(),
                                    filled: false,
                                    fillColor: Colors.transparent,
                                  ),
                                  onChanged: _onMessageChanged,
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
                                      return local.translate("timer_configuration.message.validation");
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
