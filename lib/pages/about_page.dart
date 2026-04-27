import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AboutPage — Beautiful About Daily Club page
// ─────────────────────────────────────────────────────────────────────────────

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TickerProviderStateMixin {
  // ── Animation controllers
  late final AnimationController _heroCtrl;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;

  late final AnimationController _cardsCtrl;
  late final List<Animation<double>> _cardFade;
  late final List<Animation<Offset>> _cardSlide;

  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotate;

  static const _kCardCount = 6;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoRotate = Tween<double>(
      begin: -0.08,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic));

    _cardsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cardFade = List.generate(_kCardCount, (i) {
      final start = (0.05 + i * 0.12).clamp(0.0, 0.88);
      final end = (start + 0.40).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _cardsCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });
    _cardSlide = List.generate(_kCardCount, (i) {
      final start = (0.05 + i * 0.12).clamp(0.0, 0.88);
      final end = (start + 0.40).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.22),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _cardsCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heroCtrl.forward();
      _logoCtrl.forward();
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _cardsCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _cardsCtrl.dispose();
    _logoCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAalbot() async {
    HapticFeedback.selectionClick();
    final uri = Uri.parse('https://aalbot.com/');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the website'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeScope.themeOf(context);
    final accent = appTheme.primaryAccent;
    final secondary = appTheme.secondaryAccent;
    final gradientColors = appTheme.backgroundGradientColors;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _heroFade,
              child: SlideTransition(
                position: _heroSlide,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [gradientColors.first, gradientColors.last],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                      child: Column(
                        children: [
                          // Back row
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _openAalbot,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.open_in_new_rounded,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Visit Aalbot',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Logo area
                          AnimatedBuilder(
                            animation: _logoCtrl,
                            builder: (_, child) => Transform.scale(
                              scale: _logoScale.value,
                              child: Transform.rotate(
                                angle: _logoRotate.value,
                                child: child,
                              ),
                            ),
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [accent, secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.5),
                                    blurRadius: 28,
                                    offset: const Offset(0, 10),
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.local_grocery_store_rounded,
                                  color: Colors.white,
                                  size: 44,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text(
                            'Daily Club',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your neighbourhood online hypermarket',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Stat row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StatBadge(
                                value: '2025-oct',
                                label: 'Est.',
                                color: const Color(0xFF43A047),
                              ),
                              const SizedBox(width: 12),
                              _StatBadge(
                                value: '600+',
                                label: 'Products',
                                color: const Color(0xFF1E88E5),
                              ),
                              const SizedBox(width: 12),
                              _StatBadge(
                                value: '100%',
                                label: 'Fresh',
                                color: const Color(0xFFFB8C00),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Cards ─────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 0 — About Daily Club
                _buildAnimatedCard(
                  index: 0,
                  child: _AboutCard(
                    icon: Icons.storefront_rounded,
                    iconColor: accent,
                    title: 'About Daily Club',
                    content:
                        'Daily Club is a fast-growing online hypermarket delivering the freshest groceries, household essentials, and everyday items straight to your doorstep.\n\nWe started in 2025-oct  with a mission to make quality shopping accessible, affordable, and hassle-free for every household.',
                  ),
                ),
                const SizedBox(height: 14),

                // 1 — Parent Company
                _buildAnimatedCard(
                  index: 1,
                  child: GestureDetector(
                    onTap: _openAalbot,
                    child: _AboutCard(
                      icon: Icons.business_rounded,
                      iconColor: const Color(0xFF1565C0),
                      title: 'Parent Company',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 12,
                              color: Color(0xFF1565C0),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'aalbot.com',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      content:
                          'Daily Club is proudly owned by Aalbot — a technology company building digital solutions that empower local communities and small businesses.\n\nTap to visit the Aalbot website and learn more about our parent organisation.',
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2 — Our Mission
                _buildAnimatedCard(
                  index: 2,
                  child: _AboutCard(
                    icon: Icons.rocket_launch_rounded,
                    iconColor: const Color(0xFFFB8C00),
                    title: 'Our Mission',
                    content:
                        'To be the most trusted and convenient shopping companion for every family — delivering freshness, value, and smiles every single day.',
                    highlighted: true,
                    highlightColor: const Color(0xFFFB8C00),
                  ),
                ),
                const SizedBox(height: 14),

                // 3 — What We Offer
                _buildAnimatedCard(
                  index: 3,
                  child: _AboutCard(
                    icon: Icons.category_rounded,
                    iconColor: const Color(0xFF7B1FA2),
                    title: 'What We Offer',
                    bullets: const [
                      '🥬 Fresh fruits & vegetables',
                      '🧴 Personal care & hygiene',
                      '🏠 Home & kitchen essentials',
                      '🧃 Beverages & snacks',
                      '🌾 Grains, pulses & staples',
                      '🍶 Cooking oils & condiments',
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4 — Why Choose Us
                _buildAnimatedCard(
                  index: 4,
                  child: _AboutCard(
                    icon: Icons.verified_rounded,
                    iconColor: const Color(0xFF00838F),
                    title: 'Why Choose Us',
                    bullets: const [
                      '⚡ Fast doorstep delivery',
                      '💰 Competitive everyday prices',
                      '📦 Carefully packed products',
                      '🎯 Curated quality selection',
                      '💬 Responsive customer support',
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5 — Visit Aalbot CTA
                _buildAnimatedCard(
                  index: 5,
                  child: GestureDetector(
                    onTap: _openAalbot,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D2137), Color(0xFF1A4266)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0D2137,
                            ).withValues(alpha: 0.35),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.language_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Discover Aalbot',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Visit aalbot.com to explore more',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard({required int index, required Widget child}) {
    return FadeTransition(
      opacity: _cardFade[index],
      child: SlideTransition(position: _cardSlide[index], child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatBadge
// ─────────────────────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AboutCard
// ─────────────────────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.content,
    this.bullets,
    this.trailing,
    this.highlighted = false,
    this.highlightColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? content;
  final List<String>? bullets;
  final Widget? trailing;
  final bool highlighted;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: highlighted && highlightColor != null
            ? Border.all(
                color: highlightColor!.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (content != null) ...[
            const SizedBox(height: 14),
            Text(
              content!,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: highlighted
                    ? (highlightColor ?? const Color(0xFF555555))
                    : const Color(0xFF555555),
                height: 1.65,
              ),
            ),
          ],
          if (bullets != null) ...[
            const SizedBox(height: 14),
            ...bullets!.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  b,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF444444),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
