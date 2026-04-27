import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CustomerCarePage
// ─────────────────────────────────────────────────────────────────────────────

class CustomerCarePage extends StatefulWidget {
  const CustomerCarePage({super.key});

  @override
  State<CustomerCarePage> createState() => _CustomerCarePageState();
}

class _CustomerCarePageState extends State<CustomerCarePage>
    with TickerProviderStateMixin {
  static const String _waNumber = '919539576024';

  int? _selectedIndex;

  late final AnimationController _headerCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  late final AnimationController _listCtrl;
  late final List<Animation<double>> _itemFade;
  late final List<Animation<Offset>> _itemSlide;

  late final AnimationController _btnCtrl;
  late final Animation<double> _btnScale;

  static const List<_CareReason> _reasons = [
    _CareReason(
      icon: Icons.local_shipping_rounded,
      title: 'Order Status',
      subtitle: 'Where is my last order?',
      message: 'Hi! I want to know the status of my last order.',
    ),
    _CareReason(
      icon: Icons.cancel_rounded,
      title: 'Cancel My Order',
      subtitle: 'I need to cancel my current order',
      message: 'Hi! I would like to cancel my order. Please help.',
    ),
    _CareReason(
      icon: Icons.sentiment_dissatisfied_rounded,
      title: 'Product Quality Issue',
      subtitle: 'The product I received is not good',
      message:
          'Hi! I received a product that is damaged or not of good quality. I need assistance.',
    ),
    _CareReason(
      icon: Icons.swap_horiz_rounded,
      title: 'Exchange / Return',
      subtitle: 'I want to return or exchange an item',
      message: 'Hi! I would like to return or exchange a product I received.',
    ),
    _CareReason(
      icon: Icons.payment_rounded,
      title: 'Payment Issue',
      subtitle: 'Problem with my payment or refund',
      message: 'Hi! I have an issue with my payment or pending refund.',
    ),
    _CareReason(
      icon: Icons.help_outline_rounded,
      title: 'Other Issue',
      subtitle: 'Something else I need help with',
      message: 'Hi! I need help with an issue regarding Daily Club.',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    _listCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _itemFade = List.generate(_reasons.length, (i) {
      final start = (0.08 + i * 0.10).clamp(0.0, 0.85);
      final end = (start + 0.38).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _listCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });
    _itemSlide = List.generate(_reasons.length, (i) {
      final start = (0.08 + i * 0.10).clamp(0.0, 0.85);
      final end = (start + 0.38).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0.0, 0.18),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _listCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _btnScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerCtrl.forward();
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _listCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _listCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    HapticFeedback.mediumImpact();
    await _btnCtrl.forward();
    await _btnCtrl.reverse();

    final reason = _reasons[_selectedIndex!];
    final encodedMsg = Uri.encodeComponent(reason.message);
    final uri = Uri.parse('https://wa.me/$_waNumber?text=$encodedMsg');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp'),
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
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          FadeTransition(
            opacity: _headerFade,
            child: SlideTransition(
              position: _headerSlide,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [gradientColors.first, gradientColors.last],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.headset_mic_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Customer Care',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'How can we help you today?',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
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

          // ── Reason list ─────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a reason',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _reasons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final selected = _selectedIndex == i;
                        return FadeTransition(
                          opacity: _itemFade[i],
                          child: SlideTransition(
                            position: _itemSlide[i],
                            child: _ReasonTile(
                              reason: _reasons[i],
                              selected: selected,
                              accent: accent,
                              secondary: secondary,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedIndex = i);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── WhatsApp CTA ─────────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: _selectedIndex != null
                ? Padding(
                    key: const ValueKey('btn'),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: ScaleTransition(
                      scale: _btnScale,
                      child: GestureDetector(
                        onTap: _openWhatsApp,
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF25D366)
                                    .withValues(alpha: 0.4),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_rounded,
                                  color: Colors.white, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Chat on WhatsApp',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('empty'), height: 24),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReasonTile
// ─────────────────────────────────────────────────────────────────────────────

class _ReasonTile extends StatefulWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.accent,
    required this.secondary,
    required this.onTap,
  });

  final _CareReason reason;
  final bool selected;
  final Color accent;
  final Color secondary;
  final VoidCallback onTap;

  @override
  State<_ReasonTile> createState() => _ReasonTileState();
}

class _ReasonTileState extends State<_ReasonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selCtrl;
  late final Animation<double> _selScale;

  @override
  void initState() {
    super.initState();
    _selCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _selScale = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _selCtrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(_ReasonTile old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _selCtrl.forward().then((_) => _selCtrl.reverse());
    }
  }

  @override
  void dispose() {
    _selCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _selScale,
      builder: (_, child) =>
          Transform.scale(scale: _selScale.value, child: child),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: widget.selected
              ? widget.accent.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                widget.selected ? widget.accent : const Color(0xFFE8EAED),
            width: widget.selected ? 1.8 : 1.0,
          ),
          boxShadow: [
            if (widget.selected)
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              )
            else
              const BoxShadow(
                color: Color(0x08000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: widget.accent.withValues(alpha: 0.1),
            highlightColor: widget.accent.withValues(alpha: 0.05),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.selected
                          ? widget.accent.withValues(alpha: 0.15)
                          : const Color(0xFFF0F1F3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.reason.icon,
                      size: 22,
                      color: widget.selected
                          ? widget.accent
                          : const Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.reason.title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.selected
                                ? widget.accent
                                : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.reason.subtitle,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.selected
                          ? widget.accent
                          : Colors.transparent,
                      border: Border.all(
                        color: widget.selected
                            ? widget.accent
                            : const Color(0xFFCCCCCC),
                        width: 1.8,
                      ),
                    ),
                    child: widget.selected
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
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

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _CareReason {
  const _CareReason({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String message;
}
