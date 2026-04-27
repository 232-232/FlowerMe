import 'package:flutter/foundation.dart';

import 'models/cart_entry.dart';
import 'models/product.dart';

/// Manages cart entries, count, total, last added product (for card highlight),
/// bottom bar visibility, and cart icon bounce trigger.
/// Use [ListenableBuilder] to react to changes.
class CartController extends ChangeNotifier {
  CartController();

  final List<CartEntry> _entries = [];
  List<CartEntry> get entries => List.unmodifiable(_entries);

  List<CartEntry> _savedItems = [];
  bool get hasSavedItems => _savedItems.isNotEmpty;

  /// Total number of units (sum of quantities) across all entries.
  int get count {
    int n = 0;
    for (final e in _entries) {
      n += e.quantity;
    }
    return n;
  }

  /// Total price of all cart lines.
  double get totalPrice {
    double t = 0;
    for (final e in _entries) {
      t += e.lineTotal;
    }
    return t;
  }

  Product? _lastAddedProduct;
  Product? get lastAddedProduct => _lastAddedProduct;

  String? _customerName;
  String? _customerPhone;
  String? _customerAddress;
  /// Raw GPS coordinates string "lat, lng" — populated when the user uses the
  /// location picker. Used for the Firebase `adrs` field instead of the
  /// human-readable formatted address.
  String? _customerGpsCoords;
  String _deliveryInstruction = '';

  String? get customerName => _customerName;
  String? get customerPhone => _customerPhone;
  String? get customerAddress => _customerAddress;
  /// Returns the GPS coordinate string if available, otherwise falls back to
  /// the human-readable address for use in Firebase.
  String? get customerGpsCoords => _customerGpsCoords;
  String get deliveryInstruction => _deliveryInstruction;

  bool get hasCustomerDetails =>
      (_customerName != null && _customerName!.trim().isNotEmpty) &&
      (_customerPhone != null && _customerPhone!.trim().isNotEmpty) &&
      (_customerAddress != null && _customerAddress!.trim().isNotEmpty);

  bool _showBottomBar = false;
  bool get showBottomBar => _showBottomBar;

  /// ID of the most recently placed active order (for floating track card).
  String? _latestActiveOrderId;
  String? get latestActiveOrderId => _latestActiveOrderId;

  /// Number of orders that are currently active/trackable.
  int _activeOrderCount = 0;
  int get activeOrderCount => _activeOrderCount;

  int _bounceTrigger = 0;
  int get bounceTrigger => _bounceTrigger;

