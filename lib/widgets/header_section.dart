import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Top bar matching the reference screenshot proportions.
// class HeaderSection extends StatelessWidget {
//   const HeaderSection({super.key, this.onCartPressed});

//   final VoidCallback? onCartPressed;

//   @override
//   Widget build(BuildContext context) {
//     final appTheme = AppThemeScope.themeOf(context);

//     return Padding(
//       padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
//       child: Row(
//         children: [
//           const _DrawerIconButton(),
//           const SizedBox(width: 10),
//           const Text(
//             'Daily Club',
//             style: TextStyle(
//               fontSize: 17,
//               fontWeight: FontWeight.w700,
//               letterSpacing: -0.2,
//               color: Colors.white,
//             ),
//           ),
//           const SizedBox(width: 8),
//           Container(
//             height: 28,
//             padding: const EdgeInsets.symmetric(horizontal: 10),
//             decoration: BoxDecoration(
//               color: appTheme.upgradeButtonBg.withValues(alpha: 0.22),
//               borderRadius: BorderRadius.circular(18),
//               border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
//             ),
//             child: const Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.arrow_upward, size: 12, color: Color(0xFFC6FFE1)),
//                 SizedBox(width: 3),
//                 Text(
//                   'Upgrade',
//                   style: TextStyle(
//                     color: Color(0xFFC6FFE1),
//                     fontSize: 11,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 8),
//           const _ThemeToggleButton(),
//           const Spacer(),
//           InkWell(
//             onTap: () {},
//             borderRadius: BorderRadius.circular(14),
//             child: Container(
//               height: 36,
//               width: 36,
//               decoration: BoxDecoration(
//                 color: Colors.white.withValues(alpha: 0.18),
//                 borderRadius: BorderRadius.circular(14),
//                 border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
//               ),
//               child: const Icon(
//                 Icons.person_outline_rounded,
//                 color: Colors.white,
//                 size: 19,
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           InkWell(
//             onTap: onCartPressed,
//             borderRadius: BorderRadius.circular(14),
//             child: Container(
//               height: 36,
//               padding: const EdgeInsets.symmetric(horizontal: 12),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(14),
//               ),
//               child: const Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(
//                     Icons.shopping_cart_outlined,
//                     color: Color(0xFF202020),
//                     size: 17,
//                   ),
//                   SizedBox(width: 7),
//                   Text(
//                     '00',
//                     style: TextStyle(
//                       color: Color(0xFF202020),
//                       fontSize: 13,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// ─────────────────────────────────────────────────────────────────────────────
// Animated drawer trigger icon
// ─────────────────────────────────────────────────────────────────────────────

/// Circular translucent button with a looping pulse ring, making it obvious
/// the grocery icon is tappable and opens the profile drawer.
class _DrawerIconButton extends StatefulWidget {
  const _DrawerIconButton();

  @override
  State<_DrawerIconButton> createState() => _DrawerIconButtonState();
}

class _DrawerIconButtonState extends State<_DrawerIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _ringScale = Tween<double>(
      begin: 1.0,
      end: 1.7,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));

    _ringOpacity = Tween<double>(
      begin: 0.45,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _openDrawer(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.hasDrawer) {
      scaffold.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDrawer(context),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outward pulse ring
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Transform.scale(
                  scale: _ringScale.value,
                  child: Opacity(
                    opacity: _ringOpacity.value,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ),
              // Solid circle background
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.40),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.local_grocery_store_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill button between "Upgrade" and cart to switch color themes.
class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeScope.of(context);
    final theme = controller.theme;

    return InkWell(
      onTap: controller.cycleTheme,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.color_lens_outlined,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              theme.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
