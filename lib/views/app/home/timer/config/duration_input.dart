import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:still_alive/services/timer_service.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';

/// A widget that allows the user to enter a duration using hours, minutes,
/// and seconds, or select a duration from a list of predefined presets.
///
/// The duration is displayed as three separate editable fields in the
/// `HH:MM:SS` format. Minutes and seconds are limited to a maximum value of
/// 59, while hours can be configured to support values up to 999.
///
/// Selecting a preset updates the duration fields and highlights the selected
/// preset. If the user manually enters a duration that matches a preset,
/// that preset is automatically highlighted.
///
/// The [onChanged] callback is invoked whenever the duration changes.
class DurationInput extends StatefulWidget {
  /// Creates a duration input widget.
  ///
  /// The [durationTimer] value is used as the initial duration. If it is
  /// `null`, the widget defaults to 30 minutes.
  ///
  /// The [onChanged] callback is invoked whenever the user changes the
  /// duration or selects a preset.
  const DurationInput({
    super.key,
    required this.durationTimer,
    required this.onChanged,
  });

  /// The initial duration displayed by the widget.
  ///
  /// If `null`, the duration defaults to 30 minutes.
  final Duration? durationTimer;

  /// Called whenever the duration changes.
  ///
  /// The callback receives the current [Duration] represented by the
  /// hours, minutes, and seconds fields.
  final ValueChanged<Duration> onChanged;

  @override
  State<DurationInput> createState() => _DurationInputState();
}

