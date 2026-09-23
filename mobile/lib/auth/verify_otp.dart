// lib/auth/verify_otp.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_exception.dart';
import '../api/auth/auth_api.dart';
import '../onboarding/shared.dart';
import 'otp_field.dart';
import 'shared.dart';

enum OtpPurpose { passwordReset, emailVerification }

class VerifyOtpPage extends StatefulWidget {
  final String email;
  final OtpPurpose purpose;
  final ValueChanged<String> onVerified;

  const VerifyOtpPage({
    super.key,
    required this.email,
    required this.purpose,
    required this.onVerified,
  });

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final GlobalKey<OtpInputFieldState> _otpKey = GlobalKey<OtpInputFieldState>();
  String _code = '';
  bool _isVerifying = false;
  String? _errorText;

  bool get _isEmailVerification =>
      widget.purpose == OtpPurpose.emailVerification;

  Future<void> _handleVerify(String code) async {
    if (_isVerifying) return;

    if (widget.purpose == OtpPurpose.passwordReset) {
      HapticFeedback.selectionClick();
      widget.onVerified(code);
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      await AuthRepository.instance.confirmEmailVerification(
        email: widget.email,
        otp: code,
      );

      if (!mounted) return;
      setState(() => _isVerifying = false);

      HapticFeedback.selectionClick();
      widget.onVerified(code);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorText = e.message;
      });
      _otpKey.currentState?.clear();
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorText = 'Something went wrong. Please try again.';
      });
      _otpKey.currentState?.clear();
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _handleResend() async {
    try {
      if (_isEmailVerification) {
        await AuthRepository.instance
            .requestEmailVerification(email: widget.email);
      } else {
        await AuthRepository.instance.forgotPassword(email: widget.email);
      }
    } on ApiException catch (e) {
      if (mounted) showErrorSnackBar(context, e.message);
      rethrow;
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Unable to resend the code. Please try again.',
        );
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: kPageBg,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: kPageBg,
      ),
      child: Scaffold(
        backgroundColor: kPageBg,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: kDarkNavy),
                  ),
                ),
                const SizedBox(height: 8),
                const AuthHeaderLogo(height: 60),
                const SizedBox(height: 20),
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kAccentBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isEmailVerification
                        ? Icons.mark_email_read_outlined
                        : Icons.password_rounded,
                    color: kAccentBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _isEmailVerification
                      ? 'Verify your email'
                      : 'Enter verification code',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: kDarkNavy,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: kBodyGray,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: "We've sent a 6-digit code to "),
                        TextSpan(
                          text: widget.email,
                          style: const TextStyle(
                            color: kDarkNavy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                OtpInputField(
                  key: _otpKey,
                  onChanged: (value) {
                    setState(() {
                      _code = value;
                      if (_errorText != null) _errorText = null;
                    });
                  },
                  onCompleted: _handleVerify,
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD64545),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                AuthPrimaryButton(
                  label: 'Verify',
                  isLoading: _isVerifying,
                  onPressed:
                      _code.length == 6 ? () => _handleVerify(_code) : null,
                ),
                const SizedBox(height: 18),
                OtpResendTimer(onResend: _handleResend),
              ],
            ),
          ),
        ),
      ),
    );
  }
}