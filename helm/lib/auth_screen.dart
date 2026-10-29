import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/invite_service.dart';

enum AuthViewMode {
  passwordSignIn,
  otpEmail,
  otpVerify,
  setPasswordAndProfile,
  forgotPassword,
  resetPasswordOtp,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  static bool isCompletingSetup = false;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  AuthViewMode _mode = AuthViewMode.passwordSignIn;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;

  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    AuthScreen.isCompletingSetup = false;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  void _switchMode(AuthViewMode mode) {
    setState(() {
      _mode = mode;
      _errorMessage = null;
      _successMessage = null;
      _formKey.currentState?.reset();
    });
  }

  // 1. Password Sign In
  Future<void> _handlePasswordSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Handle pending invite if present
      final pendingId = InviteService().pendingCommunityId;
      if (pendingId != null) {
        unawaited(InviteService().processJoin(pendingId));
        InviteService().pendingCommunityId = null;
      }

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Sign in failed. Check credentials and retry.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Request OTP Code for First-Time Login
  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: kIsWeb ? null : 'waypoint://login-callback',
        shouldCreateUser: true,
      );

      if (mounted) {
        _otpController.clear();
        _startResendTimer();
        _switchMode(AuthViewMode.otpVerify);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to send verification code. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. Verify OTP Code
  Future<void> _handleVerifyOtp() async {
    final email = _emailController.text.trim();
    final token = _otpController.text.trim();

    if (token.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code sent to your email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      AuthResponse? response;
      try {
        response = await Supabase.instance.client.auth.verifyOTP(
          email: email,
          token: token,
          type: OtpType.email,
        );
      } on AuthException {
        // Fallback for new user signup OTP confirmation
        response = await Supabase.instance.client.auth.verifyOTP(
          email: email,
          token: token,
          type: OtpType.signup,
        );
      }

      if (mounted && response.session != null) {
        AuthScreen.isCompletingSetup = true;
        _passwordController.clear();
        _confirmPasswordController.clear();
        _switchMode(AuthViewMode.setPasswordAndProfile);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Invalid or expired code. Please retry.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 4. Set Password & Full Name for First-Time Setup
  Future<void> _handleCompleteSetup() async {
    if (!_formKey.currentState!.validate()) return;

    final fullName = _fullNameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: password,
          data: {'full_name': fullName},
        ),
      );

      // Process pending community invite if any
      final pendingId = InviteService().pendingCommunityId;
      if (pendingId != null) {
        unawaited(InviteService().processJoin(pendingId));
        InviteService().pendingCommunityId = null;
      }

      AuthScreen.isCompletingSetup = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account setup complete! Welcome to Waypoint.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF88C0A4),
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to update account. Please retry.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 5. Request Password Reset Email
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : 'waypoint://login-callback',
      );

      if (mounted) {
        _otpController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _switchMode(AuthViewMode.resetPasswordOtp);
        setState(() {
          _successMessage = 'Reset code sent to $email. Enter it below with your new password.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to send reset code. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 6. Verify Reset Code & Set New Password
  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final token = _otpController.text.trim();
    final newPassword = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully! Please sign in.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF88C0A4),
          ),
        );
        _switchMode(AuthViewMode.passwordSignIn);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Password reset failed. Check the code and retry.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasPendingInvite = InviteService().pendingCommunityId != null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon / Logo
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.change_history,
                      size: 54,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pending Community Invite Banner
                  if (hasPendingInvite) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF88C0A4).withValues(alpha: 0.12),
                        border: Border.all(color: const Color(0xFF88C0A4).withValues(alpha: 0.6)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.group_add_outlined, color: Color(0xFF88C0A4), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Community invite detected. Authenticate to join.',
                              style: textTheme.bodySmall?.copyWith(color: const Color(0xFF88C0A4), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Inline Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  // Inline Success Banner
                  if (_successMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF88C0A4).withValues(alpha: 0.1),
                        border: Border.all(color: const Color(0xFF88C0A4).withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Color(0xFF88C0A4), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  // Dynamic Form Body based on Active View Mode
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildModeContent(context, colorScheme, textTheme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeContent(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    switch (_mode) {
      case AuthViewMode.passwordSignIn:
        return _buildPasswordSignInView(colorScheme, textTheme);
      case AuthViewMode.otpEmail:
        return _buildOtpEmailView(colorScheme, textTheme);
      case AuthViewMode.otpVerify:
        return _buildOtpVerifyView(colorScheme, textTheme);
      case AuthViewMode.setPasswordAndProfile:
        return _buildSetPasswordAndProfileView(colorScheme, textTheme);
      case AuthViewMode.forgotPassword:
        return _buildForgotPasswordView(colorScheme, textTheme);
      case AuthViewMode.resetPasswordOtp:
        return _buildResetPasswordOtpView(colorScheme, textTheme);
    }
  }

  // 1. Password Sign In View (Default)
  Widget _buildPasswordSignInView(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      key: const ValueKey('password_sign_in_view'),
      children: [
        Text('Welcome Back', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Sign in to access your Waypoint workspace.', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),

        TextFormField(
          controller: _emailController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
            hintText: 'name@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final val = v?.trim() ?? '';
            if (val.isEmpty) return 'Enter email';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(val)) return 'Enter a valid email';
            return null;
          },
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
          onFieldSubmitted: (_) => _handlePasswordSignIn(),
        ),
        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _switchMode(AuthViewMode.forgotPassword),
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePasswordSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(child: Divider(color: colorScheme.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
            ),
            Expanded(child: Divider(color: colorScheme.outlineVariant)),
          ],
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _switchMode(AuthViewMode.otpEmail),
            icon: const Icon(Icons.mark_email_read_outlined),
            label: const Text('First time here? Sign up with Email OTP'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // 2. OTP Step 1: Request Code
  Widget _buildOtpEmailView(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      key: const ValueKey('otp_email_view'),
      children: [
        Text('First-Time Sign Up', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('We will send a 6-digit code to verify your email.', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),

        TextFormField(
          controller: _emailController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
            hintText: 'name@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
          onFieldSubmitted: (_) => _handleSendOtp(),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('SEND 6-DIGIT CODE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ),
        ),
        const SizedBox(height: 16),

        TextButton(
          onPressed: () => _switchMode(AuthViewMode.passwordSignIn),
          child: const Text('Already have an account? Sign In with Password'),
        ),
      ],
    );
  }

  // 3. OTP Step 2: Code Verification
  Widget _buildOtpVerifyView(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      key: const ValueKey('otp_verify_view'),
      children: [
        Text('Verify Email', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          'Enter the 6-digit code sent to ${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => _switchMode(AuthViewMode.otpEmail),
          child: const Text('Wrong email? Change', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _otpController,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            hintText: '------',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          onChanged: (val) {
            if (val.length == 6) {
              _handleVerifyOtp();
            }
          },
          onFieldSubmitted: (_) => _handleVerifyOtp(),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Did not receive code? ', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
            if (_resendCountdown > 0)
              Text('Resend in ${_resendCountdown}s', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
            else
              TextButton(
                onPressed: _isLoading ? null : _handleSendOtp,
                child: const Text('Resend Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleVerifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('VERIFY & CONTINUE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ),
        ),
      ],
    );
  }

  // 4. OTP Step 3: Set Password & Profile
  Widget _buildSetPasswordAndProfileView(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      key: const ValueKey('set_password_and_profile_view'),
      children: [
        Text('Create Password', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Set your display name and password for subsequent logins.', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),

        TextFormField(
          controller: _fullNameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
            hintText: 'Jane Doe',
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter your full name' : null,
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Create Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          obscureText: _obscureConfirmPassword,
          validator: (v) {
            if (v != _passwordController.text) return 'Passwords do not match';
            return null;
          },
          onFieldSubmitted: (_) => _handleCompleteSetup(),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleCompleteSetup,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('COMPLETE SETUP', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ),
        ),
      ],
    );
  }

  // 5. Forgot Password View
  Widget _buildForgotPasswordView(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      key: const ValueKey('forgot_password_view'),
      children: [
        Text('Reset Password', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Enter your email to receive a password reset code.', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),

        TextFormField(
          controller: _emailController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
            hintText: 'name@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
          onFieldSubmitted: (_) => _handleForgotPassword(),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleForgotPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('SEND RESET CODE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ),
        ),
        const SizedBox(height: 16),

        TextButton(
          onPressed: () => _switchMode(AuthViewMode.passwordSignIn),
          child: const Text('Back to Sign In'),
        ),
      ],
    );
  }

  // 6. Reset Password OTP View
  Widget _buildResetPasswordOtpView(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      key: const ValueKey('reset_password_otp_view'),
      children: [
        Text('Set New Password', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Enter the reset code from your email and your new password.', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),

        TextFormField(
          controller: _otpController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Reset Code',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.pin_outlined),
            hintText: '123456',
          ),
          keyboardType: TextInputType.number,
          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter the reset code' : null,
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'New Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          obscureText: _obscureConfirmPassword,
          validator: (v) {
            if (v != _passwordController.text) return 'Passwords do not match';
            return null;
          },
          onFieldSubmitted: (_) => _handleResetPassword(),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleResetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('UPDATE PASSWORD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ),
        ),
        const SizedBox(height: 16),

        TextButton(
          onPressed: () => _switchMode(AuthViewMode.passwordSignIn),
          child: const Text('Cancel & Back to Sign In'),
        ),
      ],
    );
  }
}