/// State implementation for [DurationInput].
///
/// Manages the text controllers, focus nodes, preset selection, and duration
/// changes for the parent [DurationInput] widget.
class _DurationInputState extends State<DurationInput> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;

  late final FocusNode _hoursFocus;
  late final FocusNode _minutesFocus;
  late final FocusNode _secondsFocus;

  final _presets = [
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
  ];

  int? _selectedPresetIndex;

  @override
  void initState() {
    super.initState();

    _hoursController = TextEditingController();
    _minutesController = TextEditingController();
    _secondsController = TextEditingController();

    _hoursFocus = FocusNode();
    _minutesFocus = FocusNode();
    _secondsFocus = FocusNode();

    Duration seconds = widget.durationTimer ?? const Duration(minutes: 30);
    _setDuration(seconds);

    for (var i = 0; i < _presets.length; i++) {
      if (_presets[i] == seconds) {
        _selectedPresetIndex = i;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onChanged(_presets[i]);
        });

        break;
      }
    }
  }

  Duration _currentDuration() {
    return Duration(
      hours: int.tryParse(_hoursController.text) ?? 0,
      minutes: int.tryParse(_minutesController.text) ?? 0,
      seconds: int.tryParse(_secondsController.text) ?? 0,
    );
  }

  void _setDuration(Duration duration, {bool notify = true}) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    _hoursController.text = hours.toString().padLeft(2, '0');
    _minutesController.text = minutes.toString().padLeft(2, '0');
    _secondsController.text = seconds.toString().padLeft(2, '0');

    if (notify) {
      widget.onChanged(duration);
    }
  }

  void _onFieldChanged() {
    final duration = _currentDuration();

    int? matchingPreset;

    for (var i = 0; i < _presets.length; i++) {
      if (_presets[i] == duration) {
        matchingPreset = i;
        break;
      }
    }

    setState(() {
      _selectedPresetIndex = matchingPreset;
    });

    widget.onChanged(duration);

    _moveToNextField();
  }

  void _moveToNextField() {
    if (_hoursFocus.hasFocus && _hoursController.text.length >= 3) {
      _minutesFocus.requestFocus();
    } else if (_minutesFocus.hasFocus && _minutesController.text.length >= 2) {
      _secondsFocus.requestFocus();
    }
  }

  void _selectPreset(int index) {
    final duration = _presets[index];

    _setDuration(duration);

    setState(() {
      _selectedPresetIndex = index;
    });
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();

    _hoursFocus.dispose();
    _minutesFocus.dispose();
    _secondsFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.ms,
      ),
      child: Column(
        children: [
          FormField(
            builder: (field) => Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TimeField(
                        controller: _hoursController,
                        focusNode: _hoursFocus,
                        onChanged: (_) => _onFieldChanged(),
                        maxValue: 999,
                        nextFocus: _minutesFocus,
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: Text(
                          ':',
                          style: AppText.display(scheme).copyWith(fontSize: 44),
                        ),
                      ),

                      _TimeField(
                        controller: _minutesController,
                        focusNode: _minutesFocus,
                        onChanged: (_) => _onFieldChanged(),
                        maxValue: 59,
                        previousFocus: _hoursFocus,
                        nextFocus: _secondsFocus,
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: Text(
                          ':',
                          style: AppText.display(scheme).copyWith(fontSize: 44),
                        ),
                      ),

                      _TimeField(
                        controller: _secondsController,
                        focusNode: _secondsFocus,
                        onChanged: (_) => _onFieldChanged(),
                        maxValue: 59,
                        previousFocus: _minutesFocus,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    local.translate("timer_configuration.duration.time_format"),
                    style: AppText.micro(
                      scheme,
                    ).copyWith(letterSpacing: 2, color: scheme.onSurface),
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        field.errorText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            validator: (_) {
              Duration value = _currentDuration();
              if (value.inSeconds < 10) {
                return local.translate(
                  "timer_configuration.duration.validation",
                );
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < _presets.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final isSelected = _selectedPresetIndex == i;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isSelected ? null : () => _selectPreset(i),
                      child: Container(
                        width: 50,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.primary
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          TimerService.formatDuration(_presets[i]),
                          style: AppText.bodySm(scheme).copyWith(
                            color: isSelected
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// An editable field for entering an individual duration component.
///
/// The field accepts numeric input and restricts the value to [maxValue].
/// It can optionally move focus to the previous or next duration field.
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.maxValue,
    this.previousFocus,
    this.nextFocus,
  });

  /// Controls the text displayed in the field.
  final TextEditingController controller;

  /// Controls the field's focus state.
  final FocusNode focusNode;

  /// Called when the value in the field changes.
  final ValueChanged<String> onChanged;

  /// The maximum numeric value allowed in the field.
  final int maxValue;

  /// The focus node to move to when navigating to the previous field.
  final FocusNode? previousFocus;

  /// The focus node to move to when navigating to the next field.
  final FocusNode? nextFocus;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: (controller.text.length > 2) ? 88 : 64,
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: (maxValue > 59) ? 3 : 2,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          style: AppText.display(scheme).copyWith(fontSize: 44),
          cursorColor: scheme.primary,
          scrollPadding: const EdgeInsets.all(0),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _MaxValueFormatter(maxValue),
          ],
          decoration: InputDecoration(
            hintText: "00",
            hintStyle: AppText.display(
              scheme,
            ).copyWith(fontSize: 44, color: scheme.onSurfaceVariant),
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xxxs,
              vertical: AppSpacing.xxxs,
            ),
            filled: false,
            fillColor: Colors.transparent,
          ),
          onChanged: onChanged,
          onTap: () {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          },
          onTapOutside: (event) {
            String value = controller.text;
            if (value.length <= 1) {
              value = (value.length == 1) ? "0$value" : "00";
              controller.text = value;
            }
          },
          onSubmitted: (value) {
            if (value.length <= 1) {
              value = (value.length == 1) ? "0$value" : "00";
              controller.text = value;
            }
            if (nextFocus != null) {
              nextFocus!.requestFocus();
            } else {
              focusNode.unfocus();
            }
          },
        ),
      ),
    );
  }
}

/// An input formatter that prevents a numeric value from exceeding
/// a specified maximum.
///
/// Empty values are allowed to support normal text editing. Invalid or
/// out-of-range values are rejected and the previous value is retained.
class _MaxValueFormatter extends TextInputFormatter {
  /// Creates a formatter with the given [maxValue].
  const _MaxValueFormatter(this.maxValue);

  /// The maximum numeric value accepted by the formatter.
  final int maxValue;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(newValue.text);

    if (value == null || value > maxValue) {
      return oldValue;
    }

    return newValue;
  }
}
