import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import '../providers/user_profile_provider.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SuggestionBoxPage
// ─────────────────────────────────────────────────────────────────────────────

class SuggestionBoxPage extends StatefulWidget {
  const SuggestionBoxPage({super.key});

  @override
  State<SuggestionBoxPage> createState() => _SuggestionBoxPageState();
}

class _SuggestionBoxPageState extends State<SuggestionBoxPage>
    with TickerProviderStateMixin {
  final TextEditingController _suggestionCtrl = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();
  bool _hasFocus = false;
  bool _isSaving = false;
  bool _saved = false;

  late final AnimationController _headerCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  late final AnimationController _cardCtrl;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;
  late final Animation<double> _successFade;

  late final AnimationController _btnCtrl;
  late final Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();

    _fieldFocus.addListener(() {
      if (mounted) setState(() => _hasFocus = _fieldFocus.hasFocus);
    });

    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
    _headerSlide = Tween<Offset>(
            begin: const Offset(0, -0.08), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _headerCtrl, curve: Curves.easeOutCubic));

    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _cardCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
    _cardSlide = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));

    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _successScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut));
    _successFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _successCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));

    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _btnScale = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerCtrl.forward();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _cardCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _suggestionCtrl.dispose();
    _fieldFocus.dispose();
    _headerCtrl.dispose();
    _cardCtrl.dispose();
    _successCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _suggestionCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your suggestion first!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    await _btnCtrl.forward();
    await _btnCtrl.reverse();

    setState(() => _isSaving = true);

    final profile = context.read<UserProfileProvider>();
    final phone = profile.phone.replaceAll(RegExp(r'\D'), '');
    final name = profile.name.isEmpty ? 'Anonymous' : profile.name;
    final now = DateTime.now();
    final timeStr =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)} ${_pad(now.hour)}:${_pad(now.minute)}';

    try {
      final ref =
          FirebaseDatabase.instance.ref('root/userSugges/$phone');
      await ref.push().set({
        'name': name,
        'phone': phone,
        'time': timeStr,
        'suggestion': text,
      });

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saved = true;
        });
        _successCtrl.forward();
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

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
          // ── Header ────────────────────────────────────────────────────
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
                              child: const Icon(Icons.lightbulb_rounded,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Suggestion Box',
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
                                    'Share your ideas to help us improve',
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

          // ── Body ───────────────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _cardFade,
              child: SlideTransition(
                position: _cardSlide,
                child: _saved
                    ? _buildSuccess(accent)
                    : _buildForm(accent, secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(Color accent, Color secondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info chips
          Consumer<UserProfileProvider>(
            builder: (_, profile, __) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                    icon: Icons.person_rounded,
                    label: profile.name.isEmpty ? 'No name' : profile.name,
                    accent: accent),
                _InfoChip(
                    icon: Icons.phone_rounded,
                    label: profile.phone.isEmpty
                        ? 'No phone'
                        : '+91 ${profile.phone}',
                    accent: accent),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Suggestion field card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 14,
                    offset: Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Suggestion',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'We read every single suggestion!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    color: _hasFocus
                        ? accent.withValues(alpha: 0.04)
                        : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _hasFocus ? accent : const Color(0xFFE0E2E6),
                      width: _hasFocus ? 1.8 : 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: _suggestionCtrl,
                    focusNode: _fieldFocus,
                    maxLines: 7,
                    minLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    cursorColor: accent,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF1A1A1A),
                      height: 1.6,
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'Type your idea, suggestion or feedback here...',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Color(0xFFBEC2C8),
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          ScaleTransition(
            scale: _btnScale,
            child: GestureDetector(
              onTap: _isSaving ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.38),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: _isSaving
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Send Suggestion',
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
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Your info is kept private and never shared.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FadeTransition(
          opacity: _successFade,
          child: ScaleTransition(
            scale: _successScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.check_circle_rounded, size: 60, color: accent),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Thank you! 🎉',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your suggestion has been received.\nWe truly appreciate your feedback!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.5,
                    height: 1.6,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Back to Menu',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InfoChip
// ─────────────────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border:
            Border.all(color: accent.withValues(alpha: 0.3), width: 1.2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
