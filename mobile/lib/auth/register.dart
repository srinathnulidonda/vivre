// lib/auth/register.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_exception.dart';
import '../api/auth/auth_api.dart';
import '../app/home/home.dart';
import '../onboarding/shared.dart';
import 'login.dart';
import 'shared.dart';
import 'verify_otp.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToSignIn() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  void _handleAppleSignUp() => showComingSoon(context, 'Apple sign-up');
  void _handleTerms() => showComingSoon(context, 'Terms of Service');
  void _handlePrivacy() => showComingSoon(context, 'Privacy Policy');

  Future<void> _handleCreateAccount() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting || _isGoogleSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    final String email = _emailController.text.trim();

    try {
      await AuthRepository.instance.signup(
        email: email,
        password: _passwordController.text,
        name: _nameController.text.trim(),
        timezone: 'UTC',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyOtpPage(
            email: email,
            purpose: OtpPurpose.emailVerification,
            onVerified: (otp) {
              final user = AuthRepository.instance.currentUser;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => HomePage(userName: user?.name),
                ),
                (route) => false,
              );
            },
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Something went wrong. Please try again.');
    }
  }

  Future<void> _handleGoogleSignUp() async {
    if (_isSubmitting || _isGoogleSubmitting) return;
    setState(() => _isGoogleSubmitting = true);

    try {
      final user = await AuthRepository.instance.signInWithGoogle();

      if (!mounted) return;
      setState(() => _isGoogleSubmitting = false);
      if (user == null) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomePage(userName: user.name)),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isGoogleSubmitting = false);
      showErrorSnackBar(context, 'Google sign-up failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBusy = _isSubmitting || _isGoogleSubmitting;

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
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isBusy ? null : _goToSignIn,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          color: kAccentBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const AuthHeaderLogo(),
                  const SizedBox(height: 16),
                  const Text(
                    'Create account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: kDarkNavy,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign up to start your journey.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: kBodyGray),
                  ),
                  const SizedBox(height: 18),
                  AuthTextField(
                    controller: _nameController,
                    hint: 'Full name',
                    icon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    validator: validateNameField,
                  ),
                  const SizedBox(height: 10),
                  AuthTextField(
                    controller: _emailController,
                    hint: 'Email address',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: validateEmailField,
                  ),
                  const SizedBox(height: 10),
                  AuthTextField(
                    controller: _passwordController,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    validator: validatePasswordField,
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
                    hint: 'Confirm password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    validator: confirmPasswordValidator(_passwordController),
                    onSubmitted: (_) => _handleCreateAccount(),
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
                  const SizedBox(height: 16),
                  AuthPrimaryButton(
                    label: 'Create account',
                    isLoading: _isSubmitting,
                    onPressed: isBusy ? null : _handleCreateAccount,
                  ),
                  const SizedBox(height: 16),
                  const AuthOrDivider(),
                  const SizedBox(height: 16),
                  AuthSocialButton(
                    label: _isGoogleSubmitting
                        ? 'Signing up...'
                        : 'Continue with Google',
                    onTap: isBusy ? null : _handleGoogleSignUp,
                    leading: _isGoogleSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AuthGoogleIcon(),
                  ),
                  const SizedBox(height: 8),
                  AuthSocialButton(
                    label: 'Continue with Apple',
                    onTap: isBusy ? null : _handleAppleSignUp,
                    leading:
                        const Icon(Icons.apple, size: 22, color: Colors.black),
                  ),
                  const SizedBox(height: 14),
                  AuthTermsFooter(
                    actionText: 'creating an account',
                    onTerms: _handleTerms,
                    onPrivacy: _handlePrivacy,
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