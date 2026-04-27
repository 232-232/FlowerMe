import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../cart_scope.dart';
import '../models/checkout_details.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../services/delivery_fee_service.dart';
import '../services/firebase_order_service.dart';
import '../theme/app_colors.dart';
import 'order_success_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Payment Options Page
// ─────────────────────────────────────────────────────────────────────────────

class PaymentOptionsPage extends StatefulWidget {
  const PaymentOptionsPage({
    super.key,
    required this.customerName,
    required this.phoneNumber,
    required this.address,
    this.gpsCoords,
    this.deliveryInstruction = '',
    required this.subtotal,
    required this.discount,
    required this.deliveryCharge,
    required this.grandTotal,
  });

  final String customerName;
  final String phoneNumber;
  final String address;
  /// Raw GPS coordinates "lat, lng" for Firebase adrs field.
  /// Falls back to [address] when null.
  final String? gpsCoords;
  final String deliveryInstruction;
  final double subtotal;
  final double discount;
  final double deliveryCharge;
  final double grandTotal;

  @override
  State<PaymentOptionsPage> createState() => _PaymentOptionsPageState();
}

class _PaymentOptionsPageState extends State<PaymentOptionsPage> {
  String _selectedMethod = 'cod';
  bool _isPlacingOrder = false;

  bool _isPremiumUser = false;
  bool _isCheckingPremium = true;
  double _walletBalance = 1000.0;

  DeliveryInfo? _deliveryInfo;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    // Load delivery info from GPS coords (if available)
    Future.microtask(() async {
      final info = await DeliveryFeeService.fromGpsString(widget.gpsCoords);
      if (mounted && info != null) setState(() => _deliveryInfo = info);
    });
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final digitsOnly = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
      final last10Digits = digitsOnly.length > 10
              ? digitsOnly.substring(digitsOnly.length - 10)
              : digitsOnly;

      // Directly check walletusers node
      final walletSnap = await FirebaseDatabase.instance.ref('root/walletusers/$last10Digits').get();
      
