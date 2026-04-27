import 'package:flutter/material.dart';

import 'cart_controller.dart';

/// Provides a single [CartController] to the widget tree so cart count and
/// items stay in sync across Items, Product Details, and Cart pages.
class CartScope extends InheritedNotifier<CartController> {
  const CartScope({
    super.key,
    required CartController cartController,
    required super.child,
  }) : super(notifier: cartController);

  static CartController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
    assert(scope != null, 'CartScope not found. Wrap app with CartScope.');
    return scope!.notifier!;
  }

  /// Fetches the CartController WITHOUT registering a dependency. 
  /// The calling widget will NOT rebuild when the cart changes.
  static CartController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<CartScope>();
    assert(element != null, 'CartScope not found. Wrap app with CartScope.');
    return (element!.widget as CartScope).notifier!;
  }

  static CartController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CartScope>()?.notifier;
  }
}
