import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

enum ChartRange { day, month, year }

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with TickerProviderStateMixin {
  // Appearance constants
  static const Color em = Color(0xFF00FFA3);
  static const Color em2 = Color(0xFF00C97A);
  static const Color emDim = Color(0x1E00FFA3); // ~0.12 alpha
  static const Color bg = Color(0xFF05080F);
  static const Color bg2 = Color(0xFF080D18);
  static const Color textCol = Color(0xFFEEF2F7);
  static const Color muted = Color(0x59FFFFFF); // ~0.35 alpha
  static const Color danger = Color(0xFFFF5E72);
  static const Color warn = Color(0xFFFFB940);
  static const Color blue = Color(0xFF4A9EFF);
  static const Color purple = Color(0xFFA78BFA);
  static const Color glass = Color(0x09FFFFFF); // ~0.035 alpha
  static const Color glassB = Color(0x12FFFFFF); // ~0.07 alpha

  late final AnimationController _revealController;
  late final AnimationController _ringController;
  late final AnimationController _chartController;
  late final AnimationController _barsController;

  late final Ticker _particleTicker;
  final List<_Particle> _particles = [];
  final ValueNotifier<int> _particleNotifier = ValueNotifier(0);

  double _sliderValue = 0.0;
  double _currentDue = 0.0;
  double _creditAmount = 5000.0;
  double _walletBalance = 0.0;
  double _totalDue = 0.0;

  StreamSubscription<DatabaseEvent>? _walletSub;
  StreamSubscription<DatabaseEvent>? _ordersSub;
  List<Map<String, dynamic>> _recentOrders = [];

  ChartRange _chartRange = ChartRange.month;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  double _filteredMonthSpend = 0.0;
  double _previousMonthSpend = 0.0;
  List<Map<String, dynamic>> _breakdownItems = [];
  List<Map<String, dynamic>> _monthlySpendData = [];
  List<Map<String, dynamic>> _walletTransactions = [];
  String _breakdownSort = 'qty'; // 'qty' or 'price'
  int? _tappedChartIndex;

  late final Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();

    // Init particles
    final random = math.Random();
    for (int i = 0; i < 55; i++) {
      _particles.add(
        _Particle(
          x: random.nextDouble() * 2000,
          y: random.nextDouble() * 2000,
          r: random.nextDouble() * 1.5 + 0.3,
          vx: (random.nextDouble() - 0.5) * 0.25,
          vy: (random.nextDouble() - 0.5) * 0.25,
          a: random.nextDouble() * 0.5 + 0.1,
        ),
      );
    }

    _particleTicker = createTicker((_) {
      final size = MediaQuery.of(context).size;
      final w = size.width == 0.0 ? 500.0 : size.width;
      final h = size.height == 0.0 ? 1000.0 : size.height;
      for (var p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        if (p.x < 0) p.x = w;
        if (p.x > w) p.x = 0;
        if (p.y < 0) p.y = h;
        if (p.y > h) p.y = 0;
      }
      _particleNotifier.value++;
    });
    _particleTicker.start();

    // Init animations
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _ringAnimation =
        Tween<double>(begin: 0, end: _currentDue).animate(
          CurvedAnimation(parent: _ringController, curve: Curves.easeOutQuart),
        )..addListener(() {
          setState(() {
            _currentDue = _ringAnimation.value;
          });
        });

    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _barsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Staggered reveals
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealController.forward();

      final rawPhone = context.read<UserProfileProvider>().phone;
      final normalizedPhone = rawPhone.replaceAll(RegExp(r'\D'), '');

      if (normalizedPhone.length >= 10) {
        final last10Digits = normalizedPhone.substring(
          normalizedPhone.length - 10,
        );
        _walletSub = FirebaseDatabase.instance
            .ref('root/walletusers/$last10Digits')
            .onValue
            .listen((event) {
              final data = event.snapshot.value as Map?;

              if (data != null) {
                final double cred = (data['creditAmount'] ?? 5000.0).toDouble();
                final double bal = (data['walletBalance'] ?? 0.0).toDouble();
                // "Current Due" = credit - walletBalance
                final double due = (cred - bal).clamp(0.0, cred);
                
                final List<Map<String, dynamic>> txns = [];
                if (data.containsKey('transactions') && data['transactions'] is Map) {
                  final tData = data['transactions'] as Map;
                  tData.forEach((k, v) {
                    if (v is Map) {
                      v['id'] = k;
                      txns.add(Map<String, dynamic>.from(v));
                    }
                  });
                  txns.sort((a, b) {
                    final tA = a['at'] is int ? a['at'] as int : (a['at'] is double ? (a['at'] as double).toInt() : 0);
                    final tB = b['at'] is int ? b['at'] as int : (b['at'] is double ? (b['at'] as double).toInt() : 0);
                    return tB.compareTo(tA);
                  });
                }

                if (mounted) {
                  setState(() {
                    _creditAmount = cred;
                    _walletBalance = bal;
                    _totalDue = due;
                    _sliderValue = due;
                    _walletTransactions = txns;
                  });
                  // Properly trigger the animation so it updates the ring and _currentDue
                  _animateToDue(due);
                }
              }
            });

        _ordersSub = FirebaseDatabase.instance
            .ref('root/walletOrders/$last10Digits')
            .orderByKey()
            .limitToLast(250) // Increased for better historical accuracy
            .onValue
            .listen((event) {
              final data = event.snapshot.value as Map?;
              if (data != null) {
                final List<Map<String, dynamic>> orders = [];
                data.forEach((key, value) {
                  if (value is Map) {
                    value['orderId'] = key;
                    orders.add(Map<String, dynamic>.from(value));
                  }
                });
                orders.sort((a, b) {
                  final idA = int.tryParse(a['orderId'] ?? '') ?? 0;
                  final idB = int.tryParse(b['orderId'] ?? '') ?? 0;
                  return idB.compareTo(idA);
                });
                if (mounted) {
                  setState(() {
                    _recentOrders = orders;
                    _calculateStats();
                  });
                }
              }
            });
      }

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _ringController.forward();
      });

      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _chartController.forward();
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _barsController.forward();
      });
    });
  }

  @override
  void dispose() {
    _walletSub?.cancel();
    _ordersSub?.cancel();
    _particleTicker.dispose();
    _particleNotifier.dispose();
    _revealController.dispose();
    _ringController.dispose();
    _chartController.dispose();
    _barsController.dispose();
    super.dispose();
  }

  String _monthName(int m) {
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
    if (m >= 1 && m <= 12) return months[m - 1];
    return '';
  }

  void _calculateStats() {
    double currentMonthTotal = 0.0;
    double prevMonthTotal = 0.0;
    Map<String, int> itemCounts = {};
    Map<String, double> itemSpends = {};

    for (var order in _recentOrders) {
      final statusUpdatedAt = order['status_updated_at'] ?? '';
      if (statusUpdatedAt.isEmpty) continue;

      DateTime d;
      try {
        d = DateTime.parse(statusUpdatedAt).toLocal();
      } catch (_) {
        continue;
      }

      int price = 0;
      final paymentMethodStr = order['paymentMethod'] ?? '';
      if (paymentMethodStr.contains('-')) {
        final parts = paymentMethodStr.split('-');
        if (parts.length > 1) {
          price = int.tryParse(parts[1]) ?? 0;
        }
      }

      if (d.month == _selectedMonth && d.year == _selectedYear) {
        currentMonthTotal += price;

        // Aggregate items
        int index = 1;
        while (order.containsKey('item$index')) {
          final itemStr = order['item$index'] as String;
          String name = itemStr;
          double itemP = 0;
          int qty = 1;

          // Try qty format: "2X-Name-92RS(2X46RS)"
          final qtyMatch = RegExp(
            r'^(\d+)X-(.+)-(\d+)RS\(.*\)$',
          ).firstMatch(itemStr);
          if (qtyMatch != null) {
            qty = int.tryParse(qtyMatch.group(1) ?? '1') ?? 1;
            name = qtyMatch.group(2)!.trim();
            itemP = double.tryParse(qtyMatch.group(3) ?? '0') ?? 0;
          } else {
            // Simple format: "Name-46RS"
            final rIndex = itemStr.lastIndexOf('-');
            if (rIndex != -1 && itemStr.endsWith('RS')) {
              name = itemStr.substring(0, rIndex).trim();
              final pStr = itemStr.substring(rIndex + 1, itemStr.length - 2);
              itemP = double.tryParse(pStr) ?? 0;
            }
          }

          itemCounts[name] = (itemCounts[name] ?? 0) + qty;
          itemSpends[name] = (itemSpends[name] ?? 0) + itemP;
          index++;
        }
      } else {
        int pMonth = _selectedMonth - 1;
        int pYear = _selectedYear;
        if (pMonth == 0) {
          pMonth = 12;
          pYear--;
        }
        if (d.month == pMonth && d.year == pYear) {
          prevMonthTotal += price;
        }
      }
    }

    _filteredMonthSpend = currentMonthTotal;
    _previousMonthSpend = prevMonthTotal;

    // Build chart data based on range
    final List<Map<String, dynamic>> chartData = [];
    final now = DateTime.now();

    if (_chartRange == ChartRange.day) {
      // Last 7 days
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        double dayTotal = 0;
        for (var order in _recentOrders) {
          final sat = order['status_updated_at'] ?? '';
          if (sat.isEmpty) continue;
          try {
            final od = DateTime.parse(sat).toLocal();
            if (od.year == d.year && od.month == d.month && od.day == d.day) {
              final pm = order['paymentMethod'] ?? '';
              if (pm.contains('-')) {
                final parts = pm.split('-');
                if (parts.length > 1) dayTotal += (int.tryParse(parts[1]) ?? 0);
              }
            }
          } catch (_) {}
        }
        chartData.add({
          'm': i == 0 ? 'Today' : dayNames[d.weekday - 1],
          'v': dayTotal,
        });
      }
    } else if (_chartRange == ChartRange.month) {
      // Last 6 months
      for (int i = 5; i >= 0; i--) {
        DateTime d = DateTime(now.year, now.month - i, 1);
        double monthTotal = 0;
        for (var order in _recentOrders) {
          final sat = order['status_updated_at'] ?? '';
          if (sat.isEmpty) continue;
          try {
            final od = DateTime.parse(sat).toLocal();
            if (od.month == d.month && od.year == d.year) {
              final pm = order['paymentMethod'] ?? '';
              if (pm.contains('-')) {
                final parts = pm.split('-');
                if (parts.length > 1)
                  monthTotal += (int.tryParse(parts[1]) ?? 0);
              }
            }
          } catch (_) {}
        }
        chartData.add({'m': _monthName(d.month), 'v': monthTotal});
      }
    } else {
      // Last 4 years
      for (int i = 3; i >= 0; i--) {
        int y = now.year - i;
        double yearTotal = 0;
        for (var order in _recentOrders) {
          final sat = order['status_updated_at'] ?? '';
          if (sat.isEmpty) continue;
          try {
            final od = DateTime.parse(sat).toLocal();
            if (od.year == y) {
              final pm = order['paymentMethod'] ?? '';
              if (pm.contains('-')) {
                final parts = pm.split('-');
                if (parts.length > 1)
                  yearTotal += (int.tryParse(parts[1]) ?? 0);
              }
            }
          } catch (_) {}
        }
        chartData.add({'m': i == 0 ? 'This Yr' : y.toString(), 'v': yearTotal});
      }
    }
    _monthlySpendData = chartData;

    List<Map<String, dynamic>> bd = [];
    itemSpends.forEach((key, val) {
      bd.add({'name': key, 'spend': val, 'count': itemCounts[key] ?? 0});
    });

    if (_breakdownSort == 'qty') {
      bd.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    } else {
      bd.sort((a, b) => (b['spend'] as double).compareTo(a['spend'] as double));
    }
    _breakdownItems = bd;
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final List<DateTime> months = [];
        final now = DateTime.now();
        for (int i = 0; i < 12; i++) {
          int m = now.month - i;
          int y = now.year;
          while (m <= 0) {
            m += 12;
            y--;
          }
          months.add(DateTime(y, m, 1));
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Month',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textCol,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: months.length,
                  itemBuilder: (ctx, idx) {
                    final d = months[idx];
                    final isSel =
                        d.month == _selectedMonth && d.year == _selectedYear;
                    return ListTile(
                      title: Text(
                        '${_monthName(d.month)} ${d.year}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: isSel ? em : textCol,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedMonth = d.month;
                          _selectedYear = d.year;
                          _calculateStats();
                          _chartController.forward(from: 0.0);
                          _barsController.forward(from: 0.0);
                        });
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setDue(double v) {
    setState(() {
      _sliderValue = v;
    });
    _animateToDue(v);
  }

  void _animateToDue(double target) {
    final start = _currentDue;
    _ringController.duration = const Duration(milliseconds: 1200);
    final anim = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOutQuart),
    );
    _ringController.stop();
    anim.addListener(() {
      setState(() {
        _currentDue = anim.value;
      });
    });
    _ringController.forward(from: 0.0);
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(40, 0, 40, 30),
      ),
    );
  }

  Animation<double> _createRevealParam(int index) {
    final start = (0.05 + index * 0.05).clamp(0.0, 1.0);
    final end = (start + 0.3).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _revealController,
      curve: Interval(start, end, curve: Curves.easeOutExpo),
    );
  }

  Widget _buildReveal(Widget child, int index) {
    final anim = _createRevealParam(index);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        return Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, 28 * (1 - anim.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Background Atmosphere
          RepaintBoundary(
            child: _buildAtmosphere(),
          ),

          // Particles
          RepaintBoundary(
            child: ValueListenableBuilder<int>(
              valueListenable: _particleNotifier,
              builder: (context, val, _) {
                return CustomPaint(
                  painter: _ParticlePainter(_particles),
                  size: Size.infinite,
                );
              },
            ),
          ),

          // Main Scroll Content
          SafeArea(
            child: RepaintBoundary(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 28, 18, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildReveal(_buildHeader(), 0),
                        const SizedBox(height: 32),
                        _buildReveal(_buildRingCard(), 1),
                        const SizedBox(height: 24),
                        _buildReveal(const _SectionHeading('Monthly Spend'), 2),
                        _buildReveal(_buildChartCard(), 3),
                        const SizedBox(height: 24),
                        _buildReveal(_buildBreakdownSectionHeader(), 4),
                        _buildReveal(_buildBreakdownCard(), 5),
                        const SizedBox(height: 24),
                        _buildReveal(const _SectionHeading('Linked Stores'), 6),
                        _buildReveal(_buildLinkedAppsCard(), 7),
                        const SizedBox(height: 24),
                        _buildReveal(
                          const _SectionHeading('Recent Transactions'),
                          8,
                        ),
                      ]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    sliver: _buildTransactionsSliverList(),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildReveal(_buildRewardsCard(), 10),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
            ),
          ),
        ),

        // Back Button top left
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textCol,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtmosphere() {
    return Stack(
      children: [
        Positioned(
          top: -180,
          left: -100,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [em.withValues(alpha: 0.18), Colors.transparent],
                stops: const [0, 0.7],
              ),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox(),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          right: -120,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [blue.withValues(alpha: 0.18), Colors.transparent],
                stops: const [0, 0.7],
              ),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox(),
            ),
          ),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: MediaQuery.of(context).size.width * 0.2,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [purple.withValues(alpha: 0.18), Colors.transparent],
                stops: const [0, 0.7],
              ),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: glass,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: glassB),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: padding ?? const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x0AFFFFFF), // ~0.04 alpha
                  Colors.transparent,
                  Colors.transparent,
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'WALLET',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.88,
                color: textCol,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'GROCERY CREDIT',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.8,
                color: em,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: emDim,
                border: Border.all(color: em.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  _BlinkingDot(),
                  const SizedBox(width: 6),
                  const Text(
                    'Live',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: em,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _showToast('🔔 No new notifications'),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: glass,
                  border: Border.all(color: glassB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    '🔔',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 17),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRingCard() {
    int p = (_creditAmount > 0
        ? (_currentDue / _creditAmount * 100).round()
        : 0);
    Color badgeBg = emDim;
    Color badgeCol = em;
    Color badgeBorder = em.withValues(alpha: 0.2);

    if (p > 70) {
      badgeBg = const Color(0x26FF5E72); // ~0.15 alpha
      badgeCol = danger;
      badgeBorder = danger.withValues(alpha: 0.25);
    } else if (p > 50) {
      badgeBg = const Color(0x26FFB940); // ~0.15 alpha
      badgeCol = warn;
      badgeBorder = warn.withValues(alpha: 0.25);
    }

    return _AnimatedFloating(
      child: _buildGlassCard(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 26),
        child: Column(
          children: [
            // Ring
            SizedBox(
              width: 230,
              height: 230,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(230, 230),
                    painter: _RingPainter(
                      pct: _creditAmount > 0 ? _currentDue / _creditAmount : 0,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'CURRENT DUE',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: muted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text(
                            '₹',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: em,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _currentDue.round().toString(),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 46,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.38,
                              height: 1,
                              color: textCol,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'of ₹${_creditAmount.round()} limit',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          border: Border.all(color: badgeBorder),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$p% used',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: badgeCol,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Available',
                    value: '₹${_walletBalance.round()}',
                    valColor: em,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: _StatBox(label: 'Due Date', value: 'Apr 25'),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: _StatBox(
                    label: 'Cashback',
                    value: '₹340',
                    valColor: warn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '₹0',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: muted,
                    ),
                  ),
                  Text(
                    'Drag to adjust',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: em,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹${_totalDue.round()}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 5,
                activeTrackColor: em,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                min: 0,
                max: _totalDue > 0 ? _totalDue : 1,
                value: _sliderValue.clamp(0.0, _totalDue > 0 ? _totalDue : 1),
                onChanged: (val) {
                  setState(() {
                    _sliderValue = val;
                    _currentDue = val;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _QuickBtn(
                    label: '₹${(_totalDue * 0.25).round()}',
                    onTap: () => _setDue(_totalDue * 0.25),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickBtn(
                    label: '₹${(_totalDue * 0.50).round()}',
                    onTap: () => _setDue(_totalDue * 0.50),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickBtn(
                    label: '₹${(_totalDue * 0.75).round()}',
                    onTap: () => _setDue(_totalDue * 0.75),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickBtn(
                    label: 'Max',
                    onTap: () => _setDue(_totalDue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Primary Button
            _PrimaryButton(
              label: 'SETTLE FULL DUES',
              onTap: () async {
                final amount = _currentDue.round();
                if (amount <= 0) {
                  _showToast('Please adjust the amount to settle');
                  return;
                }
                const phone = '919539576024';
                final message = 'Hi, I want to repay my Daily Club credit due of ₹$amount.';
                final url = Uri.parse('whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}');
                final webUrl = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
                
                try {
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else if (await canLaunchUrl(webUrl)) {
                    await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                  } else {
                    _showToast('Could not launch WhatsApp');
                  }
                } catch (e) {
                  _showToast('Could not launch WhatsApp');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return _buildGlassCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _showMonthPicker,
                    child: Row(
                      children: [
                        Text(
                          '${_monthName(_selectedMonth)} $_selectedYear',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: em,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: em, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${_filteredMonthSpend.round()}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.44,
                      color: textCol,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      _SortChip(
                        label: 'Day',
                        selected: _chartRange == ChartRange.day,
                        onTap: () {
                          if (_chartRange != ChartRange.day) {
                            setState(() {
                              _chartRange = ChartRange.day;
                              _tappedChartIndex = null;
                              _calculateStats();
                              _chartController.forward(from: 0.0);
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      _SortChip(
                        label: 'Month',
                        selected: _chartRange == ChartRange.month,
                        onTap: () {
                          if (_chartRange != ChartRange.month) {
                            setState(() {
                              _chartRange = ChartRange.month;
                              _tappedChartIndex = null;
                              _calculateStats();
                              _chartController.forward(from: 0.0);
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      _SortChip(
                        label: 'Year',
                        selected: _chartRange == ChartRange.year,
                        onTap: () {
                          if (_chartRange != ChartRange.year) {
                            setState(() {
                              _chartRange = ChartRange.year;
                              _tappedChartIndex = null;
                              _calculateStats();
                              _chartController.forward(from: 0.0);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _previousMonthSpend > 0
                            ? '${_filteredMonthSpend >= _previousMonthSpend ? '↑' : '↓'} ${(((_filteredMonthSpend - _previousMonthSpend).abs() / _previousMonthSpend) * 100).toStringAsFixed(1)}%'
                            : (_filteredMonthSpend > 0 ? '↑ 100%' : '0%'),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              _filteredMonthSpend >= _previousMonthSpend &&
                                  _filteredMonthSpend > 0
                              ? danger
                              : em,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'vs Prev.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    if (_monthlySpendData.isEmpty) return;
                    const padL = 36.0, padR = 12.0;
                    final iw = constraints.maxWidth - padL - padR;
                    final xStep = iw / (_monthlySpendData.length - 1);

                    final tappedIdx =
                        ((details.localPosition.dx - padL + xStep / 2) / xStep)
                            .floor();
                    if (tappedIdx >= 0 &&
                        tappedIdx < _monthlySpendData.length) {
                      setState(() {
                        _tappedChartIndex = tappedIdx;
                      });
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _chartController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _ChartPainter(
                          animationValue: CurvedAnimation(
                            parent: _chartController,
                            curve: Curves.easeOutQuart,
                          ).value,
                          data: _monthlySpendData.isNotEmpty
                              ? _monthlySpendData
                              : [
                                  {'m': 'No data', 'v': 0.0},
                                ],
                          highlightIndex: _tappedChartIndex,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSectionHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'SPEND BREAKDOWN',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: muted,
              letterSpacing: 1.2,
            ),
          ),
          Row(
            children: [
              _SortChip(
                label: 'Most Qty',
                selected: _breakdownSort == 'qty',
                onTap: () {
                  if (_breakdownSort != 'qty') {
                    setState(() {
                      _breakdownSort = 'qty';
                      _calculateStats();
                      _barsController.forward(from: 0.0);
                    });
                  }
                },
              ),
              const SizedBox(width: 6),
              _SortChip(
                label: 'Most Price',
                selected: _breakdownSort == 'price',
                onTap: () {
                  if (_breakdownSort != 'price') {
                    setState(() {
                      _breakdownSort = 'price';
                      _calculateStats();
                      _barsController.forward(from: 0.0);
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard() {
    if (_breakdownItems.isEmpty) {
      return _buildGlassCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No item purchases found for this period.',
              style: TextStyle(
                color: muted,
                fontFamily: 'Poppins',
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final List<Color> colors = [em, blue, warn, purple, danger];
    List<Widget> rows = [];
    double maxSpend = _breakdownItems.isNotEmpty
        ? _breakdownItems.first['spend']
        : 1;
    if (maxSpend <= 0) maxSpend = 1;

    for (int i = 0; i < _breakdownItems.length && i < 5; i++) {
      final item = _breakdownItems[i];
      final col = colors[i % colors.length];
      final name = '${item['count']}x ${item['name']}';
      final val = '₹${(item['spend'] as double).round()}';
      final pct =
          ((item['spend'] as double) / maxSpend) *
          0.85; // slightly scaled down to allow space

      rows.add(
        _BreakdownRow(
          name: name,
          val: val,
          pct: pct.clamp(0.0, 1.0),
          col: col,
          ctrl: _barsController,
        ),
      );
      if (i < _breakdownItems.length - 1 && i < 4) {
        rows.add(const SizedBox(height: 14));
      }
    }

    return _buildGlassCard(child: Column(children: rows));
  }

  Widget _buildLinkedAppsCard() {
    return _buildGlassCard(
      child: Row(
        children: [
          Expanded(
            child: _AppChip(
              '🟡',
              'Naasak Supermart',
              'Connected',
              true,
              () => _showToast('Naasak Supermart: 12 orders this month'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AppChip(
              '🟠',
              'Thengumtharayil store',
              'Connected',
              true,
              () => _showToast('Thengumtharayil store: 5 orders this month'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AppChip(
              '🟢',
              'Patharam Store',
              'Connected',
              true,
              () => _showToast('Patharam Store: 3 orders this month'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AppChip(
              '+',
              'Add App',
              'Link more',
              false,
              () => _showToast('Opening app store...'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSliverList() {
    if (_walletTransactions.isEmpty && _recentOrders.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildReveal(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No recent transactions',
              style: TextStyle(fontFamily: 'Poppins', color: muted, fontSize: 13),
            ),
          ),
          9,
        ),
      );
    }

    if (_walletTransactions.isNotEmpty) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final txn = _walletTransactions[index];
            final type = txn['type'] ?? '';
            final amount = txn['amount'] is int ? txn['amount'] as int : (txn['amount'] is double ? (txn['amount'] as double).toInt() : 0);
            final at = txn['at'] is int ? txn['at'] as int : (txn['at'] is double ? (txn['at'] as double).toInt() : 0);
            final note = txn['note'] ?? '';

            String dateStr = 'Unknown';
            if (at > 0) {
              final d = DateTime.fromMillisecondsSinceEpoch(at).toLocal();
              final months = [
                'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
              ];
              final hr = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
              final ampm = d.hour >= 12 ? 'PM' : 'AM';
              dateStr = '${d.day} ${months[d.month - 1]}, $hr:${d.minute.toString().padLeft(2, '0')} $ampm';
            }

            final isRefill = type.toString().toLowerCase().contains('refill');
            final icon = isRefill ? '💰' : '🛒';
            final title = (note.isNotEmpty && isRefill) ? note : (note.isNotEmpty ? note : 'Order');
            final displayAmt = isRefill ? amount : -amount;
            final tag = isRefill ? 'Refill' : 'Grocery';
            final tagColor = isRefill ? em : const Color(0xFF00C97A);

            Map<String, dynamic>? matchingOrder;
            if (!isRefill) {
              final tOrdId = txn['orderId']?.toString();
              int minDiff = 999999999;
              for (var o in _recentOrders) {
                if (tOrdId != null && o['orderId']?.toString() == tOrdId) {
                  matchingOrder = o;
                  break;
                }
                final pm = o['paymentMethod'] ?? '';
                int p = 0;
                if (pm.contains('-')) {
                  final parts = pm.split('-');
                  if (parts.length > 1) p = int.tryParse(parts[1]) ?? 0;
                }
                if (p == amount) {
                  final sat = o['status_updated_at'] ?? o['placed_at'] ?? '';
                  if (sat.isNotEmpty) {
                    try {
                      final od = DateTime.parse(sat).toLocal().millisecondsSinceEpoch;
                      final diff = (od - at).abs();
                      if (diff < minDiff && diff < 300000) { // 5 minutes window
                        minDiff = diff;
                        matchingOrder = o;
                      }
                    } catch (_) {}
                  }
                }
              }
            }

            return _buildReveal(
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _TxnCard(
                  icon: icon,
                  name: title,
                  date: dateStr,
                  amt: displayAmt,
                  tag: tag,
                  tagCol: tagColor,
                  onTap: isRefill ? null : () {
                    if (matchingOrder != null) {
                      _showOrderDetails(matchingOrder, dateStr, amount);
                    } else {
                      _showToast('Order details not available');
                    }
                  },
                ),
              ),
              9,
            );
          },
          childCount: _walletTransactions.length,
        ),
      );
    }

    // Fallback to legacy orders
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final order = _recentOrders[index];
          final orderId = order['orderId'] ?? '';
          final statusUpdatedAt = order['status_updated_at'] ?? '';
          String dateStr = 'Unknown';
          if (statusUpdatedAt.isNotEmpty) {
            try {
              final d = DateTime.parse(statusUpdatedAt).toLocal();
              final months = [
                'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
              ];
              final hr = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
              final ampm = d.hour >= 12 ? 'PM' : 'AM';
              dateStr =
                  '${d.day} ${months[d.month - 1]}, $hr:${d.minute.toString().padLeft(2, '0')} $ampm';
            } catch (_) {}
          }

          final paymentMethodStr = order['paymentMethod'] ?? '';
          int price = 0;
          if (paymentMethodStr.contains('-')) {
            final parts = paymentMethodStr.split('-');
            if (parts.length > 1) {
              price = int.tryParse(parts[1]) ?? 0;
            }
          }

          return _buildReveal(
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _TxnCard(
                icon: '🛒',
                name: 'Order #$orderId',
                date: dateStr,
                amt: -price,
                tag: 'Grocery',
                tagCol: const Color(0xFF00C97A),
                onTap: () => _showOrderDetails(order, dateStr, price),
              ),
            ),
            9,
          );
        },
        childCount: _recentOrders.length,
      ),
    );
  }

  void _showOrderDetails(
    Map<String, dynamic> order,
    String dateStr,
    int price,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );

        List<Widget> itemWidgets = [];
        int index = 1;
        while (order.containsKey('item$index')) {
          itemWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${order['item$index']}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: textCol,
                ),
              ),
            ),
          );
          index++;
        }

        return ScaleTransition(
          scale: curved,
          child: AlertDialog(
            backgroundColor: glass,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            contentPadding: EdgeInsets.zero,
            content: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: glassB,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${order['orderId']}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textCol,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: em.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '🛒',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: em,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...itemWidgets,
                      const SizedBox(height: 20),
                      const Divider(color: glassB, thickness: 1),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Paid',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: muted,
                            ),
                          ),
                          Text(
                            '₹$price',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textCol,
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
        );
      },
    );
  }

  Widget _buildRewardsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [em.withValues(alpha: 0.08), blue.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: em.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '🎁 Rewards Available',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textCol,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '340 pts · Redeem up to ₹170 on next order',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _showToast('🎉 ₹170 cashback credited!'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(color: em.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(12),
                color: Colors.transparent,
              ),
              child: const Text(
                'Redeem',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: em,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smaller Component Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedFloating extends StatefulWidget {
  final Widget child;
  const _AnimatedFloating({required this.child});

  @override
  State<_AnimatedFloating> createState() => _AnimatedFloatingState();
}

class _AnimatedFloatingState extends State<_AnimatedFloating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0,
      end: -6,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));
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
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, _anim.value), child: child),
      child: widget.child,
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Opacity(
        opacity: 0.3 + 0.7 * _c.value,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: _WalletPageState.em,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  const _SectionHeading(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _WalletPageState.muted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valColor;

  const _StatBox({
    required this.label,
    required this.value,
    this.valColor = _WalletPageState.textCol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0x09FFFFFF),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              color: _WalletPageState.muted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          border: Border.all(color: const Color(0x17FFFFFF)),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _WalletPageState.textCol,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineCtrl;

  @override
  void initState() {
    super.initState();
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: false);
  }

  @override
  void dispose() {
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shineCtrl,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _WalletPageState.em,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x4D00FFA3), blurRadius: 30),
              ],
              gradient: LinearGradient(
                begin: Alignment(-1.5 + _shineCtrl.value * 3, 0),
                end: Alignment(-0.5 + _shineCtrl.value * 3, 0),
                colors: [
                  _WalletPageState.em,
                  Colors.white.withValues(alpha: 0.6),
                  _WalletPageState.em,
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: 1.0,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String name;
  final String val;
  final double pct;
  final Color col;
  final AnimationController ctrl;

  const _BreakdownRow({
    required this.name,
    required this.val,
    required this.pct,
    required this.col,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _WalletPageState.textCol,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              val,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: col,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          height: 5,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0x12FFFFFF),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.centerLeft,
          child: AnimatedBuilder(
            animation: ctrl,
            builder: (context, child) {
              return FractionallySizedBox(
                widthFactor:
                    CurvedAnimation(
                      parent: ctrl,
                      curve: Curves.easeOutExpo,
                    ).value *
                    pct,
                child: Container(
                  decoration: BoxDecoration(
                    color: col,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _WalletPageState.em : const Color(0x12FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0x1AFFFFFF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 9,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? Colors.black : _WalletPageState.muted,
          ),
        ),
      ),
    );
  }
}

class _AppChip extends StatelessWidget {
  final String icon;
  final String name;
  final String status;
  final bool isOk;
  final VoidCallback onTap;

  const _AppChip(this.icon, this.name, this.status, this.isOk, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          border: Border.all(color: const Color(0x12FFFFFF)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              icon,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                color: icon == '+' ? _WalletPageState.muted : null,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: icon == '+'
                    ? _WalletPageState.muted
                    : _WalletPageState.textCol,
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                color: isOk ? _WalletPageState.em : _WalletPageState.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxnCard extends StatelessWidget {
  final String icon;
  final String name;
  final String date;
  final int amt;
  final String tag;
  final Color tagCol;
  final VoidCallback? onTap;

  const _TxnCard({
    required this.icon,
    required this.name,
    required this.date,
    required this.amt,
    required this.tag,
    required this.tagCol,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _WalletPageState.glass,
          border: Border.all(color: _WalletPageState.glassB),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                icon,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _WalletPageState.textCol,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        date,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: _WalletPageState.muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tagCol.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: tagCol,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              amt > 0 ? '+₹$amt' : '-₹${amt.abs()}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: amt > 0 ? _WalletPageState.em : _WalletPageState.textCol,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

class _Particle {
  double x, y, r, vx, vy, a;
  _Particle({
    required this.x,
    required this.y,
    required this.r,
    required this.vx,
    required this.vy,
    required this.a,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final paint = Paint();
    for (var p in particles) {
      paint.color = _WalletPageState.em.withValues(
        alpha: p.a * 0.4,
      ); // adjusted opacity
      canvas.drawCircle(Offset(p.x, p.y), p.r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

class _RingPainter extends CustomPainter {
  final double pct;
  _RingPainter({required this.pct});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6.5; // half stroke
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background full ring
    final bgPaint = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13;
    canvas.drawCircle(center, radius, bgPaint);

    // Dotted accent ring (approximate)
    final accPaint = Paint()
      ..color =
          const Color(0x1900FFA3) // ~0.1 alpha
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13;

    double dashLength = 4 * 180 / (math.pi * radius);
    double gapLength = 10 * 180 / (math.pi * radius);
    double currentA = -90.0;
    while (currentA < 270.0) {
      canvas.drawArc(
        rect,
        currentA * math.pi / 180,
        dashLength * math.pi / 180,
        false,
        accPaint,
      );
      currentA += dashLength + gapLength;
    }

    // Main colored sweep
    final sweepGradient = SweepGradient(
      colors: const [_WalletPageState.em, _WalletPageState.blue],
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      transform: const GradientRotation(-math.pi / 2),
    );

    final mainPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13;

    // Glowing drop shadow under the arc
    // In Flutter, drawing a stroke with blur effectively gives a glow.
    final blurPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final sweepAngle = (pct * 2 * math.pi);
    // Draw glow
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, blurPaint);
    // Draw actual line
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, mainPaint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.pct != pct;
}

class _ChartPainter extends CustomPainter {
  final double animationValue;
  final List<Map<String, dynamic>> data;
  final int? highlightIndex;

  _ChartPainter({
    required this.animationValue,
    required this.data,
    this.highlightIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const padL = 36.0, padR = 12.0, padT = 14.0, padB = 26.0;
    final iw = w - padL - padR;
    final ih = h - padT - padB;

    if (data.isEmpty || (data.length == 1 && data[0]['v'] == 0.0)) {
      // Draw empty state text
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Not enough data',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Color(0x40FFFFFF),
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));
      return;
    }

    final values = data.map((e) => (e['v'] as num).toDouble()).toList();
    double minV = values.reduce((a, b) => a < b ? a : b);
    double maxV = values.reduce((a, b) => a > b ? a : b);

    // Provide some buffer so line isn't at exact edges
    if (maxV == minV) {
      maxV = minV + 100;
    }
    final range = maxV - minV;
    minV -= range * 0.1;
    maxV += range * 0.15;

    final xStep = iw / (data.length - 1);
    double getY(double v) => padT + ih - ((v - minV) / (maxV - minV)) * ih;

    final pts = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      pts.add(Offset(padL + i * xStep, getY(values[i])));
    }

    // Grid Lines + Y labels
    final gridPaint = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1;

    for (var f in [0.25, 0.5, 0.75, 1.0]) {
      final y = padT + ih * (1 - f);
      canvas.drawLine(Offset(padL, y), Offset(w - padR, y), gridPaint);
      final val = (minV + (maxV - minV) * f);
      final label = val >= 1000
          ? '₹${(val / 1000).toStringAsFixed(1)}K'
          : '₹${val.round()}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Color(0x40FFFFFF),
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL - tp.width - 4, y - tp.height / 2));
    }

    // X Labels
    for (int i = 0; i < data.length; i++) {
      bool isHigh = highlightIndex == i;
      final tp = TextPainter(
        text: TextSpan(
          text: data[i]['m'] as String,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: isHigh ? _WalletPageState.em : const Color(0x59FFFFFF),
            fontSize: 9,
            fontWeight: isHigh ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pts[i].dx - tp.width / 2, h - 14));
    }

    // Curve Path
    final path = Path();
    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1];
      final p1 = pts[i];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    // Animate path drawing
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final length = metrics.fold(0.0, (sum, m) => sum + m.length);
    final animatedLength = length * animationValue;

    final animPath = Path();
    double currentLength = 0;
    for (var metric in metrics) {
      if (currentLength + metric.length <= animatedLength) {
        animPath.addPath(metric.extractPath(0, metric.length), Offset.zero);
        currentLength += metric.length;
      } else {
        animPath.addPath(
          metric.extractPath(0, animatedLength - currentLength),
          Offset.zero,
        );
        break;
      }
    }

    // Area Fill
    if (animationValue > 0) {
      final areaPath = Path.from(animPath);
      final bound = animPath.getBounds();
      areaPath.lineTo(bound.right, padT + ih);
      areaPath.lineTo(padL, padT + ih);
      areaPath.close();

      final areaGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _WalletPageState.em.withValues(alpha: 0.28 * animationValue),
          _WalletPageState.em.withValues(alpha: 0.04 * animationValue),
          _WalletPageState.em.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(0, padT, 0, padT + ih));

      canvas.drawPath(areaPath, Paint()..shader = areaGradient);
    }

    // Line Path
    final lineGrad = const LinearGradient(
      colors: [_WalletPageState.em, _WalletPageState.blue],
    ).createShader(Rect.fromLTRB(padL, 0, w - padR, 0));
    canvas.drawPath(
      animPath,
      Paint()
        ..shader = lineGrad
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    if (animationValue == 1.0) {
      final dotPaintBg = Paint()..color = _WalletPageState.bg;
      final dotPaintSt = Paint()
        ..color = _WalletPageState.em
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final dotPaintFill = Paint()..color = _WalletPageState.em;

      for (int i = 0; i < pts.length; i++) {
        final isSelected = highlightIndex == i;
        final isLast = i == pts.length - 1;

        if (isSelected) {
          // Glow for selected
          canvas.drawCircle(
            pts[i],
            7,
            Paint()
              ..color = _WalletPageState.em.withValues(alpha: 0.4)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
          canvas.drawCircle(pts[i], 6, dotPaintFill);

          // Tooltip Price
          final priceLabel = '₹${values[i].round()}';
          final tp = TextPainter(
            text: TextSpan(
              text: priceLabel,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final tooltipRect = Rect.fromCenter(
            center: Offset(pts[i].dx, pts[i].dy - 24),
            width: tp.width + 16,
            height: tp.height + 8,
          );
          final rrect = RRect.fromRectAndRadius(
            tooltipRect,
            const Radius.circular(8),
          );

          // Outer glow for tooltip
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = Colors.black.withValues(alpha: 0.25)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );

          // Tooltip baground
          canvas.drawRRect(rrect, Paint()..color = _WalletPageState.em);

          // Small triangle pointer
          final pointerPath = Path()
            ..moveTo(pts[i].dx - 5, pts[i].dy - 16)
            ..lineTo(pts[i].dx + 5, pts[i].dy - 16)
            ..lineTo(pts[i].dx, pts[i].dy - 11)
            ..close();
          canvas.drawPath(pointerPath, Paint()..color = _WalletPageState.em);

          tp.paint(
            canvas,
            Offset(pts[i].dx - tp.width / 2, pts[i].dy - 24 - tp.height / 2),
          );
        } else if (isLast) {
          canvas.drawCircle(
            pts[i],
            5,
            Paint()
              ..color = _WalletPageState.em
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
          canvas.drawCircle(pts[i], 5, dotPaintFill);
        } else {
          canvas.drawCircle(pts[i], 4, dotPaintBg);
          canvas.drawCircle(pts[i], 4, dotPaintSt);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.data != data ||
      oldDelegate.highlightIndex != highlightIndex;
}
