import 'package:flutter/material.dart';

import '../cart_scope.dart';
import '../cart_controller.dart';
import '../pages/cart_page.dart';
import '../theme/app_colors.dart';
import 'cart_edit_bottom_sheet.dart';

class FloatingCartBar extends StatefulWidget {
  const FloatingCartBar({super.key});

  @override
  State<FloatingCartBar> createState() => _FloatingCartBarState();
}

class _FloatingCartBarState extends State<FloatingCartBar> {
  bool _buttonPressed = false;

  @override
  Widget build(BuildContext context) {
    final CartController cart = CartScope.of(context);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 24,
      child: ListenableBuilder(
        listenable: cart,
        builder: (context, _) {
          if (cart.count == 0) {
            return const SizedBox.shrink();
          }

          final int count = cart.count;
          final double total = cart.totalPrice;
          final accent = AppThemeScope.themeOf(context).primaryAccent;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      splashColor: Colors.white.withValues(alpha: 0.2),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      onTap: () => CartEditBottomSheet.show(context, cart),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CartPage(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${count} ITEMS',
                                style: const TextStyle(
                                  fontFamily: "PlusJakartaSans",
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontFamily: "PlusJakartaSans",
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          AnimatedScale(
                            scale: _buttonPressed ? 0.96 : 1.0,
                            duration: const Duration(milliseconds: 90),
                            curve: Curves.easeOut,
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'VIEW CART',
                                style: TextStyle(
                                  fontFamily: "PlusJakartaSans",
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
