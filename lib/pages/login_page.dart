import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../providers/user_profile_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin, CodeAutoFill {
  // ── Step: 0=phone, 1=OTP, 2=success, 3=logout ─────────────────────────────
  int _step = 0;
  bool _isLoading = false;

  // ── Phone ───────────────────────────────────────────────────────────────────
  final TextEditingController _phoneCtrl = TextEditingController();
  String _phoneError = '';

  // ── OTP (6 digits) ──────────────────────────────────────────────────────────
  static const int _otpLength = 6;
  final List<TextEditingController> _otpCtrls =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _otpNodes =
      List.generate(_otpLength, (_) => FocusNode());
  String _otpError = '';
  double _shakeValue = 0.0;
  bool _autoFillListening = false;
  double _lastKeyboardHeight = 0;

  // ── Countdown ───────────────────────────────────────────────────────────────
  Timer? _timer;
  int _timerSec = 60;

  // ── Animations ──────────────────────────────────────────────────────────────
  late AnimationController _driftCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _slideUpCtrl;
  late Animation<double> _slideUpAnim;

  // ── Verified user (kept for success step display) ───────────────────────────
  User? _verifiedUser;

  // ── CodeAutoFill (sms_autofill) ─────────────────────────────────────────────
  @override
  void codeUpdated() {
    // Called by the SMS Retriever when the OTP SMS is received.
    final smsCode = code ?? '';
    if (smsCode.length == _otpLength && mounted) {
      _fillOtpBoxes(smsCode);
      _verifyOtp();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    if (context.read<UserProfileProvider>().isLoggedIn) {
      _step = 3; // Logged In state
    }
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _slideUpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideUpAnim = CurvedAnimation(
      parent: _slideUpCtrl,
      curve: Curves.easeOutCubic,
    );
    _slideUpCtrl.forward();
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    _floatCtrl.dispose();
    _slideUpCtrl.dispose();
    _timer?.cancel();
    _phoneCtrl.dispose();
    for (var c in _otpCtrls) { c.dispose(); }
    for (var n in _otpNodes) { n.dispose(); }
    if (_autoFillListening) {
      SmsAutoFill().unregisterListener();
    }
    cancel(); // CodeAutoFill mixin cleanup
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (_lastKeyboardHeight > 100 && keyboardHeight < 10) {
      FocusScope.of(context).unfocus();
    }
    _lastKeyboardHeight = keyboardHeight;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Auth logic
  // ═══════════════════════════════════════════════════════════════════════════

  void _sendOtp() async {
    if (_isLoading) return;
    final phone = _phoneCtrl.text.replaceAll(' ', '');
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    if (!phoneRegex.hasMatch(phone)) {
      setState(() => _phoneError = 'Please enter a valid 10-digit number.');
      return;
    }
    setState(() {
      _phoneError = '';
      _isLoading = true;
    });

    AuthService.instance.reset();

    await AuthService.instance.verifyPhone(
      phone: '+91$phone',
      timeout: const Duration(seconds: 60),

      // ── Instant auto-verification (some Android devices) ─────────────────
      onAutoVerified: (PhoneAuthCredential credential) async {
        if (!mounted) return;
        await _signInWithCredential(credential);
      },

      // ── OTP SMS dispatched, move to step 1 ───────────────────────────────
      onCodeSent: (String verificationId) async {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _step = 1;
          _timerSec = 60;
        });
        _startCountdown();

        // Start SMS auto-read listener
        await SmsAutoFill().listenForCode();
        _autoFillListening = true;

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) FocusScope.of(context).requestFocus(_otpNodes[0]);
        });
      },

      // ── Firebase error ────────────────────────────────────────────────────
      onFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _phoneError = _friendlyAuthError(e);
        });
      },
    );
  }

  void _resendOtp() async {
    if (_isLoading) return;
    setState(() {
      _otpError = '';
      _isLoading = true;
      for (var c in _otpCtrls) { c.clear(); }
    });

    await AuthService.instance.verifyPhone(
      phone: '+91${_phoneCtrl.text.replaceAll(' ', '')}',
      timeout: const Duration(seconds: 60),

      onAutoVerified: (credential) async {
        if (!mounted) return;
        await _signInWithCredential(credential);
      },

      onCodeSent: (verificationId) async {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _timerSec = 60;
        });
        _startCountdown();
        // Re-listen for the new SMS
        if (_autoFillListening) await SmsAutoFill().unregisterListener();
        await SmsAutoFill().listenForCode();
        _autoFillListening = true;
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_otpNodes[0]);
      },

      onFailed: (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _otpError = _friendlyAuthError(e);
        });
      },
    );
  }

  void _verifyOtp() async {
    if (_isLoading) return;
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < _otpLength) {
      _showOtpError('Please enter all $_otpLength digits.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final result = await AuthService.instance.verifyOtp(otp);
      if (!mounted) return;
      _timer?.cancel();

      // Stop auto-fill listener
      if (_autoFillListening) {
        await SmsAutoFill().unregisterListener();
        _autoFillListening = false;
      }

      // Sync user profile
      if (result.user != null) {
        _verifiedUser = result.user;
        if (!mounted) return;
        await context.read<UserProfileProvider>().signInFromAuth(result.user!);
      }

      setState(() {
        _isLoading = false;
        _step = 2;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        for (var c in _otpCtrls) { c.clear(); }
      });
      _showOtpError(_friendlyAuthError(e));
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) FocusScope.of(context).requestFocus(_otpNodes[0]);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showOtpError('Verification failed. Please try again.');
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    setState(() => _isLoading = true);
    try {
      final result =
          await AuthService.instance.signInWithCredential(credential);
      if (!mounted) return;
      _timer?.cancel();
      if (_autoFillListening) {
        await SmsAutoFill().unregisterListener();
        _autoFillListening = false;
      }
      if (result.user != null) {
        _verifiedUser = result.user;
        if (!mounted) return;
        await context.read<UserProfileProvider>().signInFromAuth(result.user!);
      }
      setState(() {
        _isLoading = false;
        _step = 2; // Jump straight to success
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = 1; // Fall back so user can type manually
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  void _fillOtpBoxes(String code) {
    for (int i = 0; i < _otpLength && i < code.length; i++) {
      _otpCtrls[i].text = code[i];
    }
    setState(() => _otpError = '');
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _timerSec--;
        if (_timerSec <= 0) timer.cancel();
      });
    });
  }

  void _showOtpError(String msg) {
    setState(() {
      _otpError = msg;
      _shakeValue++;
    });
  }

  void _goBackToPhone() {
    _timer?.cancel();
    AuthService.instance.reset();
    setState(() {
      _step = 0;
      _otpError = '';
      for (var c in _otpCtrls) { c.clear(); }
    });
  }

  void _goHome() {
    // Pop with true so callers can know auth succeeded
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. Please check and retry.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please check and retry.';
      case 'session-expired':
        return 'OTP has expired. Please request a new one.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check and retry.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.themeOf(context);
    final bgStart = theme.loginGradient[0];
    final bgMid = theme.loginGradient[1];
    final bgEnd = theme.loginGradient[2];
    final secondaryAccent = theme.secondaryAccent;
    final accentDark = theme.loginGradient[1];
    final blobColors = theme.blobColors;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme:
            Theme.of(context).textTheme.apply(fontFamily: 'Poppins'),
        primaryTextTheme:
            Theme.of(context).primaryTextTheme.apply(fontFamily: 'Poppins'),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: bgStart,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              // ── Background Gradient ─────────────────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const FractionalOffset(0.0, 0.0),
                    end: const FractionalOffset(1.0, 1.0),
                    colors: [bgStart, bgMid, bgEnd],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // ── Animated Blobs ──────────────────────────────────────────────
            AnimatedBuilder(
              animation: _driftCtrl,
              builder: (context, child) {
                final v = _driftCtrl.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -80 + (30 * v),
                      left: -80 + (20 * v),
                      child: _buildBlob(340, blobColors[0]),
                    ),
                    Positioned(
                      bottom: -60 + (30 * (1 - v)),
                      right: -60 + (20 * (1 - v)),
                      child: _buildBlob(260, blobColors[1]),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.45 +
                          (15 * v),
                      left: MediaQuery.of(context).size.width * 0.6 +
                          (25 * v),
                      child: _buildBlob(180, blobColors[2]),
                    ),
                  ],
                );
              },
            ),

            // ── Floating Grocery Icons ──────────────────────────────────────
            AnimatedBuilder(
              animation: _floatCtrl,
              builder: (context, child) {
                final t = _floatCtrl.value;
                return Stack(
                  children: [
                    _buildFloater(
                        'assets/images/login/icon_cart.png', 0.08, 0.15, t, 0),
                    _buildFloater(
                        'assets/images/login/icon_broccoli.png', 0.80, 0.25, t,
                        pi / 2),
                    _buildFloater(
                        'assets/images/login/icon_tomato.png', 0.20, 0.75, t,
                        pi / 1.5),
                    _buildFloater(
                        'assets/images/login/icon_milk.png', 0.70, 0.70, t,
                        pi / 3),
                    _buildFloater(
                        'assets/images/login/icon_wheat.png', 0.50, 0.10, t,
                        pi),
                  ],
                );
              },
            ),

            // ── Glassmorphism Card ──────────────────────────────────────────
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedBuilder(
                  animation: _slideUpAnim,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 60 * (1 - _slideUpAnim.value)),
                      child: Opacity(
                          opacity: _slideUpAnim.value, child: child),
                    );
                  },
                  child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 80,
                            offset: Offset(0, 32),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(28, 36, 28, 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                // ── Logo Row ──────────────────────────────
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            secondaryAccent,
                                            accentDark,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: secondaryAccent
                                                .withValues(alpha: 0.5),
                                            blurRadius: 20,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: Image.asset(
                                          'assets/images/logo.png',
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'DAILY CLUB',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          '10–15 mins delivery • Green',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Colors.white
                                                .withValues(alpha: 0.65),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),

                                // ── Step Content ──────────────────────────
                                AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 400),
                                  transitionBuilder: (child, animation) {
                                    final slideAnim =
                                        Tween<Offset>(
                                      begin: const Offset(0.05, 0),
                                      end: Offset.zero,
                                    ).animate(animation);
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: slideAnim,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildStepContent(_step),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Widget builders
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBlob(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildFloater(
      String assetPath, double x, double y, double t, double phase) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final v = sin((t * 2 * pi) + phase);
    return Positioned(
      left: sw * x,
      top: sh * y,
      child: Transform.translate(
        offset: Offset(0, -18 * v),
        child: Transform.rotate(
          angle: 5 * v * (pi / 180),
          child: Opacity(
            opacity: 0.18,
            child: Image.asset(assetPath, width: 36, height: 36),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(int stepIndex) {
    if (stepIndex == 0) return _buildPhoneStep();
    if (stepIndex == 1) return _buildOtpStep();
    if (stepIndex == 3) return _buildLogoutStep();
    return _buildSuccessStep();
  }

  // ── Step 0: Phone number ────────────────────────────────────────────────────
  Widget _buildPhoneStep() {
    final theme = AppThemeScope.themeOf(context);
    final primaryAccent = theme.primaryAccent;
    final secondaryAccent = theme.secondaryAccent;

    // ── Web: phone OTP is Android-only ─────────────────────────────────────
    if (kIsWeb) {
      return KeyedSubtree(
        key: const ValueKey(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome to Daily Club 🛒',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Login with OTP on our Android app',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
            _buildDivider(),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.13)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: secondaryAccent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.phone_android_rounded,
                        size: 32, color: secondaryAccent),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Phone OTP is available on\nour Android app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Download Daily Club from the Play Store\nfor instant OTP sign-in & auto-read.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Or browse the store as a guest →',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile: normal OTP phone input ──────────────────────────────────────
    return KeyedSubtree(
      key: const ValueKey(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome back 👋',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your mobile number to continue',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          _buildDivider(),

          Text(
            'MOBILE NUMBER',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              // Country code badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: const Row(
                  children: [
                    _IndiaFlag(width: 24, height: 16),
                    SizedBox(width: 6),
                    Text(
                      '+91',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: '98765 43210',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _phoneError.isNotEmpty
                            ? Colors.redAccent
                            : Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: primaryAccent, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 18),
                  ),
                  onSubmitted: (_) => _sendOtp(),
                ),
              ),
            ],
          ),

          if (_phoneError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _phoneError,
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 12),
              ),
            ),

          const SizedBox(height: 18),
          _buildMainButton('Send OTP', _sendOtp),
          const SizedBox(height: 22),

          Text(
            'By continuing you agree to our Terms of Service & Privacy Policy',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: OTP entry (6 boxes) ─────────────────────────────────────────────
  Widget _buildOtpStep() {
    final theme = AppThemeScope.themeOf(context);
    final primaryAccent = theme.primaryAccent;

    final maskedPhone = () {
      final p = _phoneCtrl.text.replaceAll(' ', '');
      if (p.length == 10) {
        return '+91 ${p.substring(0, 5)}XXXXX';
      }
      return '+91 $p';
    }();

    return KeyedSubtree(
      key: const ValueKey(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _goBackToPhone,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back,
                        color: Colors.white.withValues(alpha: 0.45),
                        size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Text(
            'Verify OTP 🔐',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sent to $maskedPhone',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),

          // Auto-fill hint badge
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 5),
                    Text(
                      'OTP will be read automatically',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          _buildDivider(),

          Text(
            'ENTER 6-DIGIT OTP',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          // OTP boxes with shake animation
          TweenAnimationBuilder(
            key: ValueKey(_shakeValue),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 350),
            builder: (context, val, child) {
              final offset = sin(val * pi * 3) * 6;
              return Transform.translate(
                  offset: Offset(offset, 0), child: child);
            },
            child: Row(
              children: List.generate(_otpLength, (index) {
                return Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.only(right: index < _otpLength - 1 ? 7 : 0),
                    child: TextField(
                      controller: _otpCtrls[index],
                      focusNode: _otpNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      obscureText: true,
                      obscuringCharacter: '•',
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _otpCtrls[index].text.isNotEmpty
                            ? primaryAccent.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.08),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _otpError.isNotEmpty
                                ? Colors.redAccent
                                : (_otpCtrls[index].text.isNotEmpty
                                    ? primaryAccent
                                    : Colors.white
                                        .withValues(alpha: 0.14)),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: primaryAccent, width: 2),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && index < _otpLength - 1) {
                          FocusScope.of(context)
                              .requestFocus(_otpNodes[index + 1]);
                        } else if (val.isEmpty && index > 0) {
                          FocusScope.of(context)
                              .requestFocus(_otpNodes[index - 1]);
                        }
                        // Auto-submit when last box is filled
                        if (val.isNotEmpty &&
                            index == _otpLength - 1 &&
                            _otpCtrls
                                .every((c) => c.text.isNotEmpty)) {
                          _verifyOtp();
                        }
                        if (_otpError.isNotEmpty) {
                          setState(() => _otpError = '');
                        }
                      },
                    ),
                  ),
                );
              }),
            ),
          ),

          if (_otpError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _otpError,
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 12),
              ),
            ),

          const SizedBox(height: 18),

          // Resend row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Didn't receive it?",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _timerSec <= 0 ? _resendOtp : null,
                    child: Text(
                      'Resend OTP',
                      style: TextStyle(
                        color: _timerSec <= 0
                            ? theme.primaryAccent
                            : Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_timerSec > 0)
                    Text(
                      ' (${_timerSec}s)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildMainButton('Verify & Login', _verifyOtp),
          const SizedBox(height: 22),

          Text(
            'OTP is valid for 10 minutes only.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Success ─────────────────────────────────────────────────────────
  Widget _buildSuccessStep() {
    final theme = AppThemeScope.themeOf(context);
    final secondaryAccent = theme.secondaryAccent;
    final accentDark = theme.loginGradient[1];

    final displayPhone = _verifiedUser?.phoneNumber ??
        '+91 ${_phoneCtrl.text.replaceAll(' ', '')}';

    return KeyedSubtree(
      key: const ValueKey(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: AnimatedBuilder(
              animation: _floatCtrl,
              builder: (context, child) {
                final v = _floatCtrl.value;
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [secondaryAccent, accentDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: secondaryAccent.withValues(alpha: 0.6),
                        blurRadius: 32 + (16 * v),
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check,
                      color: Colors.white, size: 40),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "You're in! 🎉",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Signed in as $displayPhone\nYour groceries are just moments away.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 48),
          _buildMainButton('Go to Home →', _goHome),
        ],
      ),
    );
  }

  // ── Step 3: Already Logged In / Log Out ─────────────────────────────────────
  Widget _buildLogoutStep() {
    final profile = context.watch<UserProfileProvider>();

    return KeyedSubtree(
      key: const ValueKey(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'You are logged in',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Active account details',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          _buildDivider(),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.displayPhone,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildMainButton('Continue to Store', () {
            Navigator.of(context).pop();
          }),
          const SizedBox(height: 16),

          GestureDetector(
            onTap: () async {
              setState(() => _isLoading = true);
              await profile.signOut();
              setState(() {
                _isLoading = false;
                _step = 0; // Go back to phone enter step
              });
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Divider ─────────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.15),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  // ── CTA Button ──────────────────────────────────────────────────────────────
  Widget _buildMainButton(String text, VoidCallback onTap) {
    final theme = AppThemeScope.themeOf(context);
    final secondaryAccent = theme.secondaryAccent;
    final accentDark = theme.loginGradient[1];

    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [secondaryAccent, accentDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: secondaryAccent.withValues(alpha: 0.55),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// India Flag (inline, no image file)
// ══════════════════════════════════════════════════════════════════════════════

class _IndiaFlag extends StatelessWidget {
  final double width;
  final double height;
  const _IndiaFlag({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: CustomPaint(
        size: Size(width, height),
        painter: _IndiaFlagPainter(),
      ),
    );
  }
}

class _IndiaFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stripeH = h / 3;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, stripeH),
        Paint()..color = const Color(0xFFFF9933));
    canvas.drawRect(Rect.fromLTWH(0, stripeH, w, stripeH),
        Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(0, stripeH * 2, w, stripeH),
        Paint()..color = const Color(0xFF138808));

    final cx = w / 2;
    final cy = h / 2;
    final r = stripeH * 0.42;
    final chakraPaint = Paint()
      ..color = const Color(0xFF000080)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16;
    canvas.drawCircle(Offset(cx, cy), r, chakraPaint);

    final spokePaint = Paint()
      ..color = const Color(0xFF000080)
      ..strokeWidth = r * 0.06;
    for (int i = 0; i < 24; i++) {
      final angle = (i * 2 * pi) / 24;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + r * 0.9 * cos(angle), cy + r * 0.9 * sin(angle)),
        spokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_IndiaFlagPainter oldDelegate) => false;
}
