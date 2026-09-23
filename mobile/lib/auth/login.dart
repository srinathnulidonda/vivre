// lib/auth/login.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_exception.dart';
import '../api/auth/auth_api.dart';
import '../app/home/home.dart';
import '../onboarding/shared.dart';
import 'forgot_password.dart';
import 'register.dart';
import 'shared.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  void _handleForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
    );
  }

  void _handleAppleSignIn() => showComingSoon(context, 'Apple sign-in');
  void _handleTerms() => showComingSoon(context, 'Terms of Service');
  void _handlePrivacy() => showComingSoon(context, 'Privacy Policy');

  Future<void> _handleSignIn() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting || _isGoogleSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      final user = await AuthRepository.instance.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage(userName: user.name)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, e.message);
      if (e.isUnauthorized) {
        _passwordController.clear();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackBar(context, 'Something went wrong. Please try again.');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isSubmitting || _isGoogleSubmitting) return;
    setState(() => _isGoogleSubmitting = true);

    try {
      final user = await AuthRepository.instance.signInWithGoogle();

      if (!mounted) return;
      setState(() => _isGoogleSubmitting = false);
      if (user == null) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage(userName: user.name)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleSubmitting = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isGoogleSubmitting = false);
      showErrorSnackBar(context, 'Google sign-in failed. Please try again.');
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
                      onPressed: isBusy ? null : _goToSignUp,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sign up',
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
                    'Welcome back',
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
                    'Sign in to continue your journey.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: kBodyGray),
                  ),
                  const SizedBox(height: 18),
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
                    textInputAction: TextInputAction.done,
                    validator: validatePasswordField,
                    onSubmitted: (_) => _handleSignIn(),
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
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isBusy ? null : _handleForgotPassword,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: kAccentBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthPrimaryButton(
                    label: 'Sign in',
                    isLoading: _isSubmitting,
                    onPressed: isBusy ? null : _handleSignIn,
                  ),
                  const SizedBox(height: 16),
                  const AuthOrDivider(),
                  const SizedBox(height: 16),
                  AuthSocialButton(
                    label: _isGoogleSubmitting
                        ? 'Signing in...'
                        : 'Continue with Google',
                    onTap: isBusy ? null : _handleGoogleSignIn,
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
                    onTap: isBusy ? null : _handleAppleSignIn,
                    leading: const Icon(
                      Icons.apple,
                      size: 22,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AuthTermsFooter(
                    actionText: 'signing in',
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