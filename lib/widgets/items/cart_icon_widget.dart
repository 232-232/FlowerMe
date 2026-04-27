import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Cart icon with optional badge count and bounce animation.
/// [cartIconKey] is used to read global position for add-to-cart flight target.
class CartIconWidget extends StatefulWidget {
  const CartIconWidget({
    super.key,
    required this.cartIconKey,
    required this.count,
    required this.bounceTrigger,
    this.onTap,
  });

  final GlobalKey cartIconKey;
  final int count;
  final int bounceTrigger;
  final VoidCallback? onTap;

  @override
  State<CartIconWidget> createState() => _CartIconWidgetState();
}

class _CartIconWidgetState extends State<CartIconWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;
  int _lastBounceTrigger = -1;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.22),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.22, end: 1),
        weight: 55,
      ),
    ]).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(CartIconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bounceTrigger != _lastBounceTrigger && widget.bounceTrigger > 0) {
      _lastBounceTrigger = widget.bounceTrigger;
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeScope.themeOf(context).primaryAccent;

    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _bounceAnimation.value,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            key: widget.cartIconKey,
            width: 56,
            height: 36,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  size: 17,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _formatCount(widget.count),
                    key: ValueKey<int>(widget.count),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
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

  static String _formatCount(int n) {
    if (n <= 0) return '00';
    if (n < 10) return '0$n';
    return n.toString();
  }
}
