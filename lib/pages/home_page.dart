import 'dart:async';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../cart_scope.dart';

import '../providers/order_provider.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/profile_drawer.dart';
import '../widgets/suggestion_box.dart';
import '../widgets/category_grid.dart';
import '../widgets/hero_banner.dart';
import '../widgets/trending_section.dart';
import '../widgets/deal_banner.dart';
import '../widgets/best_sellers.dart';
import '../widgets/partner_stores_section.dart';
import '../widgets/floating_cart_bar.dart';
import '../widgets/track_order_fab.dart';
import '../widgets/global_search_overlay.dart';
import 'cart_page.dart';
import 'items_page.dart';
import 'login_page.dart';
import 'package:flutter/cupertino.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Global style
// ─────────────────────────────────────────────────────────────────────────────

const Color primaryGreen = Color(0xff0B3D2E);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const ProfileDrawer(),
      backgroundColor: const Color(0xffF3F4F6),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const _HomeHeaderSliver(),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              // Marquee ticker
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: RepaintBoundary(child: SuggestionBox()),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              // Hero banner
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: HeroBanner(
                    onBuyNow: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => const ItemsPage(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              // Category grid
              const CategoryGrid(),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
              // Trending products
              const SliverToBoxAdapter(
                child: RepaintBoundary(child: TrendingSection()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
              // Exclusive deals
              const SliverToBoxAdapter(
                child: RepaintBoundary(child: DealBannerSection()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
              // Best sellers
              const BestSellersGrid(),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              // Partner Stores
              const SliverToBoxAdapter(
                child: RepaintBoundary(child: PartnerStoresSection()),
              ),

              // Extra bottom padding so content does not hide behind cart bar
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          const FloatingCartBar(),
          Consumer<OrderProvider>(
            builder: (context, orderProvider, _) {
              final activeOrders = orderProvider.activeOrders;
              if (activeOrders.isEmpty) {
                return const SizedBox.shrink();
              }
              final latestOrder = activeOrders.first;
              return RepaintBoundary(
                child: DraggableTrackOrderFab(
                  orderId: latestOrder.orderId,
                  activeCount: activeOrders.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sliver AppBar with collapsing top section and sticky search bar
// ─────────────────────────────────────────────────────────────────────────────

class _HomeHeaderSliver extends StatelessWidget {
  const _HomeHeaderSliver();

  static const double _expandedHeight = 120;

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final headerColor = AppThemeScope.themeOf(context).gradientTop;

    return SliverAppBar(
      pinned: true,
      expandedHeight: _expandedHeight + topPadding,
      automaticallyImplyLeading: false,
      backgroundColor: headerColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double maxHeight = _expandedHeight + topPadding;
          final double minHeight = kToolbarHeight + topPadding;
          final double t =
              ((constraints.biggest.height - minHeight) /
                      (maxHeight - minHeight))
                  .clamp(0.0, 1.0);

          return Container(
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: topPadding + 8 * t,
                left: 20,
                right: 20,
                bottom: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FIX 11 (Layout Extension): Restore height compression via Align
                  // and ClipRect to prevent RenderFlex overflow when shrinking,
                  // without the GPU-expensive Opacity wrapper.
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      heightFactor: t > 0 ? t : 0.0,
                      child: const _TopHeaderRow(),
                    ),
                  ),
                  SizedBox(height: 8 * t + 4),
                  const _SearchBarPill(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopHeaderRow extends StatelessWidget {
  const _TopHeaderRow();

  static final _titleStyle = TextStyle(
    fontFamily: "PlusJakartaSans",
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
  );

  static final _subtitleStyle = TextStyle(
    fontFamily: "PlusJakartaSans",
    color: Colors.white.withValues(alpha: 0.7),
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _DrawerButton(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('DAILY CLUB', style: _titleStyle),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('instant delivery', style: _subtitleStyle),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [_ThemeToggleChip(), _LoginIcon(), _CartIconWithBadge()],
        ),
      ],
    );
  }
}

// FIX: Make const-constructible. Merged tap state into a single bool with
// one consolidated setState, removing previous 3-separate-setState pattern.
class _DrawerButton extends StatefulWidget {
  const _DrawerButton();

  @override
  State<_DrawerButton> createState() => _DrawerButtonState();
}

class _DrawerButtonState extends State<_DrawerButton> {
  bool _pressed = false;

  void _openDrawer() {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.hasDrawer) {
      scaffold.openDrawer();
    }
  }

  // FIX: Single setState call path using a helper to avoid 3 separate rebuilds
  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: _openDrawer,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.menu_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _CartIconWithBadge extends StatelessWidget {
  const _CartIconWithBadge();

  static final _badgeStyle = TextStyle(
    fontFamily: "PlusJakartaSans",
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              splashColor: Colors.white.withValues(alpha: 0.1),
              highlightColor: Colors.white.withValues(alpha: 0.05),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CartPage()),
                );
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: ListenableBuilder(
            listenable: cart,
            builder: (context, _) {
              final count = cart.count;
              if (count == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text('$count', style: _badgeStyle),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LoginIcon extends StatelessWidget {
  const _LoginIcon();

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, profile, _) {
        final loggedIn = profile.isLoggedIn;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            splashColor: Colors.white.withValues(alpha: 0.1),
            highlightColor: Colors.white.withValues(alpha: 0.05),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
              );
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: loggedIn
                    ? Colors.greenAccent.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: loggedIn
                      ? Colors.greenAccent.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(
                loggedIn ? Icons.person_rounded : Icons.person_outline_rounded,
                color: loggedIn ? Colors.greenAccent : Colors.white,
                size: 22,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThemeToggleChip extends StatelessWidget {
  const _ThemeToggleChip();

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

// ─────────────────────────────────────────────────────────────────────────────
// Search bar pill — taps to open full-screen GlobalSearchOverlay
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBarPill extends StatefulWidget {
  const _SearchBarPill();

  @override
  State<_SearchBarPill> createState() => _SearchBarPillState();
}

class _SearchBarPillState extends State<_SearchBarPill>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  // Cycling hint strings
  static const _hints = [
    'Search "Milk"',
    'Search "Rice"',
    'Search "Soap"',
    'Search "Fruits"',
    'Search "Snacks"',
  ];
  int _hintIndex = 0;
  Timer? _hintTimer;

  // Animation for hint text swap
  late final AnimationController _hintCtrl;
  late final Animation<double> _hintFade;

  @override
  void initState() {
    super.initState();
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..value = 1.0;
    _hintFade = CurvedAnimation(parent: _hintCtrl, curve: Curves.easeInOut);
    _startHintCycle();
  }

  void _startHintCycle() {
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;

      final route = ModalRoute.of(context);
      if (route == null ||
          !route.isCurrent ||
          (route.animation?.isAnimating ?? false)) {
        return;
      }

      _hintCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _hintIndex = (_hintIndex + 1) % _hints.length;
        });
        _hintCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hintCtrl.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _openSearch() async {
    final q = await showGlobalSearch(context);
    if (!mounted || q == null || q.isEmpty) return;
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => ItemsPage(initialSearchQuery: q)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeScope.themeOf(context).primaryAccent;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            splashColor: accent.withValues(alpha: 0.08),
            highlightColor: accent.withValues(alpha: 0.04),
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) {
              _setPressed(false);
              _openSearch();
            },
            onTapCancel: () => _setPressed(false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FadeTransition(
                      opacity: _hintFade,
                      child: Text(
                        _hints[_hintIndex],
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 28), // Spacer instead of mic
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
