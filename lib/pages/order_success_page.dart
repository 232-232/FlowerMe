import 'dart:async';
import 'dart:ui';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';


import '../models/order_model.dart';
import '../theme/app_colors.dart';
import '../widgets/order_success_animation.dart';
import 'order_tracking_page.dart';

/// Clamps another curve's output to [0, 1]. Required because TweenSequence
/// asserts 0 <= t <= 1, but Curves.elasticOut can overshoot past 1.
class _ClampedCurve extends Curve {
  const _ClampedCurve(this.curve);
  final Curve curve;

  @override
  double transformInternal(double t) => curve.transform(t).clamp(0.0, 1.0);
}

class OrderSuccessPage extends StatefulWidget {
  const OrderSuccessPage({super.key, this.order});

  final OrderModel? order;

  @override
  State<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends State<OrderSuccessPage>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final ConfettiController _confettiController;
  late final ConfettiController _pageConfettiController;

  late final Animation<double> _circleScaleAnimation;
  late final Animation<double> _checkAnimation;
  late final Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _pageConfettiController =
        ConfettiController(duration: const Duration(seconds: 4));

    _circleScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1.3),
        weight: 72,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1),
        weight: 28,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0,
          0.33,
          curve: _ClampedCurve(Curves.elasticOut),
        ),
      ),
    );

    _checkAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.33, 0.6, curve: Curves.easeOutCubic),
    );

    _rippleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.6, 1, curve: Curves.easeOutCubic),
    );

    unawaited(_runSuccessSequence());
  }

  Future<void> _runSuccessSequence() async {
    // Explosive burst fires immediately on load
    _pageConfettiController.play();
    _confettiController.play();

    await _animationController.forward();
    await Future<void>.delayed(const Duration(seconds: 5));

    if (!mounted) return;
    _navigateToTracking();
  }

  void _navigateToTracking() {
    if (!mounted) return;
    final orderId = widget.order?.orderId ?? 'DC92841';
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            OrderTrackingPage(initialOrderId: orderId),
        transitionDuration: const Duration(milliseconds: 550),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const Curve curve = Curves.easeOutCubic;
          final Animatable<Offset> slideTween = Tween<Offset>(
            begin: const Offset(0.15, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: curve));
          final Animatable<double> fadeTween =
              Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(slideTween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    _pageConfettiController.dispose();
    super.dispose();
  }

  /// Builds a RadialGradient background adaptive to the current theme.
  /// Green theme uses the exact spec colors (#133524 → #050B08).
  RadialGradient _buildRadialBackground(AppThemeData appTheme) {
    final Color centerColor;
    final Color edgeColor;

    switch (appTheme.type) {
      case AppThemeType.pastelGreen:
        centerColor = const Color(0xFF133524);
        edgeColor = const Color(0xFF050B08);
      case AppThemeType.lightBlue:
        centerColor = const Color(0xFF0D2137);
        edgeColor = const Color(0xFF040810);
      case AppThemeType.pink:
        centerColor = const Color(0xFF330D20);
        edgeColor = const Color(0xFF0A0308);
      case AppThemeType.orange:
        centerColor = const Color(0xFF351400);
        edgeColor = const Color(0xFF0A0400);
    }

    return RadialGradient(
      center: Alignment.center,
      radius: 1.25,
      colors: [centerColor, edgeColor],
      stops: const [0.0, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeScope.themeOf(context);
    final accent = appTheme.primaryAccent;
    final orderId = widget.order?.orderId ?? 'DC92841';

    return Scaffold(
      body: Stack(
        children: [
          // ── Radial gradient background ──────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: _buildRadialBackground(appTheme),
              ),
            ),
          ),

          // ── Full-screen explosive confetti ──────────────────────────────
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _pageConfettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.05,
                numberOfParticles: 32,
                maxBlastForce: 42,
                minBlastForce: 18,
                gravity: 0.18,
                particleDrag: 0.03,
                shouldLoop: false,
                minimumSize: const Size.square(6),
                maximumSize: const Size(14, 18),
                colors: const [
                  Color(0xFF2ECC71),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFD700),
                  Color(0xFF27AE60),
                  Color(0xFFF1C40F),
                  Color(0xFFFFFFFF),
                ],
              ),
            ),
          ),

          // ── Main scrollable content ─────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                      children: [
                        const SizedBox(height: 44),

                        // Success icon with spring + ripple animations
                        OrderSuccessAnimation(
                          scaleAnimation: _circleScaleAnimation,
                          checkAnimation: _checkAnimation,
                          rippleAnimation: _rippleAnimation,
                          confettiController: _confettiController,
                          glowColor: accent,
                        ),

                        const SizedBox(height: 36),

                        // Header — staggered at 400ms
                        Text(
                          'Woohoo! Order Placed',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: "PlusJakartaSans", 
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.6,
                            height: 1.15,
                          ),
                        ).animate(
                          effects: [
                            FadeEffect(
                              delay: 400.ms,
                              duration: 500.ms,
                              curve: Curves.easeOut,
                            ),
                            MoveEffect(
                              delay: 400.ms,
                              duration: 500.ms,
                              begin: const Offset(0, 26),
                              end: Offset.zero,
                              curve: Curves.easeOutCubic,
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Subtitle — 500ms
                        Text(
                          'Your groceries are on their way!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: "PlusJakartaSans", 
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.62),
                            letterSpacing: 0.15,
                            height: 1.5,
                          ),
                        ).animate(
                          effects: [
                            FadeEffect(
                              delay: 540.ms,
                              duration: 500.ms,
                              curve: Curves.easeOut,
                            ),
                            MoveEffect(
                              delay: 540.ms,
                              duration: 500.ms,
                              begin: const Offset(0, 20),
                              end: Offset.zero,
                              curve: Curves.easeOutCubic,
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Glass card — 700ms
                        _GlassCard(orderId: orderId, accent: accent).animate(
                          effects: [
                            FadeEffect(
                              delay: 700.ms,
                              duration: 600.ms,
                              curve: Curves.easeOut,
                            ),
                            MoveEffect(
                              delay: 700.ms,
                              duration: 600.ms,
                              begin: const Offset(0, 30),
                              end: Offset.zero,
                              curve: Curves.easeOutCubic,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // CTA button — 1000ms
                        _TrackOrderButton(
                          accent: accent,
                          onTap: _navigateToTracking,
                        ).animate(
                          effects: [
                            FadeEffect(
                              delay: 1000.ms,
                              duration: 500.ms,
                              curve: Curves.easeOut,
                            ),
                            MoveEffect(
                              delay: 1000.ms,
                              duration: 500.ms,
                              begin: const Offset(0, 18),
                              end: Offset.zero,
                              curve: Curves.easeOutCubic,
                            ),
                          ],
                        ),

                        const SizedBox(height: 52),
                      ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass Card ─────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.orderId, required this.accent});

  final String orderId;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Info chips row
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.receipt_long_rounded,
                    label: 'Order ID',
                    value: '#$orderId',
                    accent: accent,
                  ),
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: 'Arriving in',
                    value: '25–30 min',
                    accent: accent,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Delivery progress tracker
              _ProgressTracker(accent: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accent, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontFamily: "PlusJakartaSans", 
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.50),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontFamily: "PlusJakartaSans", 
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress Tracker ──────────────────────────────────────────────────────────

class _ProgressTracker extends StatelessWidget {
  const _ProgressTracker({required this.accent});

  final Color accent;

  static const _labels = ['Order\nPlaced', 'Being\nPrepared', 'Out for\nDelivery'];
  static const _activeStep = 0; // 33% — first step complete

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Delivery Progress',
          style: TextStyle(fontFamily: "PlusJakartaSans", 
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.55),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),

        // Track with positioned dots
        SizedBox(
          height: 22,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              const dotD = 14.0;
              const trackH = 3.0;
              final trackTop = (22 - trackH) / 2;
              final dotTop = (22 - dotD) / 2;
              final trackW = w - dotD;

              return Stack(
                children: [
                  // Background track
                  Positioned(
                    left: dotD / 2,
                    right: dotD / 2,
                    top: trackTop,
                    child: Container(
                      height: trackH,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Active track segment (33% of total track)
                  Positioned(
                    left: dotD / 2,
                    top: trackTop,
                    child: Container(
                      width: trackW * 0.33,
                      height: trackH,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.55),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Dot 0 — active
                  Positioned(
                    left: 0,
                    top: dotTop,
                    child: _StepDot(isActive: true, accent: accent),
                  ),
                  // Dot 1 — inactive
                  Positioned(
                    left: w / 2 - dotD / 2,
                    top: dotTop,
                    child: _StepDot(isActive: false, accent: accent),
                  ),
                  // Dot 2 — inactive
                  Positioned(
                    right: 0,
                    top: dotTop,
                    child: _StepDot(isActive: false, accent: accent),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Step labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_labels.length, (i) {
            final isActive = i <= _activeStep;
            return SizedBox(
              width: 72,
              child: Text(
                _labels[i],
                textAlign: i == 0
                    ? TextAlign.left
                    : i == _labels.length - 1
                        ? TextAlign.right
                        : TextAlign.center,
                style: TextStyle(fontFamily: "PlusJakartaSans", 
                  fontSize: 11,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: 0.1,
                  height: 1.4,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.isActive, required this.accent});

  final bool isActive;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? accent : Colors.white.withValues(alpha: 0.15),
        border: isActive
            ? null
            : Border.all(
                color: Colors.white.withValues(alpha: 0.20),
                width: 1.5,
              ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.65),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: isActive
          ? const Icon(Icons.check_rounded, size: 9, color: Colors.white)
          : null,
    );
  }
}

// ── CTA Button ────────────────────────────────────────────────────────────────

class _TrackOrderButton extends StatelessWidget {
  const _TrackOrderButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent,
              Color.lerp(accent, Colors.black, 0.15)!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.50),
              blurRadius: 28,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.20),
              blurRadius: 50,
              spreadRadius: 4,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Track My Order',
              style: TextStyle(fontFamily: "PlusJakartaSans", 
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
