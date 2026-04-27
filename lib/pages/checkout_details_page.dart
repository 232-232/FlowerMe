import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../cart_scope.dart';
import '../location_service.dart';
import '../providers/delivery_location_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/delivery_fee_service.dart';
import '../widgets/address_book_sheet.dart';

class CheckoutDetailsPage extends StatefulWidget {
  const CheckoutDetailsPage({super.key, this.showProceedToPayment = true});

  /// When true (opened via "Proceed to Checkout"), show Proceed to Payment.
  /// When false (opened via "Add your details"), show Save only.
  final bool showProceedToPayment;

  static Route<Map<String, String>?> route({bool showProceedToPayment = true}) {
    return PageRouteBuilder<Map<String, String>?>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) =>
          CheckoutDetailsPage(showProceedToPayment: showProceedToPayment),
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          // Matches the HTML cubic-bezier(0.16, 1, 0.3, 1) – springy slide-up
          curve: const Cubic(0.16, 1, 0.3, 1),
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Show the checkout details UI inside an [AlertDialog] instead of
  /// pushing a full-screen page route.
  static Future<Map<String, String>?> showAsDialog(
    BuildContext context, {
    bool showProceedToPayment = true,
  }) {
    return showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 430,
            child: CheckoutDetailsPage(
              showProceedToPayment: showProceedToPayment,
            ),
          ),
        );
      },
    );
  }

  @override
  State<CheckoutDetailsPage> createState() => _CheckoutDetailsPageState();
}

