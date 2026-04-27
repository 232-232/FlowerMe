import 'dart:ui' show channelBuffers;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show FrameTiming, SchedulerBinding;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'debug/dc_log.dart';
import 'debug/perf_logger.dart';

import 'cart_controller.dart';
import 'cart_scope.dart';
import 'pages/home_page.dart';
import 'pages/product_details_page.dart';
import 'pages/items_page.dart';
import 'models/product.dart';
import 'models/firebase_product_model.dart';
import 'providers/delivery_location_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/order_provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/home_feed_provider.dart';
import 'providers/recent_search_provider.dart';
import 'providers/items_cache_provider.dart';
import 'theme/app_colors.dart';
import 'layout/responsive_layout.dart';

bool _isNavigating = false;

class JankNavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _isNavigating = true;
    dcLog('Navigation', 'PUSH: ${route.settings.name ?? route.runtimeType}');
    Future.delayed(
      const Duration(milliseconds: 500),
      () => _isNavigating = false,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _isNavigating = true;
    dcLog('Navigation', 'POP: ${route.settings.name ?? route.runtimeType}');
    Future.delayed(
      const Duration(milliseconds: 500),
      () => _isNavigating = false,
    );
  }
}

// ── Debug-only frame-timing callback ─────────────────────────────────────────
// Flutter Web runs inside the browser compositor, so frames naturally take
// longer than 16 ms. Only log frames that are genuinely problematic:
//   🔴 CRITICAL  → total > 100 ms  (severe jank, visible freeze)
//   🟡 SLOW      → total >  50 ms  (noticeable stutter)
//   (< 50 ms is normal browser overhead — ignored)
void _onFrameTimings(List<FrameTiming> timings) {
  if (!kDebugMode) return;
  for (final t in timings) {
    final buildMs = t.buildDuration.inMicroseconds / 1000;
    final rasterMs = t.rasterDuration.inMicroseconds / 1000;
    final totalMs = t.totalSpan.inMicroseconds / 1000;

    String? tag = totalMs > 100
        ? 'FRAME 🔴 CRITICAL'
        : totalMs > 50
        ? 'FRAME 🟡 SLOW'
        : null;

    if (tag != null && _isNavigating) {
      tag = 'NAVIGATION JANK  $tag';
    }

    if (tag != null) {
      dcLog(
        tag,
        'build: ${buildMs.toStringAsFixed(1)}ms  '
        'raster: ${rasterMs.toStringAsFixed(1)}ms  '
        'total: ${totalMs.toStringAsFixed(1)}ms',
      );
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ── Debug instrumentation (stripped from release builds) ─────────────────
  if (kDebugMode) {
    // Keep Flutter's own dirty-widget flood OFF — RebuildTracker handles our widgets.
    debugPrintRebuildDirtyWidgets = false;
    // Catch slow / dropped frames.
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    dcLog(
      'App',
      '🐛 Debug tracking active — RebuildTracker + junk frames only',
    );
  }

  // Suppress "discarded" warnings for flutter/lifecycle (plugin messages
  // before framework listener is ready, common on hot restart / web).
  channelBuffers.allowOverflow('flutter/lifecycle', true);

  if (kIsWeb) {
    final void Function(FlutterErrorDetails)? upstream = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      try {
        if (_isKnownWebNoiseError(details)) return;
        (upstream ?? FlutterError.presentError)(details);
      } catch (_) {
        // Web DDC: LegacyJavaScriptObject cannot be cast to DiagnosticsNode.
        // Fall back to raw string print so errors are never silently swallowed.
        dcLog('FlutterError', details.exceptionAsString());
      }
    };
  }

  // ── Pre-load providers from local storage before first frame ─────────────
  final userProfileProvider = UserProfileProvider();
  final favoritesProvider = FavoritesProvider();
  final orderProvider = OrderProvider();
  final deliveryLocationProvider = DeliveryLocationProvider();
  final homeFeedProvider = HomeFeedProvider();
  final recentSearchProvider = RecentSearchProvider();
  final itemsCacheProvider = ItemsCacheProvider();

  await Future.wait([
    userProfileProvider.loadProfile(),
    favoritesProvider.loadFavorites(),
    orderProvider.loadOrders(),
    recentSearchProvider.init(),
  ]);

  userProfileProvider.addListener(() {
    if (userProfileProvider.phone.isNotEmpty) {
      favoritesProvider.syncWithFirebase(userProfileProvider.phone);
    }
  });

  if (userProfileProvider.phone.isNotEmpty) {
    favoritesProvider.syncWithFirebase(userProfileProvider.phone);
  }

  Perf.log('App', 'Before runApp');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Perf.log('App', 'First frame rendered');
    homeFeedProvider.fetchFeed();
  });

  runApp(
    DailyClubApp(
      userProfileProvider: userProfileProvider,
      favoritesProvider: favoritesProvider,
      orderProvider: orderProvider,
      deliveryLocationProvider: deliveryLocationProvider,
      homeFeedProvider: homeFeedProvider,
      recentSearchProvider: recentSearchProvider,
      itemsCacheProvider: itemsCacheProvider,
    ),
  );

  Perf.log('App', 'After runApp');
}

