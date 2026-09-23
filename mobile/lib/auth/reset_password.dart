// lib/auth/reset_password.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_exception.dart';
import '../api/auth/auth_api.dart';
import '../onboarding/shared.dart';
import 'login.dart';
import 'shared.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String otp;

  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      await AuthRepository.instance.resetPassword(
        email: widget.email,
        otp: widget.otp,
        newPassword: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      HapticFeedback.mediumImpact();
      _showSuccessDialog();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (e.isValidationError) {
        showErrorSnackBar(
          context,
          'This code is invalid or has expired. Please request a new one.',
        );
        Navigator.of(context).pop();
      } else {
        showErrorSnackBar(context, e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Something went wrong. Please try again.');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFDFF3E3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF2F6B3F),
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Password reset!',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: kDarkNavy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your password has been reset successfully. You can now sign in with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: kBodyGray, height: 1.4),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: AuthPrimaryButton(
                  label: 'Back to Sign in',
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                      Icons.password_rounded,
                      color: kAccentBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Set new password',
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
                      'Your new password must be different from previously used passwords.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13.5, color: kBodyGray, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AuthTextField(
                    controller: _passwordController,
                    hint: 'New password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    validator: validateNewPasswordField,
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: kBodyGray,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AuthTextField(
                    controller: _confirmPasswordController,
                    hint: 'Confirm new password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    validator: confirmPasswordValidator(
                      _passwordController,
                      emptyMessage: 'Confirm your new password',
                    ),
                    onSubmitted: (_) => _handleResetPassword(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: kBodyGray,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    label: 'Reset password',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _handleResetPassword,
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