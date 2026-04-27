import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// import '../../services/voice_search_service.dart'; // REMOVED


import 'cart_icon_widget.dart';

const List<String> _kHints = [
  "Search for 'Paneer'...",
  "Search for 'Masala'...",
  "Search for 'Milk'...",
  "Search for 'Tomatoes'...",
  "Search for 'Coriander'...",
];

class HeaderBar extends StatefulWidget {
  const HeaderBar({
    super.key,
    required this.onBack,
    required this.cartIconKey,
    required this.cartCount,
    required this.cartBounceTrigger,
    this.onCartTap,
    this.onSearchChanged,
    this.useLightStyle = false,
  });

  final VoidCallback onBack;
  final GlobalKey cartIconKey;
  final int cartCount;
  final int cartBounceTrigger;
  final VoidCallback? onCartTap;
  final ValueChanged<String>? onSearchChanged;
  final bool useLightStyle;

  @override
  State<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<HeaderBar>
    with SingleTickerProviderStateMixin {
  bool _searchActive = false;
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _animController;
  late final Animation<double> _fadeScaleAnim;

  // final VoiceSearchService _voiceService = VoiceSearchService(); // REMOVED
  // bool _isListening = false; // REMOVED

  int _hintIndex = 0;
  Timer? _hintTimer;

  static const Duration _dur = Duration(milliseconds: 300);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: _dur);
    _fadeScaleAnim = CurvedAnimation(
      parent: _animController,
      curve: _curve,
      reverseCurve: Curves.easeInCubic,
    );
    _startHintCycling();
  }

  void _startHintCycling() {
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _hintIndex = (_hintIndex + 1) % _kHints.length;
      });
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /* 
  void _startVoiceSearch() async {
    ... removed ...
  }
  */

  void _openSearch() {
    setState(() => _searchActive = true);
    _animController.forward();
  }

  void _closeSearch() {
    _animController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _searchActive = false);
      _searchController.clear();
      widget.onSearchChanged?.call('');
    });
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.useLightStyle ? Colors.white : const Color(0xFF222222);
    final searchBg = widget.useLightStyle
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFF2F3F3);
    final hintColor = widget.useLightStyle ? Colors.white60 : Colors.grey;

    return SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button
          GestureDetector(
            onTap: _searchActive ? _closeSearch : widget.onBack,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: fg),
                  ClipRect(
                    child: AnimatedSize(
                      duration: _dur,
                      curve: _curve,
                      child: _searchActive
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 5),
                                Text(
                                  'Back',
                                  style: TextStyle(fontFamily: "PlusJakartaSans", 
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: fg,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Search field (opens on tap) or cycling hint bar
          Expanded(
            child: _searchActive
                ? _buildActiveSearchField(searchBg, hintColor)
                : _buildCyclingHintBar(searchBg, hintColor, fg),
          ),

          const SizedBox(width: 8),

          // Cart icon (always visible)
          CartIconWidget(
            cartIconKey: widget.cartIconKey,
            count: widget.cartCount,
            bounceTrigger: widget.cartBounceTrigger,
            onTap: widget.onCartTap,
          ),
        ],
      ),
    );
  }

  Widget _buildCyclingHintBar(Color searchBg, Color hintColor, Color fg) {
    return GestureDetector(
      onTap: _openSearch,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: searchBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: hintColor),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.35),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _kHints[_hintIndex],
                  key: ValueKey<int>(_hintIndex),
                  style: TextStyle(fontFamily: "PlusJakartaSans", 
                    fontSize: 13,
                    color: hintColor,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideX(begin: 0.05, end: 0, duration: 200.ms);
  }

  Widget _buildActiveSearchField(Color searchBg, Color hintColor) {
    return AnimatedBuilder(
      animation: _fadeScaleAnim,
      builder: (context, _) {
        final v = _fadeScaleAnim.value;
        if (v == 0) return const SizedBox.shrink();
        return Opacity(
          opacity: v,
          child: Transform.scale(
            scaleX: 0.82 + 0.18 * v,
            alignment: Alignment.centerLeft,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: searchBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: _searchActive,
                onChanged: widget.onSearchChanged,
                style: TextStyle(fontFamily: "PlusJakartaSans", 
                  fontSize: 14,
                  color: widget.useLightStyle
                      ? Colors.white
                      : const Color(0xFF222222),
                ),
                decoration: InputDecoration(
                  hintText: 'Search products…',
                  hintStyle: TextStyle(fontFamily: "PlusJakartaSans", 
                    fontSize: 14,
                    color: hintColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 10),
                  isDense: true,
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 18, color: hintColor),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 34, minHeight: 40),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /* 
                      if (_searchController.text.isEmpty)
                        GestureDetector(
                          onTap: _startVoiceSearch,
                          ...
                        ),
                      */
                      GestureDetector(
                        onTap: _closeSearch,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: hintColor),
                        ),
                      ),
                    ],
                  ),
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 34, minHeight: 40),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
