// lib/auth/shared.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../onboarding/shared.dart';
import '../themes/app-colors.dart' show kAuthBorder, kAuthFieldFill;

export '../themes/app-colors.dart' show kAuthBorder, kAuthFieldFill;
export '../widgets/feedback.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmailField(String? value) {
  final String input = value?.trim() ?? '';
  if (input.isEmpty) return 'Enter your email address';
  if (!_emailPattern.hasMatch(input)) return 'Enter a valid email address';
  return null;
}

String? validateNameField(String? value) {
  final String input = value?.trim() ?? '';
  if (input.isEmpty) return 'Enter your full name';
  if (input.length < 2) return 'Name is too short';
  return null;
}

String? _validatePasswordLength(String value) {
  if (value.length < 8) return 'Password must be at least 8 characters';
  return null;
}

String? validatePasswordField(String? value) {
  if (value == null || value.isEmpty) return 'Enter your password';
  return _validatePasswordLength(value);
}

String? validateNewPasswordField(String? value) {
  if (value == null || value.isEmpty) return 'Enter a new password';
  return _validatePasswordLength(value);
}

String? Function(String?) confirmPasswordValidator(
  TextEditingController passwordController, {
  String emptyMessage = 'Confirm your password',
}) {
  return (String? value) {
    if (value == null || value.isEmpty) return emptyMessage;
    if (value != passwordController.text) return 'Passwords do not match';
    return null;
  };
}

class AuthHeaderLogo extends StatelessWidget {
  final double height;
  const AuthHeaderLogo({super.key, this.height = 68});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '$kAssetPath/logo.webp',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Vivre',
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.eco_rounded,
        size: height * 0.82,
        color: kAccentBlue,
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final AutovalidateMode autovalidateMode;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      autovalidateMode: autovalidateMode,
      style: const TextStyle(fontSize: 15, color: kDarkNavy),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kBodyGray, fontSize: 15),
        prefixIcon: Icon(icon, color: kBodyGray, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: kAuthFieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: kAuthFieldFill),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: kAuthFieldFill),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: kAccentBlue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: Color(0xFFD64545), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: Color(0xFFD64545), width: 1.4),
        ),
      ),
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: kAuthBorder, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              color: kBodyGray,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: kAuthBorder, thickness: 1)),
      ],
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  final String label;
  final Widget leading;
  final VoidCallback? onTap;

  const AuthSocialButton({
    super.key,
    required this.label,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: kAuthBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: kDarkNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthGoogleIcon extends StatelessWidget {
  const AuthGoogleIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/google.webp',
      width: 20,
      height: 20,
      errorBuilder: (context, error, stackTrace) => const Text(
        'G',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: kAccentBlue,
        ),
      ),
    );
  }
}

class AuthTermsFooter extends StatefulWidget {
  final String actionText;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  const AuthTermsFooter({
    super.key,
    required this.actionText,
    required this.onTerms,
    required this.onPrivacy,
  });

  @override
  State<AuthTermsFooter> createState() => _AuthTermsFooterState();
}

class _AuthTermsFooterState extends State<AuthTermsFooter> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer();
    _privacyRecognizer = TapGestureRecognizer();
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _termsRecognizer.onTap = widget.onTerms;
    _privacyRecognizer.onTap = widget.onPrivacy;

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12.5,
          color: kBodyGray,
          height: 1.4,
        ),
        children: [
          TextSpan(text: 'By ${widget.actionText}, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: const TextStyle(
              color: kAccentBlue,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: const TextStyle(
              color: kAccentBlue,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccentBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kAccentBlue.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
      ),
    );
  }
}