class _CheckoutDetailsPageState extends State<CheckoutDetailsPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _showValidationMessage = false;
  bool _isFetchingLocation = false;
  int _locationFetchAttempts = 0;
  /// Raw GPS coordinates "lat, lng" — set when user picks location via GPS.
  String? _gpsCoords;

  /// Delivery info calculated after a GPS location is confirmed.
  DeliveryInfo? _deliveryInfo;
  bool _isCalculatingDelivery = false;

  /// The address ID currently selected for delivery (null = use default).
  String? _selectedAddressId;

  late final AnimationController _shineCtrl;

  // Track keyboard visibility to unfocus when keyboard is dismissed via system
  // back/down arrow (which doesn't use Navigator.pop)
  double _lastKeyboardHeight = 0;

  String get _trimmedPhone => _phoneController.text.trim();

  bool get _canProceed {
    final nameOk = _nameController.text.trim().isNotEmpty;
    final phoneOk = _trimmedPhone.length == 10;
    if (!widget.showProceedToPayment) return nameOk && phoneOk;
    return nameOk && phoneOk && _addressController.text.trim().isNotEmpty;
  }

  String get _validationMessage {
    if (_nameController.text.trim().isEmpty) return 'Please enter your name';
    if (_trimmedPhone.length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }
    if (widget.showProceedToPayment &&
        _addressController.text.trim().isEmpty) {
      return 'Please add your delivery address';
    }
    return 'Please fill all required details';
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleTextChanged);
    _phoneController.addListener(_handleTextChanged);
    _addressController.addListener(_handleTextChanged);

    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Play the button shine once after the sheet finishes sliding up
    Future.delayed(const Duration(milliseconds: 580), () {
      if (mounted) _shineCtrl.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cart = CartScope.maybeOf(context);
      final profile = context.read<UserProfileProvider>();

      if (cart != null && cart.hasCustomerDetails) {
        _nameController.text = cart.customerName ?? '';
        _phoneController.text = cart.customerPhone ?? '';
        _addressController.text = cart.customerAddress ?? '';
      } else {
        if (profile.name.isNotEmpty && profile.name != 'Guest') {
          _nameController.text = profile.name;
        }
        if (profile.phone.isNotEmpty) {
          _phoneController.text = profile.phone;
        }
        // Pre-fill from the default saved address
        final defAddr = profile.defaultAddress;
        if (defAddr != null) {
          _selectedAddressId = defAddr.id;
          _addressController.text = defAddr.fullAddress;
          if (defAddr.gpsCoords != null) _gpsCoords = defAddr.gpsCoords;
        } else if (profile.address.isNotEmpty) {
          _addressController.text = profile.address;
        }
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    // Detect dismissal (potential down arrow click)
    if (_lastKeyboardHeight > 100 && keyboardHeight < 10) {
      FocusScope.of(context).unfocus();
    }
    
    _lastKeyboardHeight = keyboardHeight;
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleTextChanged);
    _phoneController.removeListener(_handleTextChanged);
    _addressController.removeListener(_handleTextChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _shineCtrl.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (!mounted) return;
    setState(() {
      if (_canProceed) _showValidationMessage = false;
    });
  }

  Future<void> _handleGetCurrentLocation() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    try {
      final result = await LocationService.getCurrentLocation(context);
      if (!mounted) return;
      if (result != null) {
        _addressController.text = result.formattedAddress;
        final coords =
            '${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}';
        _gpsCoords = coords;
        _selectedAddressId = null; // GPS result is a fresh address
        // Sync to cart so PaymentOptionsPage can read it.
        CartScope.maybeOf(context)?.setGpsCoords(coords);
        // Sync to the shared provider so ItemsPage header reacts.
        context
            .read<DeliveryLocationProvider>()
            .update(result.formattedAddress);
        if (mounted) setState(() {});
        // Calculate delivery fee from store to user's picked location.
        _computeDeliveryInfo(result.latitude, result.longitude);
      } else {
        _locationFetchAttempts++;
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _computeDeliveryInfo(double lat, double lng) async {
    if (!mounted) return;
    setState(() {
      _isCalculatingDelivery = true;
      _deliveryInfo = null;
    });
    try {
      final info = await DeliveryFeeService.calculate(
        userLat: lat,
        userLng: lng,
      );
      if (mounted) setState(() => _deliveryInfo = info);
    } catch (_) {
      // Silently ignore — delivery fee will be unavailable.
    } finally {
      if (mounted) setState(() => _isCalculatingDelivery = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_canProceed) {
      setState(() => _showValidationMessage = true);
      return;
    }
    final name    = _nameController.text.trim();
    final phone   = _phoneController.text.trim();
    final address = _addressController.text.trim();
    if (mounted) {
      await context.read<UserProfileProvider>().saveCheckoutDetails(
            name: name,
            phone: phone,
            address: address,
            gpsCoords: _gpsCoords,
            label: _selectedAddressId != null ? 
              (context.read<UserProfileProvider>().addresses
                .where((a) => a.id == _selectedAddressId)
                .firstOrNull?.label ?? 'home') 
              : 'home',
          );
    }
    if (mounted) {
      Navigator.of(context).pop(<String, String>{
        'name': name,
        'phone': phone,
        'address': address,
        if (_gpsCoords != null) 'gpsCoords': _gpsCoords!,
      });
    }
  }

  Future<void> _handleProceed() async {
    if (!_canProceed) {
      setState(() => _showValidationMessage = true);
      return;
    }
    final name    = _nameController.text.trim();
    final phone   = _phoneController.text.trim();
    final address = _addressController.text.trim();
    if (mounted) {
      await context.read<UserProfileProvider>().saveCheckoutDetails(
            name: name,
            phone: phone,
            address: address,
            gpsCoords: _gpsCoords,
            label: _selectedAddressId != null ?
              (context.read<UserProfileProvider>().addresses
                .where((a) => a.id == _selectedAddressId)
                .firstOrNull?.label ?? 'home')
              : 'home',
          );
    }
    if (mounted) {
      Navigator.of(context).pop(<String, String>{
        'name': name,
        'phone': phone,
        'address': address,
        if (_gpsCoords != null) 'gpsCoords': _gpsCoords!,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneVerified = _trimmedPhone.length == 10;
    final keyboardBottom =
        MediaQuery.of(context).viewInsets.bottom.clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Dismiss keyboard if visible, otherwise pop the route
          final hasFocus = FocusScope.of(context).hasFocus;
          if (hasFocus) {
            FocusScope.of(context).unfocus();
          } else {
            Navigator.of(context).maybePop();
          }
        },
        child: Stack(
          children: [
            // ── Dark blurred overlay ─────────────────────────────────
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: const Color(0x990F172A)),
              ),
            ),

            // ── Bottom sheet ─────────────────────────────────────────
            // ── Bottom sheet ─────────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(
                bottom: keyboardBottom,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(40),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 40,
                            offset: Offset(0, -20),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Scrollable form area ─
                          Flexible(
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  24, 12, 24, 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Drag handle
                                  Center(
                                    child: Container(
                                      width: 48,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius:
                                            BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Header
                                  Row(
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22C55E),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF22C55E)
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons
                                              .shopping_cart_checkout_rounded,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Checkout Details',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight:
                                                    FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                                height: 1.1,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'ALMOST THERE!',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: Color(0xFF94A3B8),
                                                letterSpacing: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          Navigator.of(context)
                                              .maybePop();
                                        },
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color:
                                                const Color(0xFFF8FAFC),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(
                                                  0xFFF1F5F9),
                                            ),
                                          ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 20,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Name field
                                _GlowField(
                                  controller: _nameController,
                                  hintText: 'Your name',
                                  icon: Icons.person_outline_rounded,
                                  textInputAction:
                                      TextInputAction.next,
                                ),
                                const SizedBox(height: 12),

                                // Phone field
                                _GlowField(
                                  controller: _phoneController,
                                  hintText: 'Your phone number',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  textInputAction:
                                      TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter
                                        .digitsOnly,
                                    LengthLimitingTextInputFormatter(
                                        10),
                                  ],
                                  trailingWidget: phoneVerified
                                      ? Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                                0xFFDCFCE7),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    6),
                                          ),
                                          child: const Text(
                                            'VERIFIED',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight:
                                                  FontWeight.w800,
                                              color:
                                                  Color(0xFF16A34A),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),

                                // ── Address section ──────────────────────────
                                Consumer<UserProfileProvider>(
                                  builder: (context, profile, _) {
                                    final hasSaved = profile.addresses.isNotEmpty;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Saved address chips row
                                        if (hasSaved) ...[
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Deliver to',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          AddressSelector(
                                            selectedId: _selectedAddressId,
                                            onSelected: (addr) {
                                              setState(() {
                                                _selectedAddressId = addr.id;
                                                _addressController.text =
                                                    addr.fullAddress;
                                                _gpsCoords = addr.gpsCoords;
                                              });
                                            },
                                          ),
                                        ],

                                        // Selected address preview
                                        if (_addressController.text
                                            .trim()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 220),
                                            width: double.infinity,
                                            padding: const EdgeInsets
                                                .symmetric(
                                              horizontal: 14,
                                              vertical: 11,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0FDF4),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(0xFFBBF7D0),
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.location_on_rounded,
                                                  size: 15,
                                                  color: Color(0xFF22C55E),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _addressController.text
                                                        .trim(),
                                                    style: const TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          Color(0xFF166534),
                                                      height: 1.4,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _addressController
                                                          .clear();
                                                      _gpsCoords = null;
                                                    });
                                                  },
                                                  child: const Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 8),
                                                    child: Icon(
                                                      Icons.close_rounded,
                                                      size: 14,
                                                      color:
                                                          Color(0xFF94A3B8),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        // Manual entry (shown after 2 failed GPS attempts)
                                        if (_locationFetchAttempts >= 2) ...[
                                          const SizedBox(height: 10),
                                          _GlowField(
                                            controller: _addressController,
                                            hintText:
                                                'Enter your delivery address manually',
                                            icon: Icons.location_on_outlined,
                                            textInputAction:
                                                TextInputAction.done,
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Get Current Location
                                _LocationButton(
                                  onTap: _handleGetCurrentLocation,
                                  isLoading: _isFetchingLocation,
                                ),

                                // -- Delivery Info Card ----------
                                if (_isCalculatingDelivery ||
                                    _deliveryInfo != null) ...[
                                  const SizedBox(height: 10),
                                  _DeliveryInfoCard(
                                    info: _deliveryInfo,
                                    isLoading: _isCalculatingDelivery,
                                  ),
                                ],
                                const SizedBox(height: 0),
                              ],
                            ),
                          ),
                        ),

                        // Footer text (validation + terms)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              24, 8, 24, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Validation message
                              if (_showValidationMessage) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 14,
                                      color: Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _validationMessage,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 12),

                              // Terms text
                              const Center(
                                child: Text(
                                  'By proceeding, you agree to our Terms & Conditions',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Floating Proceed / Save button below everything
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            0,
                            24,
                            keyboardBottom > 0 ? 16 : (MediaQuery.of(context).padding.bottom + 16),
                          ),
                          child: _ProceedButton(
                            label: widget.showProceedToPayment
                                ? 'Proceed to Payment'
                                : 'Save Details',
                            onTap: widget.showProceedToPayment
                                ? _handleProceed
                                : _handleSave,
                            shineCtrl: _shineCtrl,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLOW INPUT FIELD  (animates border + shadow on focus)
// ─────────────────────────────────────────────────────────────────────────────

class _GlowField extends StatefulWidget {
  const _GlowField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.trailingWidget,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? trailingWidget;

  @override
  State<_GlowField> createState() => _GlowFieldState();
}

class _GlowFieldState extends State<_GlowField> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              _isFocused ? const Color(0xFF22C55E) : const Color(0xFFF1F5F9),
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              widget.icon,
              key: ValueKey(_isFocused),
              size: 20,
              color: _isFocused
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              inputFormatters: widget.inputFormatters,
              cursorColor: const Color(0xFF22C55E),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.trailingWidget != null) widget.trailingWidget!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTLINED LOCATION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _LocationButton extends StatelessWidget {
  const _LocationButton({required this.onTap, required this.isLoading});

  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap();
            },
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF22C55E), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF22C55E),
                  ),
                ),
              )
            else
              const Icon(
                Icons.my_location_rounded,
                size: 20,
                color: Color(0xFF22C55E),
              ),
            const SizedBox(width: 10),
            const Text(
              'Get Current Location',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF22C55E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DARK PROCEED BUTTON  (one-shot shine sweep on first appear)
// ─────────────────────────────────────────────────────────────────────────────

class _ProceedButton extends StatelessWidget {
  const _ProceedButton({
    required this.label,
    required this.onTap,
    required this.shineCtrl,
  });

  final String label;
  final VoidCallback onTap;
  final AnimationController shineCtrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AnimatedBuilder(
            animation: shineCtrl,
            builder: (context, child) {
              // We intentionally render only the base button without
              // any white shine overlay, so nothing can visually cover
              // the top edge of the button.
              return child!;
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: Color(0xFF22C55E),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY INFO CARD  (shown after location is confirmed)
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryInfoCard extends StatelessWidget {
  const _DeliveryInfoCard({
    required this.info,
    required this.isLoading,
  });

  final DeliveryInfo? info;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildShell(
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFFF5200), // Swiggy Orange
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Analyzing delivery route…',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }

    final d = info;
    if (d == null) return const SizedBox.shrink();

    // Use a unique key for the whole card to trigger entry animations
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: _SwiggyStyleDeliveryCard(info: d, key: ValueKey(d.distanceKm)),
    );
  }

  Widget _buildShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SWIGGY STYLE DELIVERY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SwiggyStyleDeliveryCard extends StatelessWidget {
  const _SwiggyStyleDeliveryCard({super.key, required this.info});

  final DeliveryInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5200).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon Cluster
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Icon(
                    Icons.delivery_dining_rounded,
                    color: Color(0xFFFF5200),
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Time & Distance Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SmoothMovingText(
                          text: info.etaLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _SmoothMovingText(
                          text: info.distanceLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'ESTIMATED DELIVERY TIME',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              // Fee Badge
              _FeeBadge(info: info),
            ],
          ),
          if (!info.isFreeDelivery) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_rounded, size: 14, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Poppins',
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                            ),
                            children: [
                              const TextSpan(text: 'First '),
                              const TextSpan(
                                text: '5 km is FREE',
                                style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w800),
                              ),
                              TextSpan(
                                text: '. Extra ₹10/km for remaining ${(info.distanceKm - 5).ceil()} km.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeeBadge extends StatelessWidget {
  const _FeeBadge({required this.info});
  final DeliveryInfo info;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: info.isFreeDelivery
          ? Container(
              key: const ValueKey('free'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'FREE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          : Container(
              key: const ValueKey('paid'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '₹${info.deliveryFee.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

class _SmoothMovingText extends StatelessWidget {
  const _SmoothMovingText({required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
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


class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          _SmoothMovingText(
            text: label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
