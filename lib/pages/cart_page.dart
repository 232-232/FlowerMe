import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';

import '../cart_controller.dart';
import '../widgets/optimized_network_image.dart';
import '../cart_scope.dart';
import '../models/cart_entry.dart';
import '../models/stock_variant_model.dart';
import '../providers/stock_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/delivery_fee_service.dart';
import 'checkout_details_page.dart';
import 'payment_options_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY INSTRUCTIONS INPUT
// A self-contained stateful widget so the TextField can own its controller
// without making the entire CartPage stateful.
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryInstructionsField extends StatefulWidget {
  const _DeliveryInstructionsField({required this.cart});

  final CartController cart;

  @override
  State<_DeliveryInstructionsField> createState() =>
      _DeliveryInstructionsFieldState();
}

class _DeliveryInstructionsFieldState
    extends State<_DeliveryInstructionsField> {
  late final TextEditingController _controller;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.cart.deliveryInstruction);
    _expanded = widget.cart.deliveryInstruction.isNotEmpty;
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    widget.cart.updateDeliveryInstruction(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notes_rounded,
                      size: 18,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _controller.text.isNotEmpty
                          ? _controller.text
                          : 'Add delivery instructions',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _controller.text.isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _controller.text.isNotEmpty
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: const Color(0xFF22C55E),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'e.g. Leave at front door, ring the bell…',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(
                      color: Color(0xFF22C55E),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CART PAGE
// ─────────────────────────────────────────────────────────────────────────────

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartScope.of(context),
      builder: (context, _) {
        return _CartPageContent(cart: CartScope.of(context));
      },
    );
  }
}

class _CartPageContent extends StatefulWidget {
  const _CartPageContent({required this.cart});

  final CartController cart;

  @override
  State<_CartPageContent> createState() => _CartPageContentState();
}

