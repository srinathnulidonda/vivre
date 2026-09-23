// lib/auth/forgot_password.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_exception.dart';
import '../api/auth/auth_api.dart';
import '../onboarding/shared.dart';
import 'reset_password.dart';
import 'shared.dart';
import 'verify_otp.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    final String email = _emailController.text.trim();

    try {
      await AuthRepository.instance.forgotPassword(email: email);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyOtpPage(
            email: email,
            purpose: OtpPurpose.passwordReset,
            onVerified: (otp) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ResetPasswordPage(email: email, otp: otp),
                ),
              );
            },
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (e.isConflict) {
        showErrorSnackBar(
          context,
          'A code was already sent recently. Please wait before trying again.',
        );
      } else if (e.isRateLimited) {
        showErrorSnackBar(
          context,
          'Too many attempts. Please wait a moment and try again.',
        );
      } else {
        showErrorSnackBar(context, e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Something went wrong. Please try again.');
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
            child: Form(
              key: _formKey,
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
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: kAccentBlue,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Forgot password?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: kDarkNavy,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "No worries. Enter your email and we'll send you a code to reset it.",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13.5, color: kBodyGray, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AuthTextField(
                    controller: _emailController,
                    hint: 'Email address',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: validateEmailField,
                    onSubmitted: (_) => _handleSendCode(),
                  ),
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    label: 'Send code',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _handleSendCode,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}