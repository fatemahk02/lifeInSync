import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import 'auth_service.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _bgController;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Back button ───────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.textPrimary,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Logo ──────────────────────────────
                    _buildLogo(),
                    const SizedBox(height: 24),

                    // ── Title CENTERED ────────────────────
                    Text(
                      'Create account',
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),
                    const SizedBox(height: 8),
                    Text(
                      'Start your wellbeing journey today',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 32),

                    // ── Fields ────────────────────────────
                    _buildField(
                      label: 'Full Name',
                      controller: _nameController,
                      icon: Icons.person_outline_rounded,
                      hint: 'Your name',
                      delay: 250,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildField(
                      label: 'Email',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      hint: 'you@example.com',
                      type: TextInputType.emailAddress,
                      delay: 300,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your email';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildField(
                      label: 'Password',
                      controller: _passwordController,
                      icon: Icons.lock_outlined,
                      hint: 'Min. 6 characters',
                      obscure: _obscurePassword,
                      delay: 350,
                      toggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      validator: (v) {
                        if (v == null || v.length < 6)
                          return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildField(
                      label: 'Confirm Password',
                      controller: _confirmController,
                      icon: Icons.lock_outlined,
                      hint: 'Re-enter password',
                      obscure: true,
                      delay: 400,
                      validator: (v) {
                        if (v != _passwordController.text)
                          return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Terms checkbox ────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scale: 0.9,
                          child: Checkbox(
                            value: _agreedToTerms,
                            activeColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (v) =>
                                setState(() => _agreedToTerms = v ?? false),
                          ),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              text: 'I agree to the ',
                              style: Theme.of(context).textTheme.bodySmall,
                              children: [
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 420.ms),
                    const SizedBox(height: 28),

                    // ── Sign Up Button ────────────────────
                    _buildSignUpButton()
                        .animate()
                        .fadeIn(delay: 460.ms)
                        .slideY(begin: 0.2),
                    const SizedBox(height: 24),

                    // ── Sign In Link ──────────────────────
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: 'Already have an account?  ',
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (_, __) {
        final t = _bgController.value;
        return Stack(
          children: [
            Positioned(
              top: -80 + t * 40,
              left: -40 + t * 20,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondary.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: 60 - t * 30,
              right: -50 + t * 20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.09),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogo() {
    return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3DBE7A), Color(0xFF2A8F58)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 30),
        )
        .animate()
        .scale(
          duration: 600.ms,
          curve: Curves.elasticOut,
          begin: const Offset(0.5, 0.5),
        )
        .fadeIn(duration: 400.ms);
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required int delay,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
  }) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              obscureText: obscure,
              keyboardType: type,
              validator: validator,
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: Icon(icon, color: AppTheme.primary),
                suffixIcon: toggleObscure != null
                    ? IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        onPressed: toggleObscure,
                      )
                    : null,
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideX(begin: 0.08);
  }

  Widget _buildSignUpButton() => GestureDetector(
    onTap: _isLoading ? null : _signUp,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isLoading
              ? [Colors.grey.shade300, Colors.grey.shade300]
              : [const Color(0xFF3DBE7A), const Color(0xFF2A8F58)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isLoading ? null : [AppTheme.primaryShadow],
      ),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              )
            : const Text(
                'Create Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    ),
  );

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showError('Please agree to the Terms of Service');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await _authService.signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await cred.user?.updateDisplayName(_nameController.text.trim());
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
