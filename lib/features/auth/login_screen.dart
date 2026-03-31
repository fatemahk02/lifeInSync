import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'auth_service.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';
import '../dashboard/main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Raleway text style helper — use everywhere ────────────
  static TextStyle _r({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double spacing = 0.0,
  }) => GoogleFonts.raleway(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // ── Logo ──────────────────────────────────
                _buildLogo(),
                const SizedBox(height: 40),

                // ── Welcome title ─────────────────────────
                Text(
                  'Welcome Back',
                  style: _r(
                    size: 32,
                    weight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    spacing: 0.4,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
                const SizedBox(height: 8),

                Text(
                  'Sign in to continue your journey',
                  style: _r(
                    size: 14,
                    weight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    spacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 270.ms),
                const SizedBox(height: 44),

                // ── Email field ───────────────────────────
                _buildFieldLabel('Email'),
                const SizedBox(height: 8),
                _buildEmailField()
                    .animate()
                    .fadeIn(delay: 320.ms)
                    .slideX(begin: 0.08),
                const SizedBox(height: 20),

                // ── Password field ────────────────────────
                _buildFieldLabel('Password'),
                const SizedBox(height: 8),
                _buildPasswordField()
                    .animate()
                    .fadeIn(delay: 360.ms)
                    .slideX(begin: 0.08),
                const SizedBox(height: 10),

                // ── Forgot password ───────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: _r(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppTheme.primary,
                        spacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Sign In button ────────────────────────
                _buildPrimaryButton(
                  label: 'Sign In',
                  onTap: _signInWithEmail,
                  isLoading: _isLoading,
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.15),
                const SizedBox(height: 32),

                // ── Divider ───────────────────────────────
                _buildDivider().animate().fadeIn(delay: 440.ms),
                const SizedBox(height: 28),

                // ── Social buttons ────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _buildSocialButton(
                        label: 'Google',
                        icon: Icons.g_mobiledata_rounded,
                        iconColor: const Color(0xFFEA4335),
                        onTap: _signInWithGoogle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildSocialButton(
                        label: 'Phone OTP',
                        icon: Icons.phone_outlined,
                        iconColor: AppTheme.primary,
                        onTap: () => Navigator.push(
                          context,
                          _slideRoute(const OtpScreen()),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 480.ms),
                const SizedBox(height: 40),

                // ── Sign Up link ──────────────────────────
                _buildSignUpLink().animate().fadeIn(delay: 520.ms),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────
  Widget _buildLogo() {
    return Column(
      children: [
        // Geometric layered squares mark
        SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring square — rotated +12°
                  Transform.rotate(
                    angle: 0.21,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.25),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  // Middle ring square — rotated -8°
                  Transform.rotate(
                    angle: -0.14,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.55),
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                  // Inner solid square — no rotation
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(
              begin: const Offset(0.65, 0.65),
              duration: 700.ms,
              curve: Curves.easeOutBack,
            ),

        const SizedBox(height: 18),

        // Brand wordmark — Raleway
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Life',
                style: GoogleFonts.raleway(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              TextSpan(
                text: 'In',
                style: GoogleFonts.raleway(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
              TextSpan(
                text: 'Sync',
                style: GoogleFonts.raleway(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 180.ms),

        const SizedBox(height: 6),

        // Tagline — same family, tracked caps
        Text(
          'DIGITAL WELLBEING',
          style: GoogleFonts.raleway(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 4.0,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }

  // ── Field label ───────────────────────────────────────────
  Widget _buildFieldLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: _r(
        size: 13,
        weight: FontWeight.w700,
        color: AppTheme.textPrimary,
        spacing: 0.3,
      ),
    ),
  );

  // ── Email field ───────────────────────────────────────────
  Widget _buildEmailField() => TextFormField(
    controller: _emailController,
    keyboardType: TextInputType.emailAddress,
    textInputAction: TextInputAction.next,
    style: _r(size: 14, weight: FontWeight.w500, color: AppTheme.textPrimary),
    validator: (v) {
      if (v == null || v.isEmpty) return 'Please enter your email';
      if (!v.contains('@')) return 'Enter a valid email';
      return null;
    },
    decoration: InputDecoration(
      hintText: 'you@example.com',
      hintStyle: _r(
        size: 14,
        weight: FontWeight.w400,
        color: AppTheme.textSecondary,
      ),
      prefixIcon: const Icon(
        Icons.email_outlined,
        color: AppTheme.primary,
        size: 20,
      ),
      errorStyle: _r(size: 12, weight: FontWeight.w500, color: AppTheme.error),
    ),
  );

  // ── Password field ────────────────────────────────────────
  Widget _buildPasswordField() => TextFormField(
    controller: _passwordController,
    obscureText: _obscurePassword,
    textInputAction: TextInputAction.done,
    onFieldSubmitted: (_) => _signInWithEmail(),
    style: _r(size: 14, weight: FontWeight.w500, color: AppTheme.textPrimary),
    validator: (v) {
      if (v == null || v.isEmpty) return 'Please enter your password';
      if (v.length < 6) return 'Minimum 6 characters';
      return null;
    },
    decoration: InputDecoration(
      hintText: '••••••••',
      hintStyle: _r(
        size: 14,
        weight: FontWeight.w400,
        color: AppTheme.textSecondary,
      ),
      prefixIcon: const Icon(
        Icons.lock_outlined,
        color: AppTheme.primary,
        size: 20,
      ),
      errorStyle: _r(size: 12, weight: FontWeight.w500, color: AppTheme.error),
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: AppTheme.textSecondary,
          size: 20,
        ),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
    ),
  );

  // ── Primary button ────────────────────────────────────────
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading
                ? [Colors.grey.shade300, Colors.grey.shade300]
                : [const Color(0xFF3DBE7A), const Color(0xFF2A8F58)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading ? null : [AppTheme.primaryShadow],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: _r(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    spacing: 0.8,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Divider ───────────────────────────────────────────────
  Widget _buildDivider() => Row(
    children: [
      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.8)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'or',
          style: _r(
            size: 12,
            weight: FontWeight.w600,
            color: AppTheme.textSecondary,
            spacing: 0.5,
          ),
        ),
      ),
      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.8)),
    ],
  );

  // ── Social button ─────────────────────────────────────────
  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [AppTheme.cardShadowLight],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: _r(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sign Up link ──────────────────────────────────────────
  Widget _buildSignUpLink() => GestureDetector(
    onTap: () => Navigator.push(context, _slideRoute(const SignupScreen())),
    child: RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        text: "Don't have an account?  ",
        style: _r(
          size: 14,
          weight: FontWeight.w500,
          color: AppTheme.textSecondary,
        ),
        children: [
          TextSpan(
            text: 'Sign Up',
            style: _r(
              size: 14,
              weight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Slide page transition ─────────────────────────────────
  Route _slideRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 350),
  );

  // ── Actions ───────────────────────────────────────────────
  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) _goHome();
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithGoogle();
      if (result != null && mounted) _goHome();
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showError('Enter your email above first');
      return;
    }
    try {
      await _authService.sendPasswordReset(_emailController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Password reset email sent!',
              style: _r(size: 14, weight: FontWeight.w500, color: Colors.white),
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _goHome() => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const MainShell()),
  );

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: _r(size: 13, weight: FontWeight.w500, color: Colors.white),
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
