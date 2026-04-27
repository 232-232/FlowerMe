import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/checkout_details.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../services/firebase_order_service.dart';
import '../theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../providers/user_profile_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

// scaffold colour is now always pulled from the active theme
const _kGold = Color(0xFFFFB800);
const _kRedCancel = Color(0xFFE05252);
const _kCardText = Color(0xFF111111);
const _kCardSubText = Color(0xFF555555);
const _kCardHint = Color(0xFF999999);

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY STATUS ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum DeliveryStatus {
  orderPlaced,
  packed,
  outForDelivery,
  arriving,
  delivered,
  cancelled,
  deleted,
}

extension DeliveryStatusX on DeliveryStatus {
  double get progressFraction {
    switch (this) {
      case DeliveryStatus.orderPlaced:
        return 0.10;
      case DeliveryStatus.packed:
        return 0.35;
      case DeliveryStatus.outForDelivery:
        return 0.70;
      case DeliveryStatus.arriving:
        return 0.90;
      case DeliveryStatus.delivered:
        return 1.00;
      case DeliveryStatus.cancelled:
        return 0.00;
      case DeliveryStatus.deleted:
        return 0.00;
    }
  }

  String get statusLabel {
    switch (this) {
      case DeliveryStatus.orderPlaced:
        return 'Order Placed';
      case DeliveryStatus.packed:
        return 'Packed';
      case DeliveryStatus.outForDelivery:
        return 'Out for Delivery';
      case DeliveryStatus.arriving:
        return 'Arriving';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.cancelled:
        return 'Cancelled';
      case DeliveryStatus.deleted:
        return 'Deleted';
    }
  }
}