/// Returns true for Flutter-Web-specific framework noise that should be
/// silently dropped. None of these appear in release builds.
bool _isKnownWebNoiseError(FlutterErrorDetails details) {
  final msg = details.exceptionAsString();
  // 1. Engine view was torn down before a frame completed.
  if (msg.contains('disposed EngineFlutterView')) return true;
  // 2. Browser keyboard event arrives as a JS object during a route
  //    transition — Flutter tries to cast it to LogicalKeyboardKey.
  if (msg.contains("type 'LegacyJavaScriptObject' is not a subtype of type 'LogicalKeyboardKey'")) return true;
  // 3. Flutter's debug RenderObject assertion fires against a cached
  //    JS DOM object left over from a previous widget-tree state.
  if (msg.contains("type 'LegacyJavaScriptObject' is not a subtype of type 'RenderObject'")) return true;
  return false;
}

class _BouncingScrollBehavior extends ScrollBehavior {
  const _BouncingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class DailyClubApp extends StatelessWidget {
  const DailyClubApp({
    super.key,
    required this.userProfileProvider,
    required this.favoritesProvider,
    required this.orderProvider,
    required this.deliveryLocationProvider,
    required this.homeFeedProvider,
    required this.recentSearchProvider,
    required this.itemsCacheProvider,
  });

  final UserProfileProvider userProfileProvider;
  final FavoritesProvider favoritesProvider;
  final OrderProvider orderProvider;
  final DeliveryLocationProvider deliveryLocationProvider;
  final HomeFeedProvider homeFeedProvider;
  final RecentSearchProvider recentSearchProvider;
  final ItemsCacheProvider itemsCacheProvider;

  @override
  Widget build(BuildContext context) {
    final themeController = AppThemeController();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: userProfileProvider,
        ),
        ChangeNotifierProvider<FavoritesProvider>.value(
          value: favoritesProvider,
        ),
        ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
        ChangeNotifierProvider<DeliveryLocationProvider>.value(
          value: deliveryLocationProvider,
        ),
        ChangeNotifierProvider<HomeFeedProvider>.value(value: homeFeedProvider),
        ChangeNotifierProvider<RecentSearchProvider>.value(
          value: recentSearchProvider,
        ),
        ChangeNotifierProvider<ItemsCacheProvider>.value(
          value: itemsCacheProvider,
        ),
      ],
      child: CartScope(
        cartController: CartController(),
        child: AppThemeScope(
          controller: themeController,
          child: Builder(
            builder: (context) {
              final appTheme = AppThemeScope.themeOf(context);

              return ResponsiveLayout(
                child: MaterialApp(
                  title: 'Daily Club',
                  debugShowCheckedModeBanner: false,
                  navigatorObservers: [JankNavigationObserver()],
                  scrollBehavior: const _BouncingScrollBehavior(),
                  theme: ThemeData(
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: appTheme.primaryAccent,
                    ),
                    scaffoldBackgroundColor: appTheme.gradientTop,
                    useMaterial3: false,
                    pageTransitionsTheme: const PageTransitionsTheme(
                      builders: {
                        TargetPlatform.android:
                            CupertinoPageTransitionsBuilder(),
                        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                        TargetPlatform.windows:
                            CupertinoPageTransitionsBuilder(),
                        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
                      },
                    ),
                    fontFamilyFallback: const [
                      'NotoSans',
                      'NotoMalayalam',
                      'Roboto',
                      'Arial',
                    ],
                  ),
                  home: const HomePage(),
                  onGenerateRoute: (settings) {
                    final uri = Uri.parse(settings.name ?? '/');

                    if (uri.pathSegments.length == 2 &&
                        uri.pathSegments.first == 'category') {
                      final categoryParam = Uri.decodeComponent(
                        uri.pathSegments[1],
                      );
                      return MaterialPageRoute(
                        builder: (_) =>
                            ItemsPage(initialCategory: categoryParam),
                      );
                    }

                    if (uri.pathSegments.length == 2 &&
                        uri.pathSegments.first == 'item') {
                      final productCode = uri.pathSegments[1];
                      return MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: FutureBuilder<DatabaseEvent>(
                            future: FirebaseDatabase.instance
                                .ref('root/products/$productCode')
                                .once(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasData &&
                                  snapshot.data?.snapshot.value != null) {
                                try {
                                  final fbProduct =
                                      FirebaseProductModel.fromSnapshot(
                                        productCode,
                                        snapshot.data!.snapshot.value,
                                      );
                                  final product = Product(
                                    name: fbProduct.name,
                                    weight: fbProduct.weight,
                                    image: fbProduct.picUrl ?? '',
                                    price: fbProduct.price,
                                    oldPrice: fbProduct.originalPrice,
                                    discount: fbProduct.discount,
                                    productCode: fbProduct.code,
                                    unit: fbProduct.unit,
                                    description: fbProduct.details,
                                  );
                                  return ProductDetailsPage(product: product);
                                } catch (_) {
                                  return const HomePage();
                                }
                              }
                              return const HomePage();
                            },
                          ),
                        ),
                      );
                    }

                    // Fallback to null means it will just display the home layout
                    return null;
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