      if (walletSnap.exists && walletSnap.value is Map) {
        final data = walletSnap.value as Map;
        final balance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final isEnabled = data['walletEnabled'] == true;

        if (mounted) {
          setState(() {
            // User is "premium" if wallet is enabled and has balance
            _isPremiumUser = isEnabled;
            _walletBalance = balance;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isPremiumUser = false;
            _walletBalance = 0.0;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isCheckingPremium = false);
    }
  }

  Future<void> _handlePay() async {
    if (_isPlacingOrder) return;
    setState(() => _isPlacingOrder = true);

    final cart = CartScope.of(context);

    // Build item list for Firebase: [{name, variantLabel, price, quantity}]
    final firebaseItems = cart.entries
        .map((e) => {
              'name': e.product.name,
              'variantLabel': e.variantLabel,
              'price': e.unitPrice.toStringAsFixed(0),
              'quantity': e.quantity.toString(),
              'productCode': e.product.productCode,
              'variantId': (e.product.variants != null && e.variantIndex < e.product.variants!.length)
                  ? e.product.variants![e.variantIndex].variantId
                  : 'base',
            })
        .toList();

    // Build local OrderModel items
    final orderItems = cart.entries
        .map((e) => OrderItemModel(
              name: e.product.name,
              price: e.unitPrice,
              quantity: e.quantity,
            ))
        .toList();

    // The adrs in Firebase is GPS coords when available, otherwise address text
    final adrsForFirebase = widget.gpsCoords ?? cart.customerGpsCoords ?? widget.address;

    // Build stock update list: [{productCode, variantId, count}]
    final stockUpdates = cart.entries.map((e) {
      // Find the variantId from the variants list or use 'base' if it's the main product
      String? vId;
      if (e.product.variants != null && e.variantIndex < e.product.variants!.length) {
        vId = e.product.variants![e.variantIndex].variantId;
      } else {
        // Fallback or legacy check
        vId = 'base';
      }

      return {
        'productCode': e.product.productCode,
        'variantId': vId,
        'count': e.quantity,
      };
    }).toList();

    try {
      // ── Write to Firebase RTDB and get atomic order number ─────────────
      final orderNumber = await FirebaseOrderService.placeOrder(
        name: widget.customerName,
        phone: widget.phoneNumber,
        address: adrsForFirebase,
        items: firebaseItems,
        stockUpdates: stockUpdates,
        walletDeductionAmount: _selectedMethod == 'wallet' ? widget.grandTotal : null,
        paymentMethod: '$_selectedMethod-${widget.grandTotal.toStringAsFixed(0)}',
      );

      if (!mounted) return;

      // ── Use the Firebase order number as the local orderId (e.g. "105") ─
      final orderId = '$orderNumber';

      final order = OrderModel(
        orderId: orderId,
        items: orderItems,
        totalPrice: widget.grandTotal,
        quantity: cart.count,
        orderDateTime: DateTime.now(),
        status: 'orderPlaced',
        deliveryDetails: CheckoutDetails(
          name: widget.customerName,
          phone: widget.phoneNumber,
          address: widget.address,
        ),
        paymentMethod: _selectedMethod,
        deliveryInstruction: widget.deliveryInstruction,
      );

      // ── Save locally and register for the floating track bar ───────────
      context.read<OrderProvider>().addOrder(order);
      CartScope.of(context).registerNewOrder(orderId: orderId);
      cart.clear();

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrderSuccessPage(order: order),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Show error — do NOT leave a half-placed order.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not place order: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeScope.themeOf(context);
    final grandTotalStr = widget.grandTotal.toStringAsFixed(0);
    final accent = appTheme.primaryAccent;

    // Subtly tint the background with the current theme accent
    final pageBackground = Color.lerp(
      const Color(0xFFF2F4F7),
      accent,
      0.04,
    )!;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: _PaymentAppBar(accent: accent),
      body: SafeArea(
        child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Delivery Address Header ───────────────────────────────
                  _AddressHeader(
                    phone: widget.phoneNumber,
                    address: widget.address,
                  ),
                  const SizedBox(height: 16),

                  // ── Offers Banner ─────────────────────────────────────────
                  _OffersBanner(accent: accent),
                  const SizedBox(height: 24),

                  // ── DAILY CLUB WALLET ─────────────────────────────────────
                  _SectionLabel(label: 'Daily Club Wallet'),
                  const SizedBox(height: 10),
                  _WalletCard(
                    accent: accent,
                    isEnabled: _isPremiumUser && _walletBalance >= widget.grandTotal,
                    isLoading: _isCheckingPremium,
                    selected: _selectedMethod == 'wallet',
                    balance: _walletBalance,
                    isPremium: _isPremiumUser,
                    onTap: () {
                      if (_isPremiumUser && _walletBalance >= widget.grandTotal) {
                        setState(() => _selectedMethod = 'wallet');
                      } else if (_isPremiumUser && _walletBalance < widget.grandTotal) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Insufficient wallet balance.'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── CASH / PAY ON DELIVERY ────────────────────────────────
                  _SectionLabel(label: 'Cash / Pay on Delivery'),
                  const SizedBox(height: 10),
                  _CodCard(
                    selected: _selectedMethod == 'cod',
                    onTap: () => setState(() => _selectedMethod = 'cod'),
                    accent: accent,
                  ),
                  const SizedBox(height: 24),

                  // ── OTHER METHODS ─────────────────────────────────────────
                  _SectionLabel(label: 'Other Methods'),
                  const SizedBox(height: 10),
                  const _UpiCard(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
      ),

      // ── Fixed bottom: Total + Slide to Pay ─────────────────────────────────
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TOTAL TO PAY',
                          style: TextStyle(fontFamily: "PlusJakartaSans", 
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹$grandTotalStr',
                          style: const TextStyle(fontFamily: "PlusJakartaSans", 
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => _showDetailedBill(context, accent),
                      style: TextButton.styleFrom(
                        foregroundColor: accent,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View Detailed Bill',
                        style: TextStyle(fontFamily: "PlusJakartaSans", 
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SlideToPayBar(
                  totalAmount: grandTotalStr,
                  primaryColor: accent,
                  onSuccess: _handlePay,
                  isLoading: _isPlacingOrder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailedBill(BuildContext context, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Detailed Bill',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),
              _BillRow(
                label: 'Items Subtotal',
                value: '₹${widget.subtotal.toStringAsFixed(0)}',
              ),
              if (widget.discount > 0) ...[
                const SizedBox(height: 12),
                _BillRow(
                  label: 'Coupon Offer',
                  value: '-₹${widget.discount.toStringAsFixed(0)}',
                  valueColor: const Color(0xFF16A34A),
                ),
              ],
              const SizedBox(height: 12),
              _BillRow(
                label: 'Delivery Fee',
                valueWidget: widget.deliveryCharge <= 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'FREE',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (_deliveryInfo != null) ...[  
                            const SizedBox(width: 8),
                            _AnimatedLabel(
                              text: _deliveryInfo!.distanceLabel,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${widget.deliveryCharge.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 16,
                              color: Color(0xFFEA580C),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (_deliveryInfo != null) ...[  
                            const SizedBox(width: 8),
                            _AnimatedLabel(
                              text: '• ${_deliveryInfo!.distanceLabel}',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              _BillRow(
                label: 'Grand Total',
                value: '₹${widget.grandTotal.toStringAsFixed(0)}',
                isBold: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF334155),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    this.value,
    this.valueColor,
    this.valueWidget,
    this.isBold = false,
  });

  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? valueWidget;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? const Color(0xFF111827) : const Color(0xFF64748B),
          ),
        ),
        if (valueWidget != null)
          valueWidget!
        else if (value != null)
          Text(
            value!,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? const Color(0xFF1E293B),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PaymentAppBar({required this.accent});

  final Color accent;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: Color(0xFF111827),
        ),
      ),
      title: Text(
        'Payment Options',
        style: TextStyle(fontFamily: "PlusJakartaSans", 
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF111827),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: const Color(0xFFE5E7EB),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Address Header Card
// ─────────────────────────────────────────────────────────────────────────────

class _AddressHeader extends StatelessWidget {
  const _AddressHeader({required this.phone, required this.address});

  final String phone;
  final String address;

  @override
  Widget build(BuildContext context) {
    final displayAddress = [
      if (phone.isNotEmpty) phone,
      if (address.isNotEmpty) address,
    ].join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Squircle home icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.home_rounded,
              color: Color(0xFFF97316),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DELIVERING TO HOME',
                  style: TextStyle(fontFamily: "PlusJakartaSans", 
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: const Color(0xFFF97316),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  displayAddress.isEmpty ? 'No address provided' : displayAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: "PlusJakartaSans", 
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
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

// ─────────────────────────────────────────────────────────────────────────────
// Section Label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontFamily: "PlusJakartaSans", 
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offers Banner
// ─────────────────────────────────────────────────────────────────────────────

class _OffersBanner extends StatelessWidget {
  const _OffersBanner({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_offer_rounded, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Save more with payment offers',
              style: TextStyle(fontFamily: "PlusJakartaSans", 
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 22, color: accent),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wallet Card
// ─────────────────────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.accent,
    required this.isEnabled,
    required this.isLoading,
    required this.selected,
    required this.balance,
    required this.isPremium,
    required this.onTap,
  });

  final Color accent;
  final bool isEnabled;
  final bool isLoading;
  final bool selected;
  final double balance;
  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeBg = accent.withValues(alpha: 0.06);

    return Opacity(
      opacity: isEnabled || isLoading ? 1.0 : 0.6,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Squircle wallet icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.12)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 22,
                  color: selected ? accent : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Wallet Credit',
                          style: TextStyle(fontFamily: "PlusJakartaSans", 
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (isLoading)
                          const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (isEnabled)
                          Text(
                            '₹${balance.toStringAsFixed(0)}',
                            style: TextStyle(fontFamily: "PlusJakartaSans", 
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          )
                        else
                          Text(
                            '₹${balance.toStringAsFixed(0)}',
                            style: const TextStyle(fontFamily: "PlusJakartaSans", 
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isLoading
                          ? 'Checking wallet eligibility...'
                          : isEnabled
                              ? 'Pay using your premium wallet balance'
                              : !isPremium 
                                  ? 'Unavailable for non-premium customers'
                                  : 'Insufficient balance to cover order',
                      style: TextStyle(fontFamily: "PlusJakartaSans", 
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontStyle: isLoading || !isEnabled ? FontStyle.italic : FontStyle.normal,
                        color: isLoading || !isEnabled ? Colors.red : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: accent,
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COD Card — active selectable payment method
// ─────────────────────────────────────────────────────────────────────────────

class _CodCard extends StatelessWidget {
  const _CodCard({
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppThemeScope.themeOf(context).primaryAccent;
    final activeBg = activeColor.withValues(alpha: 0.06);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: selected ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Squircle QR icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? activeColor.withValues(alpha: 0.12)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 22,
                color: selected ? activeColor : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash / UPI on Delivery',
                    style: TextStyle(fontFamily: "PlusJakartaSans", 
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pay via Cash or QR code at your doorstep',
                    style: TextStyle(fontFamily: "PlusJakartaSans", 
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // CircleAvatar checkmark
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? CircleAvatar(
                      key: const ValueKey('check'),
                      radius: 14,
                      backgroundColor: activeColor,
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    )
                  : const CircleAvatar(
                      key: ValueKey('uncheck'),
                      radius: 14,
                      backgroundColor: Color(0xFFE5E7EB),
                      child: SizedBox.shrink(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UPI Card — coming soon badge
// ─────────────────────────────────────────────────────────────────────────────

class _UpiCard extends StatelessWidget {
  const _UpiCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // Squircle bank icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              size: 22,
              color: Color(0xFFD1D5DB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Direct UPI Payment',
              style: TextStyle(fontFamily: "PlusJakartaSans", 
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
          // COMING SOON badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width * 0.02,
              vertical: MediaQuery.sizeOf(context).height * 0.005,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'COMING SOON',
              style: TextStyle(fontFamily: "PlusJakartaSans", 
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.orange.shade700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide to Pay Bar — interactive thumb with snap-back physics
// ─────────────────────────────────────────────────────────────────────────────

class _SlideToPayBar extends StatefulWidget {
  const _SlideToPayBar({
    required this.totalAmount,
    required this.primaryColor,
    required this.onSuccess,
    required this.isLoading,
  });

  final String totalAmount;
  final Color primaryColor;
  final VoidCallback onSuccess;
  final bool isLoading;

  @override
  State<_SlideToPayBar> createState() => _SlideToPayBarState();
}

class _SlideToPayBarState extends State<_SlideToPayBar>
    with SingleTickerProviderStateMixin {
  double _dragValue = 0.0;
  bool _isSuccess = false;

  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;

  static const double _thumbSize = 56.0;
  static const double _thumbPad = 4.0;
  static const Color _successColor = Color(0xFF065F27);

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isSuccess) return;
    setState(() {
      _dragValue = (_dragValue + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details, double maxDrag) {
    if (_isSuccess) return;

    if (_dragValue >= maxDrag * 0.9) {
      // ── Success ─────────────────────────────────────────────────────────
      setState(() {
        _dragValue = maxDrag;
        _isSuccess = true;
      });
      HapticFeedback.heavyImpact();
      // Execute the callback immediately (which swaps this bar for the loader).
      widget.onSuccess();
    } else {
      // ── Snap back with elastic physics ──────────────────────────────────
      _snapController.reset();
      final double start = _dragValue;
      _snapAnimation = Tween<double>(begin: start, end: 0.0).animate(
        CurvedAnimation(
          parent: _snapController,
          curve: Curves.elasticOut,
        ),
      )..addListener(() {
          if (mounted) setState(() => _dragValue = _snapAnimation!.value);
        });
      _snapController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag =
            constraints.maxWidth - _thumbSize - _thumbPad * 2;
        final double progress = maxDrag > 0
            ? (_dragValue / maxDrag).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          height: 64,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.isLoading 
                ? widget.primaryColor.withValues(alpha: 0.8) 
                : (_isSuccess ? _successColor : widget.primaryColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.center,
            children: [
              // ── Slide label ────────────────────────────────────────────
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isSuccess ? 0.0 : (1.0 - progress * 0.7),
                child: Text(
                  'SLIDE TO PAY ₹${widget.totalAmount}',
                  style: TextStyle(fontFamily: "PlusJakartaSans", 
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.92),
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // ── Success label / Loading label ──────────────────────────
              if (widget.isLoading)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Processing Order...',
                      style: TextStyle(fontFamily: "PlusJakartaSans", 
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                )
              else if (_isSuccess)
                Text(
                  'Order Confirmed!',
                  style: TextStyle(fontFamily: "PlusJakartaSans", 
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),

              // ── Draggable thumb ────────────────────────────────────────
              Positioned(
                left: _thumbPad,
                top: _thumbPad,
                child: Opacity(
                  opacity: widget.isLoading ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: widget.isLoading,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxDrag),
                      onHorizontalDragEnd: (d) => _onDragEnd(d, maxDrag),
                      child: Transform.translate(
                        offset: Offset(_dragValue, 0),
                        child: Container(
                          width: _thumbSize,
                          height: _thumbSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Icon(
                              _isSuccess
                                  ? Icons.check_rounded
                                  : Icons.keyboard_double_arrow_right_rounded,
                              key: ValueKey(_isSuccess),
                              color: _isSuccess
                                  ? _successColor
                                  : widget.primaryColor,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
