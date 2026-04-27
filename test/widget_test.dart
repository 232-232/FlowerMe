import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_club_beta/main.dart';
import 'package:daily_club_beta/providers/delivery_location_provider.dart';
import 'package:daily_club_beta/providers/favorites_provider.dart';
import 'package:daily_club_beta/providers/order_provider.dart';
import 'package:daily_club_beta/providers/user_profile_provider.dart';
import 'package:daily_club_beta/providers/home_feed_provider.dart';
import 'package:daily_club_beta/providers/recent_search_provider.dart';
import 'package:daily_club_beta/providers/items_cache_provider.dart';

void main() {
  testWidgets('app renders home page', (WidgetTester tester) async {
    // Provide empty in-memory SharedPreferences so providers can load
    // without touching real disk / platform channels during testing.
    SharedPreferences.setMockInitialValues({});

    final userProfileProvider = UserProfileProvider();
    final favoritesProvider = FavoritesProvider();
    final orderProvider = OrderProvider();

    await Future.wait([
      userProfileProvider.loadProfile(),
      favoritesProvider.loadFavorites(),
      orderProvider.loadOrders(),
    ]);

    await tester.pumpWidget(DailyClubApp(
      userProfileProvider: userProfileProvider,
      favoritesProvider: favoritesProvider,
      orderProvider: orderProvider,
      deliveryLocationProvider: DeliveryLocationProvider(),
      homeFeedProvider: HomeFeedProvider(),
      recentSearchProvider: RecentSearchProvider(),
      itemsCacheProvider: ItemsCacheProvider(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Daily Club'), findsOneWidget);
    expect(find.text('BUY NOW'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsWidgets);
  });
}