  /// Add [quantity] of [product] with [variantIndex]. If same product+variant
  /// already exists, merges quantity.
  void add(Product product, int quantity, {int variantIndex = 0}) {
    if (quantity <= 0) return;
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (_sameProductVariant(e, product, variantIndex)) {
        _entries[i] = CartEntry(
          product: e.product,
          quantity: e.quantity + quantity,
          variantIndex: e.variantIndex,
        );
        _setLastAddedAndNotify(product);
        return;
      }
    }
    _entries.add(CartEntry(
      product: product,
      quantity: quantity,
      variantIndex: variantIndex,
    ));
    _setLastAddedAndNotify(product);
  }

  /// Adds [product], triggers the cart-icon bounce, and shows the bottom bar
  /// in **one** [notifyListeners] call instead of three.
  /// Use this from the UI instead of calling [add] + [triggerBounce] + [showAddedBar].
  void addWithUi(Product product, int quantity, {int variantIndex = 0}) {
    if (quantity <= 0) return;
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (_sameProductVariant(e, product, variantIndex)) {
        _entries[i] = CartEntry(
          product: e.product,
          quantity: e.quantity + quantity,
          variantIndex: e.variantIndex,
        );
        _lastAddedProduct = product;
        _bounceTrigger++;
        _showBottomBar = true;
        notifyListeners();
        return;
      }
    }
    _entries.add(CartEntry(
      product: product,
      quantity: quantity,
      variantIndex: variantIndex,
    ));
    _lastAddedProduct = product;
    _bounceTrigger++;
    _showBottomBar = true;
    notifyListeners();
  }

  /// Sets the absolute quantity for a product. Removes if quantity <= 0.
  /// Also triggers bounce & bottom bar if a new item is added.
  void setQuantity(Product product, int newQuantity, {int variantIndex = 0}) {
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (_sameProductVariant(e, product, variantIndex)) {
        if (newQuantity <= 0) {
          _entries.removeAt(i);
          // If cart becomes empty, hide bottom bar
          if (_entries.isEmpty) {
            _showBottomBar = false;
          }
        } else {
          _entries[i] = CartEntry(
            product: e.product,
            quantity: newQuantity,
            variantIndex: e.variantIndex,
          );
        }
        notifyListeners();
        return;
      }
    }
    // If not found and qty > 0, we effectively add it
    if (newQuantity > 0) {
      addWithUi(product, newQuantity, variantIndex: variantIndex);
    }
  }

  bool _sameProductVariant(CartEntry e, Product p, int v) {
    return identical(e.product, p) ||
        (e.product.name == p.name && e.variantIndex == v);
  }

  void _setLastAddedAndNotify(Product product) {
    _lastAddedProduct = product;
    notifyListeners();
  }

  void updateCustomerDetails({
    required String name,
    required String phone,
    required String address,
    String? gpsCoords,
  }) {
    _customerName = name.trim();
    _customerPhone = phone.trim();
    _customerAddress = address.trim();
    if (gpsCoords != null) _customerGpsCoords = gpsCoords;
    notifyListeners();
  }

  /// Stores raw GPS coordinates "lat, lng" for use in Firebase `adrs` field.
  void setGpsCoords(String coords) {
    _customerGpsCoords = coords;
    // No notify needed — this is a background data field.
  }

  /// Clears saved customer details so the bar shows "Add your details" again.
  void clearCustomerDetails() {
    _customerName = null;
    _customerPhone = null;
    _customerAddress = null;
    _customerGpsCoords = null;
    notifyListeners();
  }

  void updateDeliveryInstruction(String instruction) {
    _deliveryInstruction = instruction;
    // No notifyListeners – handled locally by the text field widget.
  }

  void removeAt(int index) {
    if (index >= 0 && index < _entries.length) {
      _entries.removeAt(index);
      notifyListeners();
    }
  }

  void updateQuantityAt(int index, int newQuantity) {
    if (index >= 0 && index < _entries.length && newQuantity >= 0) {
      final e = _entries[index];
      if (newQuantity == 0) {
        _entries.removeAt(index);
      } else {
        _entries[index] = CartEntry(
          product: e.product,
          quantity: newQuantity,
          variantIndex: e.variantIndex,
        );
      }
      notifyListeners();
    }
  }

  void setLastAdded(Product? product) {
    _lastAddedProduct = product;
    notifyListeners();
  }

  void showAddedBar() {
    _showBottomBar = true;
    notifyListeners();
  }

  void hideBottomBar() {
    _showBottomBar = false;
    notifyListeners();
  }

  void triggerBounce() {
    _bounceTrigger++;
    notifyListeners();
  }

  /// Call when a new order has been successfully placed.
  /// [orderId] is stored so the floating "Track Order" card can open it.
  void registerNewOrder({required String orderId}) {
    _latestActiveOrderId = orderId;
    _activeOrderCount++;
    notifyListeners();
  }

  /// Call when an order is no longer active (delivered / cancelled / dismissed).
  void completeAnOrder() {
    if (_activeOrderCount <= 0) return;
    _activeOrderCount--;
    if (_activeOrderCount == 0) _latestActiveOrderId = null;
    notifyListeners();
  }

  /// Clears all cart items and hides any dependent bottom bars.
  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    _lastAddedProduct = null;
    _showBottomBar = false;
    notifyListeners();
  }

  /// Saves the current cart items for later and clears the active cart.
  void saveForLater() {
    if (_entries.isEmpty) return;
    _savedItems = List.from(_entries);
    clear();
  }

  /// Restores the previously saved cart items into the active cart.
  void restoreSavedOrder() {
    if (_savedItems.isEmpty) return;
    for (final e in _savedItems) {
      add(e.product, e.quantity, variantIndex: e.variantIndex);
    }
    _savedItems.clear();
    // note: add() already calls notifyListeners, but just to be sure
    notifyListeners();
  }
}
