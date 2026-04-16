import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/app_brand.dart';
import '../../data/api/api_client.dart';
import 'providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static String? validateForgotPasswordEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return 'Enter your email first.';
    }
    const emailPattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
    if (!RegExp(emailPattern).hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(authClientProvider)
          .signInWithPhoneAndPassword(
            phone: _phone.text.trim(),
            password: _pass.text,
          );
    } on BackendApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter account email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(emailController.text.trim()),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    emailController.dispose();
    if (!mounted || email == null) {
      return;
    }

    final validationMessage = LoginScreen.validateForgotPasswordEmail(email);
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    try {
      await ref.read(authClientProvider).sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'If an account exists for $email, you can reset the password '
            'using the link or token from your administrator.',
          ),
        ),
      );
    } on BackendApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                border: Border(
                  bottom: BorderSide(
                    color: AppBrand.primary.withValues(alpha: 0.08),
                  ),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppBrand.primary.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(
                    size: 64,
                    borderRadius: 18,
                    padding: 6,
                    showShadow: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppBrand.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppBrand.accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Text(
                            'Secure Login',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppBrand.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          AppBrand.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppBrand.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sign in to continue to your MAHTOT workspace.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: AppBrand.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Card(
                          elevation: 10,
                          shadowColor: AppBrand.primary.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          surfaceTintColor: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppBrand.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Please sign in to continue',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppBrand.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                TextField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number',
                                    hintText: 'Enter your phone number',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                    hintStyle: TextStyle(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _pass,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Enter your password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    hintStyle: const TextStyle(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (_error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: Color(0xFFC62828),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(
                                              color: Color(0xFFC62828),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: <Color>[
                                        AppBrand.primary,
                                        AppBrand.primaryDark,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: AppBrand.primary.withValues(
                                          alpha: 0.28,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _loading ? null : _login,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 48,
                                        alignment: Alignment.center,
                                        child: _loading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Text(
                                                    'Login',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Icon(
                                                    Icons.arrow_forward,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: TextButton(
                                    onPressed: _sendPasswordReset,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text(
                                      'Forgot Password? Click here',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Professional daily saving access',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppBrand.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
