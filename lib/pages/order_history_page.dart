import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/order_model.dart';
import '../models/product.dart';
import '../providers/user_profile_provider.dart';
import '../services/firebase_order_service.dart';
import '../theme/app_colors.dart';
import 'product_details_page.dart';
import '../widgets/optimized_network_image.dart';
import '../cart_scope.dart';
import 'cart_page.dart';
import '../services/search_service.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({Key? key}) : super(key: key);

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  static List<OrderModel>? _cachedOrders;
  static String? _cachedPhone;

  bool _isLoading = true;
  List<OrderModel> _orders = [];
  int _selectedFilter = 0; // 0: All, 1: Delivered, 2: Cancelled

  final ScrollController _scrollController = ScrollController();
  bool _isCompact = false;
  String _userName = 'User';

  int get _totalSpent => _orders
      .where((o) => o.status != 'cancelled')
      .fold(0, (sum, o) => sum + o.totalPrice.toInt());
  int get _totalItems => _orders
      .where((o) => o.status != 'cancelled')
      .fold(0, (sum, o) => sum + o.quantity);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 1. Try to load from cache IMMEDIATELY and SYNCHRONOUSLY
    // to prevent the 400ms shimmer "flash" for repeat visits.
    final profile = context.read<UserProfileProvider>();
    final currentPhone = profile.phone;
    if (_cachedOrders != null &&
        _cachedPhone == currentPhone &&
        currentPhone.isNotEmpty) {
      _orders = _cachedOrders!;
      _isLoading = false;
      _userName = profile.name.isNotEmpty ? profile.name : 'User';
    } else {
      _isLoading = true;
    }

    // 2. Refresh from network in background with a delay to keep the
    // page-entry animation (Hero, Slide) buttery smooth.
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _fetchOrders(showLoader: _orders.isEmpty);
    });
  }

  void _initData() {
    // This is now redundant but kept for safety if needed elsewhere
    _fetchOrders(showLoader: _orders.isEmpty);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final compact = _scrollController.offset > 50;
    if (compact != _isCompact) {
      setState(() => _isCompact = compact);
    }
  }

  Future<void> _fetchOrders({bool showLoader = true}) async {
    final profile = context.read<UserProfileProvider>();
    final currentPhone = profile.phone;

    if (currentPhone.isEmpty || profile.isGuest) {
      if (mounted) {
        setState(() {
          _orders = [];
          _isLoading = false;
          _userName = profile.name.isNotEmpty && !profile.isGuest
              ? profile.name
              : 'User';
        });
      }
      return;
    }

    if (showLoader) {
      setState(() => _isLoading = true);
    }

    _userName = profile.name.isNotEmpty ? profile.name : 'User';

    try {
      final fetchedOrders = await FirebaseOrderService.fetchUserOrders(
        currentPhone,
      );
      // Filter for only delivered and cancelled orders
      final validOrders = fetchedOrders
          .where((o) => o.status == 'delivered' || o.status == 'cancelled')
          .toList();

      // Update cache
      _cachedOrders = validOrders;
      _cachedPhone = currentPhone;

      if (mounted) {
        setState(() {
          _orders = validOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (showLoader) _orders = [];
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStatPill(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.65),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(AppThemeData appTheme, double topPadding) {
    final profile = context.watch<UserProfileProvider>();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: const Cubic(0.4, 0.0, 0.2, 1.0),
      padding: EdgeInsets.fromLTRB(
        24,
        topPadding + (_isCompact ? 16 : 52),
        24,
        _isCompact ? 32 : 68,
      ),
      decoration: BoxDecoration(
        color: appTheme.primaryAccent,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: appTheme.backgroundGradientColors,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_isCompact ? 28 : 48),
          bottomRight: Radius.circular(_isCompact ? 28 : 48),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x610B4A25),
            blurRadius: 52,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              Spacer(),
              const Text(
                'My Orders',
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              Spacer(),

              //   Container(
              //     width: 40, height: 40,
              //     decoration: BoxDecoration(
              //       color: Colors.white.withValues(alpha: 0.15),
              //       shape: BoxShape.circle,
              //       border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              //     ),
              //     child: Stack(
              //       alignment: Alignment.center,
              //       children: [
              //         const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 20),
              //         Positioned(
              //           top: 9, right: 9,
              //           child: Container(
              //             width: 8, height: 8,
              //             decoration: BoxDecoration(
              //               color: const Color(0xFFFF8C00),
              //               shape: BoxShape.circle,
              //               border: Border.all(color: const Color(0xFF16783C), width: 2),
              //             ),
              //           ),
              //         )
              //       ],
              //     ),
              //   ),
              // ],
            ],
          ),

          AnimatedContainer(
            duration: const Duration(milliseconds: 380),
            curve: const Cubic(0.4, 0.0, 0.2, 1.0),
            constraints: BoxConstraints(maxHeight: _isCompact ? 0 : 80),
            margin: EdgeInsets.only(top: _isCompact ? 0 : 24),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              curve: const Cubic(0.4, 0.0, 0.2, 1.0),
              opacity: _isCompact ? 0.0 : 1.0,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2.5,
                        ),
                        image: profile.avatarBytes != null
                            ? DecorationImage(
                                image: MemoryImage(profile.avatarBytes!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: profile.avatarBytes == null
                          ? const Icon(
                              Icons.shopping_cart_rounded,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                    const SizedBox(width: 13),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Hello, $_userName',
                              style: const TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.waving_hand_rounded,
                              color: Color(0xFFFFD54F),
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your complete delivery history',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          AnimatedContainer(
            duration: const Duration(milliseconds: 380),
            curve: const Cubic(0.4, 0.0, 0.2, 1.0),
            margin: EdgeInsets.only(top: _isCompact ? 10 : 20),
            child: Row(
              children: [
                _buildStatPill('Orders', _orders.length.toString()),
                const SizedBox(width: 10),
                _buildStatPill('Spent', '₹$_totalSpent'),
                const SizedBox(width: 10),
                _buildStatPill('Items', _totalItems.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndLabel(AppThemeData appTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildChip(0, 'All Orders', appTheme),
              const SizedBox(width: 8),
              _buildChip(1, 'Delivered', appTheme),
              const SizedBox(width: 8),
              _buildChip(2, 'Cancelled', appTheme),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Text(
            'RECENT ACTIVITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF6B8C76),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(int index, String label, AppThemeData appTheme) {
    final isActive = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? appTheme.primaryAccent : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive ? Colors.transparent : const Color(0xFFEAF2EC),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: appTheme.primaryAccent.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : const Color(0xFF6B8C76),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F5C2E).withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 38,
              color: Color(0xFF0F5C2E),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No orders yet',
            style: TextStyle(
              fontFamily: 'ClashDisplay',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D1F14),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your past orders\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B8C76),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeScope.themeOf(context);
    final topPadding = MediaQuery.of(context).padding.top;

    List<OrderModel> _filteredOrders = _orders;
    if (_selectedFilter == 1) {
      _filteredOrders = _orders.where((o) => o.status == 'delivered').toList();
    } else if (_selectedFilter == 2) {
      _filteredOrders = _orders.where((o) => o.status == 'cancelled').toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFDDE8E0),
      body: Column(
        children: [
          _buildHero(appTheme, topPadding),
          Expanded(
            child: _isLoading && _orders.isEmpty
                ? _HistoryShimmer(appTheme: appTheme)
                : CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildFiltersAndLabel(appTheme),
                      ),
                      if (_filteredOrders.isEmpty)
                        SliverToBoxAdapter(
                          child: _buildEmptyState(),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _OrderCard(order: _filteredOrders[index]),
                                );
                              },
                              childCount: _filteredOrders.length,
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 36),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.eco_rounded,
                                size: 14,
                                color: Color(0xFF6B8C76),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'All caught up — great choices!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B8C76),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isCancelled = order.status == 'cancelled';
    final glowColor = isCancelled
        ? const Color(0xFFEF9A9A)
        : const Color(0xFF3ECF6E);
    final badgeBg = isCancelled
        ? const Color(0xFFFFEBEE)
        : const Color(0xFFE3F4EB);
    final badgeText = isCancelled
        ? const Color(0xFFC62828)
        : const Color(0xFF0F5C2E);
    final badgeLabel = isCancelled ? 'Cancelled' : 'Delivered';
    final tickBg = isCancelled
        ? const Color(0xFFFFCDD2).withValues(alpha: 0.5)
        : const Color(0xFF1A8A47).withValues(alpha: 0.15);
    final tickIconColor = isCancelled
        ? const Color(0xFFD32F2F)
        : const Color(0xFF1A8A47);
    final tickIcon = isCancelled
        ? Icons.cancel_rounded
        : Icons.check_circle_rounded;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C0F5C2E),
            blurRadius: 40,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Left glow line
          Positioned(
            left: 0,
            top: 20,
            bottom: 20,
            width: 3,
            child: Container(
              decoration: BoxDecoration(
                color: glowColor,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(3),
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 18, 10),
                child: Row(
                  children: [
                    // Tick
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: tickBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: tickIconColor.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(tickIcon, color: tickIconColor, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.orderId}',
                            style: const TextStyle(
                              fontFamily: 'ClashDisplay',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D1F14),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 10,
                                color: Color(0xFF6B8C76),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatDate(order.orderDateTime),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B8C76),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.access_time_rounded,
                                size: 10,
                                color: Color(0xFF6B8C76),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatTime(order.orderDateTime),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B8C76),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(tickIcon, size: 11, color: badgeText),
                          const SizedBox(width: 4),
                          Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: badgeText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                margin: const EdgeInsets.only(left: 20, right: 20, top: 4),
                height: 1,
                color: const Color(0xFFEAF2EC),
              ),

              // Items Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 18, 6),
                child: Text(
                  '${order.quantity} ITEMS',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF1A8A47),
                  ),
                ),
              ),

              // Items List
              ...order.items.map((item) {
                return InkWell(
                  onTap: () async {
                    if (item.productCode == null || item.productCode!.isEmpty)
                      return;

                    final cached = SearchService.getProductSync(
                      item.productCode!,
                    );
                    String picUrl = cached?.picUrl ?? '';

                    if (picUrl.isEmpty) {
                      try {
                        final snap = await FirebaseDatabase.instance
                            .ref('root/products/${item.productCode}/pic')
                            .get();
                        if (snap.exists) picUrl = snap.value.toString();
                      } catch (_) {}
                    }

                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductDetailsPage(
                          product: Product(
                            name: item.name,
                            weight: cached?.weight ?? '',
                            image: picUrl,
                            price: item.price,
                            oldPrice: item.price,
                            discount: 0,
                            productCode: item.productCode!,
                          ),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 9, 18, 9),
                    child: Row(
                      children: [
                        _ProductImage(productCode: item.productCode),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D1F14),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Qty: ${item.quantity}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B8C76),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D1F14),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${item.quantity} × ₹${item.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B8C76),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Footer
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.fromLTRB(20, 13, 18, 15),
                decoration: const BoxDecoration(
                  border: const Border(
                    top: BorderSide(color: Color(0xFFEAF2EC)),
                  ),
                  gradient: LinearGradient(
                    colors: [Color(0xFFF6FBF8), Colors.white],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Total',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B8C76),
                          ),
                        ),
                        Text(
                          '₹${order.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: Color(0xFF0F5C2E),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final cart = CartScope.read(context);
                        cart.clear();

                        for (final item in order.items) {
                          if (item.productCode == null ||
                              item.productCode!.isEmpty)
                            continue;

                          final cached = SearchService.getProductSync(
                            item.productCode!,
                          );
                          String picUrl = cached?.picUrl ?? '';

                          if (picUrl.isEmpty) {
                            try {
                              final snap = await FirebaseDatabase.instance
                                  .ref('root/products/${item.productCode}/pic')
                                  .get();
                              if (snap.exists) picUrl = snap.value.toString();
                            } catch (_) {}
                          }

                          cart.addWithUi(
                            Product(
                              name: item.name,
                              weight: cached?.weight ?? '',
                              image: picUrl,
                              price: item.price,
                              oldPrice: item.price,
                              discount: 0,
                              productCode: item.productCode!,
                            ),
                            item.quantity,
                          );
                        }

                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CartPage()),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Reorder',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5C2E),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 6,
                        shadowColor: const Color(0x4D0F5C2E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatefulWidget {
  final String? productCode;
  const _ProductImage({this.productCode});

  @override
  State<_ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<_ProductImage> {
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.productCode != null && widget.productCode!.isNotEmpty) {
      FirebaseDatabase.instance
          .ref('root/products/${widget.productCode}/pic')
          .get()
          .then((snap) {
            if (snap.exists && mounted) {
              setState(() {
                imageUrl = snap.value.toString();
              });
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFE3F4EB),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Text('🛒', style: TextStyle(fontSize: 22)),
      );
    }
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFE3F4EB),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: OptimizedNetworkImage(
        imageUrl: imageUrl!,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        trackLogLabel: 'OrderHistory',
      ),
    );
  }
}

class _HistoryShimmer extends StatefulWidget {
  final AppThemeData appTheme;
  const _HistoryShimmer({required this.appTheme});

  @override
  State<_HistoryShimmer> createState() => _HistoryShimmerState();
}

class _HistoryShimmerState extends State<_HistoryShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final opacity = _anim.value;
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // Filters shimmer
            Row(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ShimmerBox(
                    width: 80,
                    height: 32,
                    radius: 20,
                    opacity: opacity,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Cards shimmer
            ...List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ShimmerBox(
                            width: 38,
                            height: 38,
                            radius: 19,
                            opacity: opacity,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ShimmerBox(
                                width: 120,
                                height: 14,
                                radius: 4,
                                opacity: opacity,
                              ),
                              const SizedBox(height: 6),
                              _ShimmerBox(
                                width: 80,
                                height: 10,
                                radius: 4,
                                opacity: opacity,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _ShimmerBox(
                        width: double.infinity,
                        height: 1,
                        radius: 0,
                        opacity: opacity,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _ShimmerBox(
                            width: 48,
                            height: 48,
                            radius: 12,
                            opacity: opacity,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ShimmerBox(
                                  width: 150,
                                  height: 12,
                                  radius: 4,
                                  opacity: opacity,
                                ),
                                const SizedBox(height: 6),
                                _ShimmerBox(
                                  width: 60,
                                  height: 10,
                                  radius: 4,
                                  opacity: opacity,
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
          ],
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final double opacity;
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Color.fromRGBO(226, 232, 240, opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