DeliveryStatus _statusFromString(String s) {
  switch (s) {
    case 'packed':
      return DeliveryStatus.packed;
    case 'outForDelivery':
      return DeliveryStatus.outForDelivery;
    case 'arriving':
      return DeliveryStatus.arriving;
    case 'delivered':
      return DeliveryStatus.delivered;
    case 'cancelled':
      return DeliveryStatus.cancelled;
    case 'deleted':
      return DeliveryStatus.deleted;
    default:
      return DeliveryStatus.orderPlaced;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CANCEL ORDER REASONS
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _cancelReasons = [
  'Changed my mind',
  'Ordered by mistake',
  'Delivery taking too long',
  'Found cheaper elsewhere',
  'Other',
];

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({super.key, required this.initialOrderId});
  final String initialOrderId;

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage>
    with TickerProviderStateMixin {
  static const int _initialMinutes = 12;

  late int _remainingSeconds;
  Timer? _countdownTimer;
  String? _lastKnownStatus;
  bool _isRatingShown = false;

  /// Firebase real-time status subscription — only active when orderId is
  /// numeric (i.e. a Firebase order number like "105").
  StreamSubscription<DatabaseEvent>? _statusSubscription;

  // Pulse for timeline node
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Triple-ring ripple for Out for Delivery
  late final AnimationController _rippleController;

  // Motorcycle vibration
  late final AnimationController _vibrateController;
  late final Animation<double> _vibrateAnimation;

  // Confetti
  late final ConfettiController _confettiController;

  late String _currentSelectedOrderId;

  @override
  void initState() {
    super.initState();

    _remainingSeconds = _initialMinutes * 60;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.82, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _vibrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..repeat(reverse: true);
    _vibrateAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _vibrateController, curve: Curves.easeInOut),
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );

    _currentSelectedOrderId = widget.initialOrderId;
    _subscribeToOrder(_currentSelectedOrderId);
    _initFCM();
  }

  Future<void> _initFCM() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    try {
      final orderProvider = context.read<OrderProvider>();
      final order = orderProvider.getOrderById(widget.initialOrderId);
      final profileProvider = context.read<UserProfileProvider>();
      
      String rawPhone = order?.deliveryDetails.phone ?? profileProvider.phone;
      String phone = rawPhone.replaceAll(RegExp(r'\D'), '');
      
      if (phone.length >= 10) {
        phone = phone.substring(phone.length - 10);
      }
      
      if (phone.isEmpty) {
        debugPrint('--- FCM INIT: No phone number found to associate token ---');
        return;
      }

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('--- FCM Auth Status: ${settings.authorizationStatus} ---');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        String? token = await messaging.getToken();
        debugPrint('--- FCM Token Generated: $token ---');
        
        if (token != null) {
          final dbRef = FirebaseDatabase.instance.ref('root/fcm_tokens/$phone');
          await dbRef.update({
            'phone': phone,
            'token': token,
            'platform': defaultTargetPlatform.toString(),
            'orderCompletedAt': ServerValue.timestamp,
            'updatedAt': ServerValue.timestamp,
          });
          debugPrint('--- FCM Token Saved to Firebase /root/fcm_tokens/$phone ! ---');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('--- FCM INIT ERROR: $e ---');
      debugPrint('--- FCM INIT STACKTRACE: $stackTrace ---');
    }
  }

  void _subscribeToOrder(String orderId) {
    _statusSubscription?.cancel();

    // ── Firebase real-time status listener ────────────────────────────────────
    // Only Firebase-based orders have a pure-numeric orderId (e.g. "105").
    // Legacy demo orders use strings like "DC92841" — skip those.
    final orderNum = int.tryParse(orderId);
    if (orderNum != null) {
      _statusSubscription = FirebaseOrderService.listenToStatus(orderNum, (
        firebaseStatus,
      ) {
        if (!mounted) return;
        final appStatus = FirebaseOrderService.firebaseToAppStatus(
          firebaseStatus,
        );
        // Only write to provider when something actually changed.
        context.read<OrderProvider>().updateOrderStatus(orderId, appStatus);
      });
    }
  }

  void _syncStatus(DeliveryStatus status) {
    final s = status.name;
    if (_lastKnownStatus == s) return;

    // Provide haptic feedback on status change (skip initial page load)
    if (_lastKnownStatus != null) {
      if (status == DeliveryStatus.delivered ||
          status == DeliveryStatus.cancelled ||
          status == DeliveryStatus.deleted) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }

    _lastKnownStatus = s;

    if (status == DeliveryStatus.delivered) {
      _countdownTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _confettiController.play();
          if (!_isRatingShown) {
            _isRatingShown = true;
            _showRatingDialog();
          }
        }
      });
    } else if (status == DeliveryStatus.cancelled ||
        status == DeliveryStatus.deleted) {
      _countdownTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final activeOrders = context.read<OrderProvider>().activeOrders;
          if (activeOrders.isNotEmpty &&
              activeOrders.first.orderId != _currentSelectedOrderId) {
            setState(() {
              _currentSelectedOrderId = activeOrders.first.orderId;
              _isRatingShown = false;
              _lastKnownStatus = null;
              _remainingSeconds = _initialMinutes * 60;
              _subscribeToOrder(_currentSelectedOrderId);
            });
          } else {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      });
    } else if (_countdownTimer == null || !_countdownTimer!.isActive) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        setState(() => _remainingSeconds = 0);
        t.cancel();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _statusSubscription?.cancel();
    _pulseController.dispose();
    _rippleController.dispose();
    _vibrateController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String get _timeLabel {
    if (_remainingSeconds <= 0) return 'Arriving soon';
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return m > 0 ? '$m min left' : '${s}s left';
  }

  int get _minutesLeft => (_remainingSeconds / 60).ceil();

  void _showRatingDialog() {
    final order = context.read<OrderProvider>().getOrderById(
      _currentSelectedOrderId,
    );
    if (order == null) return;

    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => RatingReviewDialog(order: order),
      );

      if (!mounted) return;

      // Once rating is done/skipped:
      // If there are other active orders, seamlessly switch to tracking them.
      // Otherwise, return to the home page.
      final activeOrders = context.read<OrderProvider>().activeOrders;
      if (activeOrders.isNotEmpty) {
        setState(() {
          _currentSelectedOrderId = activeOrders.first.orderId;
          _isRatingShown = false;
          _lastKnownStatus = null;
          _remainingSeconds = _initialMinutes * 60;
          _subscribeToOrder(_currentSelectedOrderId);
        });
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  void _showCancelSheet(BuildContext context, String orderId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CancelOrderSheet(
        onConfirm: (reason) async {
          final orderNum = int.tryParse(orderId);
          if (orderNum != null) {
            await FirebaseOrderService.updateStatus(
              orderNum,
              FirebaseOrderService.statusCancelled,
            );
          }
          if (context.mounted) {
            context.read<OrderProvider>().cancelOrder(orderId, reason);
          }
        },
      ),
    );
  }

  Color _scaffoldColor(AppThemeData appTheme) => appTheme.gradientTop;

  List<Color> _bgGradient(AppThemeData appTheme) =>
      appTheme.backgroundGradientColors;

  // Cards are always white regardless of theme
  Color _cardBg(AppThemeData appTheme) => Colors.white;

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeScope.themeOf(context);
    final accent = appTheme.primaryAccent;
    final scaffold = _scaffoldColor(appTheme);
    final bg = _bgGradient(appTheme);
    final cardBg = _cardBg(appTheme);

    return Scaffold(
      backgroundColor: scaffold,
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          final order = orderProvider.getOrderById(_currentSelectedOrderId);

          if (order == null) {
            return _buildNotFound(appTheme, bg, _currentSelectedOrderId);
          }

          final status = _statusFromString(order.status);
          _syncStatus(status);

          final isCancelled = status == DeliveryStatus.cancelled;
          final isDelivered = status == DeliveryStatus.delivered;
          final canCancel = !isDelivered && !isCancelled;
          final isOutForDelivery = status == DeliveryStatus.outForDelivery;

          final totalAmount = order.items.fold<double>(
            0,
            (sum, i) => sum + i.total,
          );

          return Stack(
            children: [
              // ── Background gradient ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: bg,
                  ),
                ),
              ),

              // ── Subtle radial glow top-left ──────────────────────────────
              Positioned(
                top: -60,
                left: -60,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Main scrollable content ──────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    _PremiumAppBar(
                      orderId: _currentSelectedOrderId,
                      isCancelled: isCancelled,
                      accent: accent,
                    ),
                    if (orderProvider.activeOrders.length > 1)
                      _ActiveOrdersTabs(
                        orders: orderProvider.activeOrders,
                        selectedOrderId: _currentSelectedOrderId,
                        onTabSelected: (id) {
                          if (id == _currentSelectedOrderId) return;
                          setState(() {
                            _currentSelectedOrderId = id;
                            _isRatingShown = false;
                            _lastKnownStatus = null;
                            _remainingSeconds = _initialMinutes * 60;
                            _subscribeToOrder(id);
                          });
                        },
                        accent: accent,
                      ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                        children: [
                          // 1 – Hero progress card
                          _staggerCard(
                            delay: 0,
                            child: _HeroTrackCard(
                              orderId: _currentSelectedOrderId,
                              isMostRecent:
                                  orderProvider.activeOrders.isNotEmpty &&
                                  orderProvider.activeOrders.first.orderId ==
                                      _currentSelectedOrderId,
                              status: status,
                              accent: accent,
                              cardBg: cardBg,
                              vibrateAnimation: _vibrateAnimation,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 2 – Live status / banner
                          _staggerCard(
                            delay: 1,
                            child: isCancelled
                                ? _CancelledBanner(
                                    reason: order.cancelReason,
                                    cardBg: cardBg,
                                  )
                                : isDelivered
                                ? _DeliveredBanner(
                                    accent: accent,
                                    cardBg: cardBg,
                                  )
                                : _LiveStatusBanner(
                                    timeLabel: _timeLabel,
                                    status: status,
                                    accent: accent,
                                    cardBg: cardBg,
                                  ),
                          ),
                          const SizedBox(height: 14),

                          // 3 – Timeline (hidden if cancelled)
                          if (!isCancelled) ...[
                            _staggerCard(
                              delay: 2,
                              child: _PremiumTimeline(
                                status: status,
                                accent: accent,
                                cardBg: cardBg,
                                pulseAnimation: _pulseAnimation,
                                rippleController: _rippleController,
                                minutesLeft: _minutesLeft,
                                isOutForDelivery: isOutForDelivery,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 4 – Delivery Partner (hidden if cancelled)
                          if (!isCancelled) ...[
                            _staggerCard(
                              delay: 3,
                              child: _DeliveryPartnerCard(
                                orderId: _currentSelectedOrderId,
                                accent: accent,
                                cardBg: cardBg,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 5 – Order Details
                          _staggerCard(
                            delay: 4,
                            child: _OrderDetailsCard(
                              items: order.items,
                              totalAmount: totalAmount,
                              paymentMethod: order.paymentMethod,
                              accent: accent,
                              cardBg: cardBg,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 6 – Delivery Details
                          _staggerCard(
                            delay: 5,
                            child: _DeliveryDetailsCard(
                              details: order.deliveryDetails,
                              accent: accent,
                              cardBg: cardBg,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 7 – Delivery Instructions (if present)
                          if (order.deliveryInstruction.isNotEmpty) ...[
                            _staggerCard(
                              delay: 6,
                              child: _DeliveryInstructionCard(
                                instruction: order.deliveryInstruction,
                                accent: accent,
                                cardBg: cardBg,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 8 – Support (with glint button)
                          _staggerCard(
                            delay: 7,
                            child: _SupportSection(
                              accent: accent,
                              cardBg: cardBg,
                            ),
                          ),

                          // 9 – Cancel
                          if (canCancel) ...[
                            const SizedBox(height: 20),
                            _staggerCard(
                              delay: 8,
                              child: Center(
                                child: _CancelOrderButton(
                                  onPressed: () => _showCancelSheet(
                                    context,
                                    _currentSelectedOrderId,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Confetti overlay ─────────────────────────────────────────
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 30,
                  gravity: 0.18,
                  emissionFrequency: 0.06,
                  colors: [
                    accent,
                    _kGold,
                    Colors.white,
                    Colors.white70,
                    appTheme.secondaryAccent,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _staggerCard({required int delay, required Widget child}) {
    return child
        .animate()
        .slideY(
          begin: 0.2,
          end: 0,
          duration: const Duration(milliseconds: 600),
          delay: Duration(milliseconds: 100 * delay),
          curve: Curves.easeOutExpo,
        )
        .fadeIn(
          duration: const Duration(milliseconds: 500),
          delay: Duration(milliseconds: 100 * delay),
          curve: Curves.easeOutExpo,
        );
  }

  Widget _buildNotFound(AppThemeData appTheme, List<Color> bg, String orderId) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: bg,
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _PremiumAppBar(
                orderId: orderId,
                isCancelled: false,
                accent: appTheme.primaryAccent,
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Order not found',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED CARD DECORATION
// ─────────────────────────────────────────────────────────────────────────────

BoxDecoration _premiumCard(Color bg) => BoxDecoration(
  color: bg,
  borderRadius: BorderRadius.circular(24),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.13),
      blurRadius: 40,
      offset: const Offset(0, 12),
    ),
  ],
  border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
);

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM APP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumAppBar extends StatelessWidget {
  const _PremiumAppBar({
    required this.orderId,
    required this.isCancelled,
    required this.accent,
  });

  final String orderId;
  final bool isCancelled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Tracking',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'ESTIMATED: 12:45 PM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Order ID / Cancelled badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isCancelled
                  ? _kRedCancel.withValues(alpha: 0.20)
                  : Colors.white.withValues(alpha: 0.10),
              border: Border.all(
                color: isCancelled
                    ? _kRedCancel.withValues(alpha: 0.60)
                    : Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Text(
              isCancelled ? 'Cancelled' : '#$orderId',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isCancelled ? const Color(0xFFFFB3B3) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO TRACK CARD  (bike + progress bar)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroTrackCard extends StatelessWidget {
  const _HeroTrackCard({
    required this.orderId,
    this.isMostRecent = false,
    required this.status,
    required this.accent,
    required this.cardBg,
    required this.vibrateAnimation,
  });

  final String orderId;
  final bool isMostRecent;
  final DeliveryStatus status;
  final Color accent;
  final Color cardBg;
  final Animation<double> vibrateAnimation;

  @override
  Widget build(BuildContext context) {
    final isCancelled = status == DeliveryStatus.cancelled;
    final bikeColor = isCancelled ? _kRedCancel : accent;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: _premiumCard(cardBg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE TRACKING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 1.8,
                    ),
                  ),
                  if (isMostRecent) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _kGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'Recently Ordered',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB8860B),
                        ),
                      ),
                    ),
                  ],
                ],
              ), // hero card header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: bikeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: bikeColor.withValues(alpha: 0.40)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: bikeColor,
                            shape: BoxShape.circle,
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 0.6, end: 1.4, duration: 700.ms),
                    const SizedBox(width: 6),
                    Text(
                      isCancelled ? 'Order Cancelled' : 'Partner on the way',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: bikeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Animated track
          _AnimatedTrack(
            status: status,
            accent: accent,
            bikeColor: bikeColor,
            vibrateAnimation: vibrateAnimation,
          ),

          const SizedBox(height: 22),

          // ETA display
          if (!isCancelled) ...[
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: accent),
                const SizedBox(width: 6),
                Builder(
                  builder: (context) {
                    final order = context.watch<OrderProvider>().getOrderById(
                      orderId,
                    );
                    if (status == DeliveryStatus.delivered &&
                        order?.deliveredAt != null) {
                      final duration = order!.deliveredAt!.difference(
                        order.orderDateTime,
                      );
                      final minutes = duration.inMinutes;
                      return Text(
                        'Delivered: ${minutes > 0 ? '$minutes mins' : 'Just now'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _kCardSubText,
                        ),
                      );
                    }
                    return Text(
                      'Estimated: 12 mins',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kCardSubText,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED TRACK (progress bar + vibrating motorcycle)
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedTrack extends StatelessWidget {
  const _AnimatedTrack({
    required this.status,
    required this.accent,
    required this.bikeColor,
    required this.vibrateAnimation,
  });

  final DeliveryStatus status;
  final Color accent;
  final Color bikeColor;
  final Animation<double> vibrateAnimation;

  static const double _trackH = 72.0;
  static const double _nodeR = 16.0;
  static const double _bikeSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final isCancelled = status == DeliveryStatus.cancelled;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: status.progressFraction),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutExpo,
      builder: (context, progress, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const startX = _nodeR + 8.0;
            final endX = w - _nodeR - 8.0;
            final trackLen = endX - startX;
            final bikeCenter = startX + trackLen * progress;
            const centerY = _trackH / 2;

            return SizedBox(
              height: _trackH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Full dashed track
                  CustomPaint(
                    size: Size(w, _trackH),
                    painter: _DashedTrackPainter(
                      start: Offset(startX, centerY),
                      end: Offset(endX, centerY),
                      color: const Color(0xFFDDDDDD),
                    ),
                  ),

                  // Filled accent track
                  if (!isCancelled && progress > 0)
                    CustomPaint(
                      size: Size(w, _trackH),
                      painter: _GlowTrackPainter(
                        start: Offset(startX, centerY),
                        end: Offset(bikeCenter, centerY),
                        color: bikeColor,
                      ),
                    ),

                  // Store node (left)
                  Positioned(
                    left: 0,
                    top: centerY - _nodeR,
                    child: _TrackEndNode(
                      icon: Icons.storefront_rounded,
                      color: accent,
                      radius: _nodeR,
                      label: 'STORE',
                    ),
                  ),

                  // Home node (right)
                  Positioned(
                    right: 0,
                    top: centerY - _nodeR,
                    child: _TrackEndNode(
                      icon: Icons.home_rounded,
                      color: const Color(0xFFFF9800),
                      radius: _nodeR,
                      label: 'HOME',
                    ),
                  ),

                  // Animated motorcycle with vibration
                  Positioned(
                    left: bikeCenter - _bikeSize / 2,
                    top: centerY - _bikeSize / 2,
                    child: AnimatedBuilder(
                      animation: vibrateAnimation,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, vibrateAnimation.value),
                        child: child,
                      ),
                      child: Container(
                        width: _bikeSize,
                        height: _bikeSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: bikeColor, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: bikeColor.withValues(alpha: 0.50),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          isCancelled
                              ? Icons.cancel_outlined
                              : Icons.motorcycle_rounded,
                          size: 22,
                          color: bikeColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TrackEndNode extends StatelessWidget {
  const _TrackEndNode({
    required this.icon,
    required this.color,
    required this.radius,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final double radius;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.20),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.60), width: 2),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: _kCardHint,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _DashedTrackPainter extends CustomPainter {
  const _DashedTrackPainter({
    required this.start,
    required this.end,
    required this.color,
  });

  final Offset start;
  final Offset end;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const dashW = 6.0;
    const gap = 5.0;
    final dist = (end - start).distance;
    if (dist <= 0) return;
    final count = (dist / (dashW + gap)).floor();
    final unit = (end - start) / dist;
    for (int i = 0; i < count; i++) {
      canvas.drawLine(
        start + unit * (i * (dashW + gap)),
        start + unit * (i * (dashW + gap) + dashW),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedTrackPainter old) =>
      old.end != end || old.color != color;
}

class _GlowTrackPainter extends CustomPainter {
  const _GlowTrackPainter({
    required this.start,
    required this.end,
    required this.color,
  });

  final Offset start;
  final Offset end;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Glow layer
    final glow = Paint()
      ..color = color.withValues(alpha: 0.30)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(start, end, glow);

    // Core line
    final core = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, core);
  }

  @override
  bool shouldRepaint(covariant _GlowTrackPainter old) =>
      old.end != end || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE STATUS BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _LiveStatusBanner extends StatelessWidget {
  const _LiveStatusBanner({
    required this.timeLabel,
    required this.status,
    required this.accent,
    required this.cardBg,
  });

  final String timeLabel;
  final DeliveryStatus status;
  final Color accent;
  final Color cardBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _premiumCard(cardBg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.40),
                width: 1.5,
              ),
            ),
            child: Icon(Icons.local_shipping_rounded, color: accent, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your order is on the way!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kCardText,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${status.statusLabel}  ·  ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kCardSubText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        timeLabel,
                        key: ValueKey<String>(timeLabel),
                        style: TextStyle(
                          fontSize: 12,
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM TIMELINE with triple-ring ripple for Out for Delivery
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumTimeline extends StatelessWidget {
  const _PremiumTimeline({
    required this.status,
    required this.accent,
    required this.cardBg,
    required this.pulseAnimation,
    required this.rippleController,
    required this.minutesLeft,
    required this.isOutForDelivery,
  });

  final DeliveryStatus status;
  final Color accent;
  final Color cardBg;
  final Animation<double> pulseAnimation;
  final AnimationController rippleController;
  final int minutesLeft;
  final bool isOutForDelivery;

  static const _steps = [
    (DeliveryStatus.orderPlaced, 'Order Placed', Icons.receipt_long_rounded),
    (DeliveryStatus.packed, 'Packed', Icons.inventory_2_rounded),
    (
      DeliveryStatus.outForDelivery,
      'Out for Delivery',
      Icons.motorcycle_rounded,
    ),
    (DeliveryStatus.arriving, 'Arriving', Icons.near_me_rounded),
    (DeliveryStatus.delivered, 'Delivered', Icons.home_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final ordered = DeliveryStatus.values
        .where((s) => s != DeliveryStatus.cancelled)
        .toList();
    final currentIndex = status == DeliveryStatus.cancelled
        ? -1
        : ordered.indexOf(status);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: _premiumCard(cardBg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER PROGRESS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 1.8,
            ),
          ), // timeline header
          const SizedBox(height: 18),
          for (int i = 0; i < _steps.length; i++) ...[
            _TimelineStep(
              label: _steps[i].$2,
              icon: _steps[i].$3,
              isCompleted: i < currentIndex,
              isCurrent: i == currentIndex,
              isPending: i > currentIndex,
              isLast: i == _steps.length - 1,
              accent: accent,
              pulseAnimation: pulseAnimation,
              rippleController: rippleController,
              showRipple:
                  i == currentIndex &&
                  _steps[i].$1 == DeliveryStatus.outForDelivery,
              badge:
                  (i == currentIndex &&
                      _steps[i].$1 == DeliveryStatus.outForDelivery &&
                      minutesLeft > 0)
                  ? minutesLeft.toString()
                  : null,
            ),
            if (i < _steps.length - 1) const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.icon,
    required this.isCompleted,
    required this.isCurrent,
    required this.isPending,
    required this.isLast,
    required this.accent,
    required this.pulseAnimation,
    required this.rippleController,
    required this.showRipple,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;
  final bool isPending;
  final bool isLast;
  final Color accent;
  final Animation<double> pulseAnimation;
  final AnimationController rippleController;
  final bool showRipple;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final nodeColor = isPending ? Colors.white.withValues(alpha: 0.15) : accent;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                // Node
                if (showRipple)
                  _RippleNode(accent: accent, icon: icon, badge: badge)
                else if (isCurrent)
                  ScaleTransition(
                    scale: pulseAnimation,
                    child: _NodeCircle(
                      isCompleted: false,
                      isCurrent: true,
                      color: nodeColor,
                      icon: icon,
                      badge: badge,
                    ),
                  )
                else
                  _NodeCircle(
                    isCompleted: isCompleted,
                    isCurrent: false,
                    color: nodeColor,
                    icon: icon,
                    badge: null,
                  ),

                // Connector line
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: isPending
                              ? null
                              : LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    accent,
                                    accent.withValues(alpha: 0.20),
                                  ],
                                ),
                          color: isPending ? const Color(0xFFE0E0E0) : null,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 280),
                    style: TextStyle(
                      fontSize: isCurrent ? 15 : 13,
                      fontWeight: isCurrent
                          ? FontWeight.w800
                          : (isCompleted ? FontWeight.w600 : FontWeight.w400),
                      color: isPending
                          ? const Color(0xFFBBBBBB)
                          : (isCurrent ? _kCardText : _kCardSubText),
                    ),
                    child: Text(label),
                  ),
                  if (isCurrent && !isPending)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        isCurrent ? 'In progress' : 'Done',
                        style: TextStyle(
                          fontSize: 11,
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Triple-ring ripple node for Out for Delivery
class _RippleNode extends StatelessWidget {
  const _RippleNode({required this.accent, required this.icon, this.badge});

  final Color accent;
  final IconData icon;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Three ripple rings
          for (int r = 0; r < 3; r++) _RippleRing(accent: accent, ringIndex: r),
          // Core node
          _NodeCircle(
            isCompleted: false,
            isCurrent: true,
            color: accent,
            icon: icon,
            badge: badge,
          ),
        ],
      ),
    );
  }
}

class _RippleRing extends StatefulWidget {
  const _RippleRing({required this.accent, required this.ringIndex});
  final Color accent;
  final int ringIndex;

  @override
  State<_RippleRing> createState() => _RippleRingState();
}

class _RippleRingState extends State<_RippleRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scale = Tween<double>(
      begin: 0.5,
      end: 2.4,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.ringIndex * 600), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.accent.withValues(alpha: _opacity.value),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _NodeCircle extends StatelessWidget {
  const _NodeCircle({
    required this.isCompleted,
    required this.isCurrent,
    required this.color,
    required this.icon,
    this.badge,
  });

  final bool isCompleted;
  final bool isCurrent;
  final Color color;
  final IconData icon;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: (isCompleted || isCurrent) ? color : const Color(0xFFF5F5F5),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: isCurrent ? 2.5 : 2.0),
        boxShadow: (isCompleted || isCurrent)
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.40),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
            : badge != null
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  badge!,
                  key: ValueKey<String>(badge!),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              )
            : isCurrent
            ? Icon(icon, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY PARTNER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryPartnerCard extends StatelessWidget {
  const _DeliveryPartnerCard({
    required this.orderId,
    required this.accent,
    required this.cardBg,
  });

  final String orderId;
  final Color accent;
  final Color cardBg;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('root/order/$orderId').onValue,
      builder: (context, snapshot) {
        final data = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;

        final partnerName =
            data?['delivery_partner_name']?.toString() ??
            'Assigning Delivery Boy...';
        final partnerPhone = data?['delivery_partner_phone']?.toString();

        String initials = 'DP';
        if (partnerName != 'Assigning Delivery Boy...' &&
            partnerName.isNotEmpty) {
          final parts = partnerName.trim().split(' ');
          if (parts.length > 1) {
            initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
          } else {
            initials = partnerName
                .substring(0, math.min(2, partnerName.length))
                .toUpperCase();
          }
        }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: _premiumCard(cardBg),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar with initials
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.60)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YOUR DELIVERY PARTNER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _kCardHint,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          partnerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _kCardText,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _kGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _kGold.withValues(alpha: 0.40),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 11,
                                    color: _kGold,
                                  ),
                                  const SizedBox(width: 3),
                                  const Text(
                                    '4.8',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _kGold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '245 deliveries',
                              style: TextStyle(fontSize: 11, color: _kCardHint),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _HapticPillButton(
                      icon: Icons.call_rounded,
                      label: 'Call',
                      color: partnerPhone != null ? accent : _kCardHint,
                      onTap: partnerPhone != null
                          ? () => launchUrl(Uri.parse('tel:$partnerPhone'))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HapticPillButton(
                      icon: Icons.chat_bubble_rounded,
                      label: 'Chat',
                      color: _kCardSubText,
                      outlined: true,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HapticPillButton extends StatelessWidget {
  const _HapticPillButton({
    required this.icon,
    required this.label,
    required this.color,
    this.outlined = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap == null) return;
        HapticFeedback.mediumImpact();
        onTap!();
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: outlined ? 0.35 : 0.40),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDER DETAILS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    required this.accent,
    required this.cardBg,
  });

  final List<OrderItemModel> items;
  final double totalAmount;
  final String paymentMethod;
  final Color accent;
  final Color cardBg;

  @override
  Widget build(BuildContext context) {
    final isCod = paymentMethod == 'cod';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _premiumCard(cardBg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER DETAILS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kCardText,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${item.total.toInt()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _kCardText,
                        ),
                      ),
                      Text(
                        'Qty: ${item.quantity}',
                        style: const TextStyle(fontSize: 11, color: _kCardHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24, color: Color(0xFFEEEEEE)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kCardSubText,
                ),
              ),
              Text(
                '₹${totalAmount.toInt()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _kCardText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isCod
                  ? const Color(0xFFFF9800).withValues(alpha: 0.12)
                  : accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCod
                    ? const Color(0xFFFF9800).withValues(alpha: 0.35)
                    : accent.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCod
                      ? Icons.payments_outlined
                      : Icons.account_balance_wallet_rounded,
                  size: 14,
                  color: isCod ? const Color(0xFFFF9800) : accent,
                ),
                const SizedBox(width: 7),
                Text(
                  isCod
                      ? 'Cash on Delivery · Pay ₹${totalAmount.toInt()}'
                      : 'UPI · Paid',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCod ? const Color(0xFFFF9800) : accent,
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
// DELIVERY DETAILS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryDetailsCard extends StatelessWidget {
  const _DeliveryDetailsCard({
    required this.details,
    required this.accent,
    required this.cardBg,
  });

  final CheckoutDetails details;
  final Color accent;
  final Color cardBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _premiumCard(cardBg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DELIVERY DETAILS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 1.8,
            ),
          ), // delivery details header
          const SizedBox(height: 18),
          _DetailRow(
            icon: Icons.person_rounded,
            label: 'Name',
            value: details.name,
            accent: accent,
          ),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.call_rounded,
            label: 'Phone',
            value: details.phone,
            accent: accent,
          ),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.location_on_rounded,
            label: 'Address',
            value: details.address,
            accent: accent,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, size: 17, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: _kCardHint,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kCardText,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY INSTRUCTION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryInstructionCard extends StatelessWidget {
  const _DeliveryInstructionCard({
    required this.instruction,
    required this.accent,
    required this.cardBg,
  });

  final String instruction;
  final Color accent;
  final Color cardBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _premiumCard(cardBg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notes_rounded, size: 20, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Instructions',
                  style: TextStyle(
                    fontSize: 11,
                    color: _kCardHint,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  instruction,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _kCardText,
                    height: 1.4,
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
// SUPPORT SECTION  (gradient button + glint animation every 3 s)
// ─────────────────────────────────────────────────────────────────────────────

class _SupportSection extends StatefulWidget {
  const _SupportSection({required this.accent, required this.cardBg});
  final Color accent;
  final Color cardBg;

  @override
  State<_SupportSection> createState() => _SupportSectionState();
}

class _SupportSectionState extends State<_SupportSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glintCtrl;
  late final Animation<double> _glintAnim;

  @override
  void initState() {
    super.initState();
    _glintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _glintAnim = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _glintCtrl, curve: Curves.easeInOut));

    // Fire glint every 3 seconds
    Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      _glintCtrl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _glintCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: _premiumCard(widget.cardBg),
      child: Column(
        children: [
          const Text(
            'Need help with this order?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kCardSubText,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => HapticFeedback.mediumImpact(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AnimatedBuilder(
                animation: _glintAnim,
                builder: (_, child) {
                  return ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (rect) {
                      final glintX = _glintAnim.value * rect.width;
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: const [0, 0.45, 0.55, 1],
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.35),
                          Colors.white.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        transform: _GlintTransform(glintX),
                      ).createShader(rect);
                    },
                    child: child,
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.75)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.40),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.headset_mic_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'CONTACT SUPPORT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlintTransform extends GradientTransform {
  const _GlintTransform(this.translateX);
  final double translateX;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(translateX, 0, 0);
}

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERED & CANCELLED BANNERS
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveredBanner extends StatelessWidget {
  const _DeliveredBanner({required this.accent, required this.cardBg});
  final Color accent;
  final Color cardBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _premiumCard(cardBg),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: accent, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Delivered 🎉',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kCardText,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your order has been delivered successfully!',
                  style: TextStyle(fontSize: 12, color: _kCardSubText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner({required this.reason, required this.cardBg});
  final String? reason;
  final Color cardBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: _kRedCancel.withValues(alpha: 0.40),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _kRedCancel.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_rounded,
              color: Color(0xFFFF8080),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Cancelled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kCardText,
                  ),
                ),
                if (reason != null && reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reason: $reason',
                    style: const TextStyle(fontSize: 12, color: _kCardSubText),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CANCEL ORDER BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _CancelOrderButton extends StatelessWidget {
  const _CancelOrderButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _kRedCancel.withValues(alpha: 0.50),
            width: 1.5,
          ),
          color: _kRedCancel.withValues(alpha: 0.08),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFFF8080)),
            SizedBox(width: 8),
            Text(
              'Cancel Order',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF8080),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CANCEL ORDER BOTTOM SHEET (unchanged visuals — keep white for legibility)
// ─────────────────────────────────────────────────────────────────────────────

class _CancelOrderSheet extends StatefulWidget {
  const _CancelOrderSheet({required this.onConfirm});
  final void Function(String reason) onConfirm;

  @override
  State<_CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends State<_CancelOrderSheet> {
  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: Color(0xFFE05252),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cancel Order',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Please select a reason below',
                      style: TextStyle(fontSize: 13, color: Color(0xFF888B88)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(_cancelReasons.length, (index) {
            final reason = _cancelReasons[index];
            final isSelected = _selectedReason == reason;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedReason = reason),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFECEC)
                        : const Color(0xFFF6F8F4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFE05252)
                          : const Color(0xFFE2E5DF),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? const Color(0xFFE05252)
                                : const Color(0xFF2A2D2A),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFFE05252)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFE05252)
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedReason == null
                  ? null
                  : () {
                      widget.onConfirm(_selectedReason!);
                      Navigator.of(context).pop();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE05252),
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _selectedReason == null
                    ? 'Select a reason'
                    : 'Confirm Cancellation',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UNUSED IMPORT GUARD – keeps dart:math available for future painters
// ─────────────────────────────────────────────────────────────────────────────
// ignore: unused_element
double _unusedMathRef() => math.pi;

// ─────────────────────────────────────────────────────────────────────────────
// RATING & REVIEW DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class RatingReviewDialog extends StatefulWidget {
  const RatingReviewDialog({super.key, required this.order});
  final OrderModel order;

  @override
  State<RatingReviewDialog> createState() => _RatingReviewDialogState();
}

class _RatingReviewDialogState extends State<RatingReviewDialog> {
  double _rating = 5.0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final orderNum = int.tryParse(widget.order.orderId);
      if (orderNum == null) throw 'Invalid order ID';

      // Calculate total time
      String totalTimeStr = 'Just now';
      if (widget.order.deliveredAt != null) {
        final duration = widget.order.deliveredAt!.difference(
          widget.order.orderDateTime,
        );
        final mins = duration.inMinutes;
        totalTimeStr = mins > 0 ? '$mins mins' : 'under 1 min';
      }

      final itemNames = widget.order.items.map((i) => i.name).toList();

      await FirebaseOrderService.submitRating(
        orderNumber: orderNum,
        name: widget.order.deliveryDetails.name,
        phoneNumber:
            int.tryParse(
              widget.order.deliveryDetails.phone.replaceAll(RegExp(r'\D'), ''),
            ) ??
            0,
        rating: _rating,
        review: _reviewController.text.trim(),
        items: itemNames,
        totalTime: totalTimeStr,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeScope.themeOf(context).primaryAccent;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Image/Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_rounded, size: 48, color: accent),
            ).animate().scale(
              delay: 200.ms,
              duration: 400.ms,
              curve: Curves.easeOutBack,
            ),

            const SizedBox(height: 20),
            const Text(
              'How was your experience?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your feedback helps us improve our service.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),

            const SizedBox(height: 24),

            // Star row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1.0;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starValue),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child:
                        Icon(
                              starValue <= _rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 42,
                              color: starValue <= _rating
                                  ? accent
                                  : Colors.grey.shade300,
                            )
                            .animate(target: starValue <= _rating ? 1 : 0)
                            .scale(duration: 200.ms, curve: Curves.easeOut),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Review Input
            TextField(
              controller: _reviewController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Write a review (optional)',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
    );
  }
}

// ── Multi-Order Tabs ──────────────────────────────────────────────────────────

class _ActiveOrdersTabs extends StatelessWidget {
  const _ActiveOrdersTabs({
    required this.orders,
    required this.selectedOrderId,
    required this.onTabSelected,
    required this.accent,
  });

  final List<OrderModel> orders;
  final String selectedOrderId;
  final ValueChanged<String> onTabSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final order = orders[index];
          final isSelected = order.orderId == selectedOrderId;
          return GestureDetector(
            onTap: () => onTabSelected(order.orderId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? accent
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child: Text(
                  '#${order.orderId}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