class _CartPageContentState extends State<_CartPageContent>
    with TickerProviderStateMixin {
  late final AnimationController _staggerCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _floatCtrl;
  late final ConfettiController _confettiCtrl;
  String? _appliedPromoCode;

  /// Cached delivery info — null while loading or when GPS unavailable.
  DeliveryInfo? _deliveryInfo;
  String? _lastGpsForDelivery;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 1));
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    // Hydrate cart from saved profile so "Add your details" bar shows saved details
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cart = widget.cart;
      final profile = context.read<UserProfileProvider>();
      if (!cart.hasCustomerDetails && profile.hasCheckoutDetails) {
        cart.updateCustomerDetails(
          name: profile.name,
          phone: profile.phone,
          address: profile.address,
        );
      }
      // Compute delivery info if GPS coords already available.
      _refreshDeliveryInfo();
    });
  }

  void _refreshDeliveryInfo() {
    final gps = widget.cart.customerGpsCoords;
    if (gps == null || gps == _lastGpsForDelivery) return;
    _lastGpsForDelivery = gps;
    DeliveryFeeService.fromGpsString(gps).then((info) {
      if (mounted) setState(() => _deliveryInfo = info);
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  Widget _reveal(Widget child, double start, double end) {
    final anim = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(
        start.clamp(0.0, 1.0),
        end.clamp(0.0, 1.0),
        curve: const Cubic(0.22, 1, 0.36, 1),
      ),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Refresh delivery info whenever GPS coords change.
    _refreshDeliveryInfo();

    final entries = widget.cart.entries;
    final double deliveryCharge = _deliveryInfo?.deliveryFee ?? 0;
    final double subtotal = widget.cart.totalPrice;
    final double discount = _appliedPromoCode == 'FIRST10' ? subtotal * 0.1 : 0.0;
    final double grandTotal = math.max(0.0, subtotal + deliveryCharge - discount);
    final int itemCount = entries.fold(0, (sum, e) => sum + e.quantity);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
          Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
                children: [
                  // ── Sticky Nav ─────────────────────────────────────────
                  _StickyNav(
                    cart: widget.cart,
                    itemCount: itemCount,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  // ── Scrollable body + fixed bottom ─────────────────────
                  Expanded(
                    child: Stack(
                      children: [
                        CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  // Free delivery goal
                                  // _reveal(
                                  //   _FreeDeliveryBar(
                                  //       shimmerCtrl: _shimmerCtrl),
                                  //   0.0,
                                  //   0.45,
                                  // ),
                                  const SizedBox(height: 12),
                                  // Customer details (tap = edit, delete icon = clear)
                                  _reveal(
                                    _CustomerDetailsCard(
                                      cart: widget.cart,
                                      onTap: () async {
                                        final result = await Navigator.of(context)
                                            .push<Map<String, String>?>(
                                              CheckoutDetailsPage.route(
                                                showProceedToPayment: false,
                                              ),
                                            );
                                        if (!context.mounted) return;
                                        if (result != null) {
                                          widget.cart.updateCustomerDetails(
                                            name: result['name'] ?? '',
                                            phone: result['phone'] ?? '',
                                            address: result['address'] ?? '',
                                            gpsCoords: result['gpsCoords'],
                                          );
                                        }
                                      },
                                      onDelete: () async {
                                        final profile = context
                                            .read<UserProfileProvider>();
                                        widget.cart.clearCustomerDetails();
                                        await profile.clearCheckoutDetails();
                                      },
                                    ),
                                    0.08,
                                    0.5,
                                  ),
                                  const SizedBox(height: 12),
                                  // Delivery instructions
                                  _reveal(
                                    _DeliveryInstructionsField(cart: widget.cart),
                                    0.14,
                                    0.55,
                                  ),
                                  const SizedBox(height: 16),
                                  // Items or empty state
                                  if (entries.isEmpty)
                                    _reveal(
                                      _EmptyCart(floatCtrl: _floatCtrl),
                                      0.2,
                                      0.75,
                                    ),
                                ]),
                              ),
                            ),
                            if (entries.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, idx) {
                                      final item = entries[idx];
                                      final s = 0.2 + idx * 0.07;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _reveal(
                                          _CartItemCard(
                                            entry: item,
                                            index: idx,
                                            onRemove: () =>
                                                widget.cart.removeAt(idx),
                                            onQuantityChanged: (q) => widget.cart
                                                .updateQuantityAt(idx, q),
                                          ),
                                          s,
                                          s + 0.4,
                                        ),
                                      );
                                    },
                                    childCount: entries.length,
                                  ),
                                ),
                              ),
                            if (entries.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 180),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    // Promo code
                                    _reveal(
                                      Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          _PromoCard(
                                            appliedCode: _appliedPromoCode,
                                            onTap: () => _openPromoModal(context),
                                            onRemove: () => setState(() {
                                              _appliedPromoCode = null;
                                            }),
                                          ),
                                          if (_appliedPromoCode != null)
                                            ConfettiWidget(
                                              confettiController: _confettiCtrl,
                                              blastDirectionality: BlastDirectionality.explosive,
                                              maxBlastForce: 20,
                                              minBlastForce: 10,
                                              emissionFrequency: 0.1,
                                              numberOfParticles: 20,
                                              gravity: 0.15,
                                            ),
                                        ],
                                      ),
                                      0.45,
                                      0.85,
                                    ),
                                    const SizedBox(height: 16),
                                    // Order summary
                                    _reveal(
                                      _OrderSummaryCard(
                                        subtotal: subtotal,
                                        discount: discount,
                                        deliveryCharge: deliveryCharge,
                                        grandTotal: grandTotal,
                                        deliveryInfo: _deliveryInfo,
                                      ),
                                      0.55,
                                      0.95,
                                    ),
                                  ]),
                                ),
                              ),
                          ],
                        ),
                        // Fixed bottom checkout bar
                        if (entries.isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _BottomCheckoutBar(
                              grandTotal: grandTotal,
                              pulseCtrl: _pulseCtrl,
                              onCheckout: () async {
                                if (widget.cart.hasCustomerDetails) {
                                  if (!context.mounted) return;
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => PaymentOptionsPage(
                                        customerName:
                                            widget.cart.customerName ?? '',
                                        phoneNumber:
                                            widget.cart.customerPhone ?? '',
                                        address:
                                            widget.cart.customerAddress ?? '',
                                        gpsCoords: widget.cart.customerGpsCoords,
                                        deliveryInstruction:
                                            widget.cart.deliveryInstruction,
                                        subtotal: subtotal,
                                        discount: discount,
                                        deliveryCharge: deliveryCharge,
                                        grandTotal: grandTotal,
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final result = await Navigator.of(context)
                                    .push<Map<String, String>?>(
                                      CheckoutDetailsPage.route(
                                        showProceedToPayment: true,
                                      ),
                                    );
                                if (!context.mounted) return;
                                if (result != null) {
                                  widget.cart.updateCustomerDetails(
                                    name: result['name'] ?? '',
                                    phone: result['phone'] ?? '',
                                    address: result['address'] ?? '',
                                    gpsCoords: result['gpsCoords'],
                                  );
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => PaymentOptionsPage(
                                        customerName: result['name'] ?? '',
                                        phoneNumber: result['phone'] ?? '',
                                        address: result['address'] ?? '',
                                        gpsCoords: result['gpsCoords'] ?? widget.cart.customerGpsCoords,
                                        deliveryInstruction:
                                            widget.cart.deliveryInstruction,
                                        subtotal: subtotal,
                                        discount: discount,
                                        deliveryCharge: deliveryCharge,
                                        grandTotal: grandTotal,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                      ],
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
  }

  void _openPromoModal(BuildContext context) {
    if (_appliedPromoCode != null) return;
    
    final txt = TextEditingController();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Apply Promo Code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: txt,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter code (e.g. FIRST10)',
                      hintStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      final code = txt.text.trim().toUpperCase();
                      Navigator.of(ctx).pop(); // close modal
                      if (code == 'FIRST10') {
                        setState(() {
                          _appliedPromoCode = code;
                        });
                        _confettiCtrl.play();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, color: Colors.white),
                                SizedBox(width: 12),
                                Text(
                                  'Coupon applied! 10% discount added.',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF059669),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invalid or expired promo code.',
                              style: TextStyle(fontFamily: 'Poppins'),
                            ),
                            backgroundColor: Color(0xFFDC2626),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'APPLY',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STICKY NAV BAR
// ─────────────────────────────────────────────────────────────────────────────

class _StickyNav extends StatelessWidget {
  const _StickyNav({required this.cart, required this.itemCount, required this.onBack});

  final CartController cart;
  final int itemCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onBack();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Checkout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$itemCount ${itemCount == 1 ? 'Item' : 'Items'} • ~12 Mins',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (cart.entries.isNotEmpty || cart.hasSavedItems)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (cart.hasSavedItems) {
                      cart.restoreSavedOrder();
                    } else {
                      cart.saveForLater();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cart.hasSavedItems
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: cart.hasSavedItems
                            ? const Color(0xFFBFDBFE)
                            : const Color(0xFFBBF7D0),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      cart.hasSavedItems ? 'Add last order' : 'Save for later',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: cart.hasSavedItems
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// FREE DELIVERY PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────

// class _FreeDeliveryBar extends StatelessWidget {
//   const _FreeDeliveryBar({required this.shimmerCtrl});

//   final AnimationController shimmerCtrl;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(24),
//         border: Border.all(color: const Color(0xFFF1F5F9)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.04),
//             blurRadius: 30,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 32,
//                 height: 32,
//                 decoration: const BoxDecoration(
//                   color: Color(0xFFFFF7ED),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(
//                   Icons.local_shipping_rounded,
//                   size: 16,
//                   color: Color(0xFFEA580C),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               const Text(
//                 'Free Delivery Goal',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w700,
//                   color: Color(0xFF1E293B),
//                 ),
//               ),
//               const Spacer(),
//               const Text(
//                 '₹100 to go',
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w700,
//                   color: Color(0xFFEA580C),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Container(
//             height: 10,
//             decoration: BoxDecoration(
//               color: const Color(0xFFF1F5F9),
//               borderRadius: BorderRadius.circular(5),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   flex: 60,
//                   child: _ShimmerProgressFill(shimmerCtrl: shimmerCtrl),
//                 ),
//                 const Expanded(flex: 40, child: SizedBox.shrink()),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// Animated shimmer fill for the progress bar – uses a sliding white highlight
// over a solid green base, clipped to a rounded pill shape.
class _ShimmerProgressFill extends StatelessWidget {
  const _ShimmerProgressFill({required this.shimmerCtrl});

  final AnimationController shimmerCtrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: shimmerCtrl,
              builder: (context, _) {
                return FractionallySizedBox(
                  widthFactor: 0.35,
                  alignment: Alignment(-1 + 2 * shimmerCtrl.value, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMER DETAILS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerDetailsCard extends StatelessWidget {
  const _CustomerDetailsCard({
    required this.cart,
    required this.onTap,
    required this.onDelete,
  });

  final CartController cart;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool hasDetails = cart.hasCustomerDetails;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasDetails
                              ? (cart.customerName ?? '')
                              : 'Add your details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: hasDetails
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        if (hasDetails) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${cart.customerPhone ?? ''} • ${cart.customerAddress ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasDetails)
            IconButton(
              onPressed: () async {
                final confirm = await showGeneralDialog<bool>(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: 'Dismiss',
                  barrierColor: Colors.black.withValues(alpha: 0.5),
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (ctx, anim1, anim2) {
                    return Center(
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 40,
                                spreadRadius: -10,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon container
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 34,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Remove Details?',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Your saved name, phone and delivery address will be removed. You’ll be asked to add them again during checkout.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.of(ctx).pop(false);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'Keep',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        Navigator.of(ctx).pop(true);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'Remove',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  transitionBuilder: (ctx, anim1, anim2, child) {
                    final curve = Curves.easeOutBack.transform(anim1.value);
                    return BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: 8 * anim1.value,
                        sigmaY: 8 * anim1.value,
                      ),
                      child: Opacity(
                        opacity: anim1.value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.9 + (0.1 * curve),
                          child: child,
                        ),
                      ),
                    );
                  },
                );
                if (confirm == true) onDelete();
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 22,
                color: Color(0xFF94A3B8),
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 40),
                padding: EdgeInsets.zero,
              ),
            )
          else
            const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Color(0xFF22C55E),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY CART STATE  (floating icon animation)
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.floatCtrl});

  final AnimationController floatCtrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: floatCtrl,
              builder: (context, child) {
                final dy = math.sin(floatCtrl.value * 2 * math.pi) * 5;
                return Transform.translate(
                  offset: Offset(0, -dy),
                  child: child,
                );
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 40,
                  color: Color(0xFF818CF8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add items to get started',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CART ITEM CARD
// ─────────────────────────────────────────────────────────────────────────────

class _CartItemCard extends StatefulWidget {
  const _CartItemCard({
    required this.entry,
    required this.index,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final CartEntry entry;
  final int index;
  final VoidCallback onRemove;
  final void Function(int newQuantity) onQuantityChanged;

  @override
  State<_CartItemCard> createState() => _CartItemCardState();
}

class _CartItemCardState extends State<_CartItemCard> {
  late Stream<List<StockVariantModel>> _stockStream;

  @override
  void initState() {
    super.initState();
    _stockStream = StockProvider.stockStream(widget.entry.product.productCode);
  }

  @override
  void didUpdateWidget(covariant _CartItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.product.productCode != widget.entry.product.productCode) {
      _stockStream = StockProvider.stockStream(widget.entry.product.productCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int q = widget.entry.quantity;
    final CartEntry entry = widget.entry;

    return StreamBuilder<List<StockVariantModel>>(
      stream: _stockStream,
      builder: (context, snapshot) {
        int stockQty = -1;
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final vars = entry.product.variants;
          final targetId = (vars != null && vars.length > entry.variantIndex)
              ? vars[entry.variantIndex].variantId
              : 'base';

          final matchingVars = snapshot.data!.where((v) => v.variantId == targetId).toList();
          final match = matchingVars.isNotEmpty ? matchingVars.first : snapshot.data!.first;
          stockQty = match.quantity;
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image on dark background
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: OptimizedNetworkImage(
                    imageUrl: entry.product.image,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    placeholder: const Center(
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFF475569),
                        size: 32,
                      ),
                    ),
                    errorWidget: const Center(
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFF475569),
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Details column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.product.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                              height: 1.3,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onRemove();
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.variantLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          '₹${entry.lineTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1,
                          ),
                        ),
                        const Spacer(),
                        // Quantity stepper
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _QuantityBtn(
                                icon: Icons.remove_rounded,
                                color: const Color(0xFF94A3B8),
                                onTap: q > 1
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        widget.onQuantityChanged(q - 1);
                                      }
                                    : null,
                              ),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '$q',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              _QuantityBtn(
                                icon: Icons.add_rounded,
                                color: const Color(0xFF22C55E),
                                onTap: () {
                                  if (stockQty != -1 && q >= stockQty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Sorry, only $stockQty quantity left'),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  HapticFeedback.selectionClick();
                                  widget.onQuantityChanged(q + 1);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROMO CODE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    this.appliedCode,
    required this.onTap,
    this.onRemove,
  });

  final String? appliedCode;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    if (appliedCode != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "'$appliedCode' Applied",
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to remove if you want to use another code',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 40),
                foregroundColor: const Color(0xFF047857),
              ),
              child: const Text(
                'Remove',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF4338CA)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Apply Promo Code',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Save up to ₹50 on this order',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFBFDBFE),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Color(0x80FFFFFF),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDER SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.subtotal,
    required this.discount,
    required this.deliveryCharge,
    required this.grandTotal,
    this.deliveryInfo,
  });

  final double subtotal;
  final double discount;
  final double deliveryCharge;
  final double grandTotal;
  final DeliveryInfo? deliveryInfo;

  @override
  Widget build(BuildContext context) {
    final info = deliveryInfo;
    final bool hasGps = info != null;
    final bool isFree = !hasGps || info.isFreeDelivery;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Distance + ETA row (Swiggy inspired)
          if (hasGps) ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey(info.distanceKm),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Animated Delivery Partner Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF7ED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: Color(0xFFFF5200),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _AnimatedLabel(
                                text: info.etaLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _AnimatedLabel(
                                text: info.distanceLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'DELIVERY ESTIMATE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!info.isFreeDelivery)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '+${(info.distanceKm - 5).ceil()} km extra',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFEA580C),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              '₹10/km after 5km',
                              style: TextStyle(
                                fontSize: 8,
                                color: Color(0xFFC2410C),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          _SummaryRow(
            label: 'Items Subtotal',
            value: '₹${subtotal.toStringAsFixed(0)}',
          ),
          if (discount > 0) ...[
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Coupon Offer',
              value: '-₹${discount.toStringAsFixed(0)}',
              valueColor: const Color(0xFF16A34A),
            ),
          ],
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Delivery Fee',
            trailingIcon: Icons.info_outline_rounded,
            valueWidget: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isFree
                  ? Row(
                      key: const ValueKey('free'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!hasGps)
                          const Text(
                            '₹49',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        if (!hasGps) const SizedBox(width: 6),
                        const Text(
                          'FREE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      key: const ValueKey('paid'),
                      '₹${deliveryCharge.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEA580C),
                      ),
                    ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL AMOUNT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '₹${grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 12,
                      color: Color(0xFF059669),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Secure SSL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                        letterSpacing: 0.5,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    this.value,
    this.valueColor,
    this.valueWidget,
    this.trailingIcon,
  });

  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? valueWidget;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 4),
          Icon(trailingIcon, size: 13, color: const Color(0xFF94A3B8)),
        ],
        const Spacer(),
        if (valueWidget != null)
          valueWidget!
        else if (value != null)
          Text(
            value!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF1E293B),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM CHECKOUT BAR  (frosted glass + pulsing button)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomCheckoutBar extends StatelessWidget {
  const _BottomCheckoutBar({
    required this.grandTotal,
    required this.pulseCtrl,
    required this.onCheckout,
  });

  final double grandTotal;
  final AnimationController pulseCtrl;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 40,
                offset: const Offset(0, -20),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              // Pulsing ring that expands and fades outward from the button
              child: AnimatedBuilder(
                animation: pulseCtrl,
                builder: (context, child) {
                  final t = pulseCtrl.value;
                  final spread = t < 0.7 ? (t / 0.7) * 12.0 : 0.0;
                  final opacity = t < 0.7 ? (1 - t / 0.7) * 0.35 : 0.0;
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF16A34A,
                          ).withValues(alpha: opacity),
                          spreadRadius: spread,
                          blurRadius: spread * 1.5,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onCheckout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Proceed to Pay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED QUANTITY BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _QuantityBtn extends StatelessWidget {
  const _QuantityBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? color.withValues(alpha: 0.35) : color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CART DELIVERY CHIP  (used in _OrderSummaryCard)
// ─────────────────────────────────────────────────────────────────────────────

class _CartDeliveryChip extends StatelessWidget {
  const _CartDeliveryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          _AnimatedLabel(
            text: label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedLabel extends StatelessWidget {
  const _AnimatedLabel({required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.4),
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
        text,
        key: ValueKey(text),
        style: style,
      ),
    );
  }
}
