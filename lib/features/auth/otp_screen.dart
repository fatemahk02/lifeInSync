import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pinput/pinput.dart';
import '../../core/theme/app_theme.dart';
import 'auth_service.dart';
import 'login_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _authService = AuthService();
  late AnimationController _bgController;

  String? _verificationId;
  bool _codeSent = false;
  bool _isLoading = false;
  String? _errorText;

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
    _phoneController.dispose();
    _pinController.dispose();
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back button
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
                    const SizedBox(height: 20),

                    // ── Icon CENTERED ─────────────────────
                    Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3DBE7A), Color(0xFF2A8F58)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.phone_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        )
                        .animate()
                        .scale(
                          duration: 600.ms,
                          curve: Curves.elasticOut,
                          begin: const Offset(0.5, 0.5),
                        )
                        .fadeIn(),
                    const SizedBox(height: 24),

                    // ── Title CENTERED ────────────────────
                    Text(
                      _codeSent ? 'Verify OTP' : 'Phone Sign In',
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                    const SizedBox(height: 10),

                    Text(
                      _codeSent
                          ? 'Enter the 6-digit code sent to\n${_phoneController.text}'
                          : 'Enter your number with country code\ne.g. +91 98765 43210',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 36),

                    // ── Error banner ──────────────────────
                    if (_errorText != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.error.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppTheme.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorText!,
                                style: const TextStyle(
                                  color: AppTheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn().shake(),
                      const SizedBox(height: 16),
                    ],

                    // ── Phone input OR OTP ────────────────
                    if (!_codeSent) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Phone Number',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textAlign: TextAlign.left,
                        decoration: const InputDecoration(
                          hintText: '+91 98765 43210',
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                            color: AppTheme.primary,
                          ),
                        ),
                      ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.1),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'For testing: +91 9999999999, OTP: 123456\n(Add test number in Firebase Console)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 32),
                      _buildButton(
                        'Send OTP',
                        _sendOTP,
                      ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.2),
                    ] else ...[
                      // OTP Pinput — centered
                      Center(
                        child: Pinput(
                          length: 6,
                          controller: _pinController,
                          onCompleted: _verifyOTP,
                          defaultPinTheme: PinTheme(
                            width: 48,
                            height: 56,
                            textStyle: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1.5,
                              ),
                            ),
                          ),
                          focusedPinTheme: PinTheme(
                            width: 48,
                            height: 56,
                            textStyle: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.primary,
                                width: 2.0,
                              ),
                            ),
                          ),
                          submittedPinTheme: PinTheme(
                            width: 48,
                            height: 56,
                            textStyle: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn().scale(
                        begin: const Offset(0.9, 0.9),
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
                      const SizedBox(height: 32),
                      _buildButton(
                        'Verify & Sign In',
                        () => _verifyOTP(_pinController.text),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() {
                            _codeSent = false;
                            _errorText = null;
                            _pinController.clear();
                          }),
                          child: Text(
                            'Resend Code',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
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
              top: -60 + t * 30,
              right: -40 + t * 20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: 120 - t * 40,
              left: -50 + t * 15,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondary.withOpacity(0.07),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildButton(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
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
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorText = 'Please enter a phone number');
      return;
    }
    if (!phone.startsWith('+')) {
      setState(() => _errorText = 'Include country code — e.g. +91 9876543210');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await _authService.sendOTP(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) _goToLogin();
        },
        codeSent: (verificationId, _) {
          if (mounted)
            setState(() {
              _verificationId = verificationId;
              _codeSent = true;
              _isLoading = false;
            });
        },
        verificationFailed: (e) {
          if (mounted)
            setState(() {
              _isLoading = false;
              _errorText =
                  e.message ??
                  'Verification failed. Check your number and try again.';
            });
        },
      );
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorText = e.toString().replaceAll('Exception: ', '');
        });
    }
  }

  Future<void> _verifyOTP(String code) async {
    if (code.length < 6) {
      setState(() => _errorText = 'Enter the complete 6-digit code');
      return;
    }
    if (_verificationId == null) {
      setState(() => _errorText = 'Session expired. Request a new code.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _authService.verifyOTPAndSignIn(
        verificationId: _verificationId!,
        smsCode: code,
      );
      if (mounted) _goToLogin();
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorText = e.toString().replaceAll('Exception: ', '');
        });
    }
  }

  void _goToLogin() => Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}
