// lib/auth/otp_field.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../onboarding/shared.dart';
import 'shared.dart';

class OtpInputField extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const OtpInputField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.autofocus = true,
  });

  @override
  State<OtpInputField> createState() => OtpInputFieldState();
}

class OtpInputFieldState extends State<OtpInputField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<FocusNode> _keyboardListenerNodes;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _keyboardListenerNodes =
        List.generate(widget.length, (_) => FocusNode(skipTraversal: true));
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final f in _keyboardListenerNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    widget.onChanged?.call('');
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _maybeComplete() {
    if (_code.length == widget.length) {
      FocusScope.of(context).unfocus();
      widget.onCompleted(_code);
    }
  }

  void _handleChange(int index, String value) {
    if (value.length > 1) {
      _distributePaste(value, index);
      return;
    }

    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    widget.onChanged?.call(_code);
    _maybeComplete();
  }

  void _distributePaste(String pasted, int startIndex) {
    final String digitsOnly = pasted.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return;

    final int available = widget.length - startIndex;
    final String toPlace = digitsOnly.length > available
        ? digitsOnly.substring(0, available)
        : digitsOnly;

    for (int i = 0; i < toPlace.length; i++) {
      _controllers[startIndex + i].value = TextEditingValue(
        text: toPlace[i],
        selection: const TextSelection.collapsed(offset: 1),
      );
    }

    final int lastFilled =
        (startIndex + toPlace.length - 1).clamp(0, widget.length - 1);
    final int nextEmpty = lastFilled + 1;
    if (nextEmpty < widget.length) {
      _focusNodes[nextEmpty].requestFocus();
    } else {
      _focusNodes[lastFilled].requestFocus();
    }

    widget.onChanged?.call(_code);
    _maybeComplete();
  }

  void _handleBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      widget.onChanged?.call(_code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return SizedBox(
          width: 46,
          height: 54,
          child: KeyboardListener(
            focusNode: _keyboardListenerNodes[index],
            onKeyEvent: (event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace) {
                _handleBackspace(index);
              }
            },
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              autofocus: widget.autofocus && index == 0,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints:
                  index == 0 ? const [AutofillHints.oneTimeCode] : null,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kDarkNavy,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: kAuthFieldFill,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kAuthFieldFill),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kAuthFieldFill),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kAccentBlue, width: 1.6),
                ),
              ),
              onChanged: (value) => _handleChange(index, value),
            ),
          ),
        );
      }),
    );
  }
}

class OtpResendTimer extends StatefulWidget {
  final Future<void> Function() onResend;
  final int seconds;

  const OtpResendTimer({
    super.key,
    required this.onResend,
    this.seconds = 60,
  });

  @override
  State<OtpResendTimer> createState() => _OtpResendTimerState();
}

class _OtpResendTimerState extends State<OtpResendTimer> {
  Timer? _timer;
  late int _remaining;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    if (_remaining <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining <= 1) {
        timer.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _handleResend() async {
    if (_remaining > 0 || _isResending) return;
    setState(() => _isResending = true);

    try {
      await widget.onResend();
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _remaining = widget.seconds;
      });
      _startCountdown();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canResend = _remaining == 0 && !_isResending;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Didn't receive the code?  ",
          style: TextStyle(color: kBodyGray, fontSize: 13.5),
        ),
        GestureDetector(
          onTap: canResend ? _handleResend : null,
          child: Text(
            _isResending
                ? 'Sending...'
                : (canResend ? 'Resend' : 'Resend in ${_remaining}s'),
            style: TextStyle(
              color: canResend ? kAccentBlue : kBodyGray.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }
}