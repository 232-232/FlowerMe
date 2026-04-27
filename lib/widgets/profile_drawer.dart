import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../pages/about_page.dart';
import '../pages/customer_care_page.dart';
import '../pages/favorites_page.dart';
import '../pages/order_history_page.dart';
import '../pages/suggestion_box_page.dart';
import '../pages/wallet_page.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_colors.dart';
import 'address_book_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Internal data model
// ─────────────────────────────────────────────────────────────────────────────

class _MenuItemData {
  const _MenuItemData({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
}

// ─────────────────────────────────────────────────────────────────────────────
// ProfileDrawer — root widget
// ─────────────────────────────────────────────────────────────────────────────

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _avatarScale;
  late final List<Animation<double>> _itemFade;
  late final List<Animation<Offset>> _itemSlide;

  static const int _menuItemCount = 9;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );

    _avatarScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    // 30 ms stagger per item
    _itemFade = List.generate(_menuItemCount, (i) {
      final start = (0.18 + i * 0.037).clamp(0.0, 0.9);
      final end = (start + 0.32).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _itemSlide = List.generate(_menuItemCount, (i) {
      final start = (0.18 + i * 0.037).clamp(0.0, 0.9);
      final end = (start + 0.32).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(-0.25, 0.0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeScope.themeOf(context);

    final menuItems = <_MenuItemData>[
      _MenuItemData(
        icon: Icons.receipt_long_rounded,
        title: 'Order History',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const OrderHistoryPage()),
          );
        },
      ),
      _MenuItemData(
        icon: Icons.favorite_rounded,
        title: 'Favourites',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const FavoritesPage()),
          );
        },
      ),
      _MenuItemData(
        icon: Icons.location_on_rounded,
        title: 'Saved Addresses',
        onTap: () {
          showAddressBookSheet(context);
        },
      ),
      _MenuItemData(
        icon: Icons.headset_mic_rounded,
        title: 'Customer Care',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CustomerCarePage()),
          );
        },
      ),
      _MenuItemData(
        icon: Icons.lightbulb_rounded,
        title: 'Suggestion Box',
        onTap: () {
          final profile = context.read<UserProfileProvider>();
          final hasName = profile.name.trim().isNotEmpty;
          final hasPhone = profile.phone.trim().length >= 10;
          if (!hasName || !hasPhone) {
            _showProfileRequiredDialog(context);
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SuggestionBoxPage()),
          );
        },
      ),
      _MenuItemData(
        icon: Icons.info_outline_rounded,
        title: 'About',
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const AboutPage()));
        },
      ),
      // _MenuItemData(
      //   icon: Icons.settings_rounded,
      //   title: 'Settings',
      //   onTap: () => Navigator.pop(context),
      // ),
      // _MenuItemData(
      //   icon: Icons.language_rounded,
      //   title: 'Language',
      //   onTap: () => Navigator.pop(context),
      // ),
      // _MenuItemData(
      //   icon: Icons.logout_rounded,
      //   title: 'Log Out',
      //   onTap: () async {
      //     Navigator.pop(context);
      //     await context.read<UserProfileProvider>().signOut();
      //   },
      // ),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Poppins'),
      ),
      child: Drawer(
        width: 304,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(26),
          ),
          child: Container(
            color: const Color(0xFFF6F7F9),
            child: SingleChildScrollView(
              physics: kIsWeb
                  ? const ClampingScrollPhysics()
                  : const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DrawerHeaderSection(
                    avatarScale: _avatarScale,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 14),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: CreditInfoCard(),
                  ),
                  const SizedBox(height: 10),

                  RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: menuItems.length,
                        itemBuilder: (context, i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: SlideTransition(
                              position: _itemSlide[i],
                              child: FadeTransition(
                                opacity: _itemFade[i],
                                child: DrawerMenuItem(
                                  icon: menuItems[i].icon,
                                  title: menuItems[i].title,
                                  appTheme: appTheme,
                                  onTap: menuItems[i].onTap,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                  const DrawerFooter(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileRequiredDialog(BuildContext ctx) {
    final appTheme = AppThemeScope.themeOf(ctx);
    showDialog<void>(
      context: ctx,
      builder: (_) => _ProfileEditDialog(
        appTheme: appTheme,
        hint:
            'To continue with Suggestion Box, please enter your name and phone number.',
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DrawerHeaderSection — live profile sync via Selector
// ─────────────────────────────────────────────────────────────────────────────

class DrawerHeaderSection extends StatelessWidget {
  const DrawerHeaderSection({
    super.key,
    required this.avatarScale,
    required this.appTheme,
  });

  final Animation<double> avatarScale;
  final AppThemeData appTheme;

  void _openAvatarPicker(BuildContext context) {
    context.read<UserProfileProvider>().pickAndUpdateAvatar();
  }

  void _openProfileEditDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ProfileEditDialog(appTheme: appTheme),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: appTheme.backgroundGradientColors,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cart icon — top right
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Avatar + user info — rebuilt only when profile changes
              Selector<
                UserProfileProvider,
                (String, String, Uint8List?, String)
              >(
                selector: (_, p) =>
                    (p.name, p.displayPhone, p.avatarBytes, p.address),
                builder: (context, data, _) {
                  final (name, displayPhone, avatarBytes, address) = data;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Animated avatar with tap-to-change-image
                      ScaleTransition(
                        scale: avatarScale,
                        child: GestureDetector(
                          onTap: () => _openAvatarPicker(context),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: avatarBytes != null
                                      ? Image.memory(
                                          avatarBytes,
                                          fit: BoxFit.cover,
                                          width: 66,
                                          height: 66,
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.person_rounded,
                                            size: 38,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              // Edit pencil — opens profile edit dialog
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: () => _openProfileEditDialog(context),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.edit,
                                        size: 12,
                                        color: appTheme.primaryAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // User info text — tap anywhere to edit
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openProfileEditDialog(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                name.isEmpty ? 'Member' : name,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              if (displayPhone.trim() != '+91')
                                Text(
                                  displayPhone,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white.withValues(alpha: 0.68),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        address,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Edit Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({required this.appTheme, this.hint});

  final AppThemeData appTheme;

  /// Optional hint message shown as a banner at the top of the fields section.
  final String? hint;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog>
    with TickerProviderStateMixin {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _hasAvatar = false;
  bool _isSaving = false;
  double _lastKeyboardHeight = 0;

  // — Entrance animation
  late final AnimationController _entranceCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  // — Avatar pulse animation
  late final AnimationController _avatarPulseCtrl;
  late final Animation<double> _avatarPulseAnim;

  // — Staggered field animations
  late final AnimationController _fieldsCtrl;
  late final List<Animation<double>> _fieldFade;
  late final List<Animation<Offset>> _fieldSlide;

  // — Save button press animation
  late final AnimationController _saveBtnCtrl;
  late final Animation<double> _saveBtnScale;

  // — Focus nodes for field highlight effect
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  bool _nameHasFocus = false;
  bool _phoneHasFocus = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProfileProvider>();
    _nameCtrl = TextEditingController(text: profile.name);
    _phoneCtrl = TextEditingController(text: profile.phone);
    _hasAvatar = profile.avatarBytes != null;

    // Entrance
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Avatar pulse
    _avatarPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _avatarPulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _avatarPulseCtrl, curve: Curves.easeInOut),
    );

    // Staggered fields (4 items: name, phone, photo btn, save btn)
    _fieldsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fieldFade = List.generate(4, (i) {
      final start = (0.15 + i * 0.18).clamp(0.0, 0.85);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _fieldsCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });
    _fieldSlide = List.generate(4, (i) {
      final start = (0.15 + i * 0.18).clamp(0.0, 0.85);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0.0, 0.35),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _fieldsCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    // Save button
    _saveBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _saveBtnScale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _saveBtnCtrl, curve: Curves.easeInOut));

    // Focus listeners
    _nameFocus.addListener(() {
      if (mounted) setState(() => _nameHasFocus = _nameFocus.hasFocus);
    });
    _phoneFocus.addListener(() {
      if (mounted) setState(() => _phoneHasFocus = _phoneFocus.hasFocus);
    });

    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceCtrl.forward();
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _fieldsCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _entranceCtrl.dispose();
    _avatarPulseCtrl.dispose();
    _fieldsCtrl.dispose();
    _saveBtnCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    await _saveBtnCtrl.forward();
    await _saveBtnCtrl.reverse();
    setState(() => _isSaving = true);
    final profile = context.read<UserProfileProvider>();
    await profile.updateNameAndPhone(_nameCtrl.text, _phoneCtrl.text);
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (_lastKeyboardHeight > 100 && keyboardHeight < 10) {
      FocusScope.of(context).unfocus();
    }
    _lastKeyboardHeight = keyboardHeight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.appTheme;
    final accent = theme.primaryAccent;
    final secondary = theme.secondaryAccent;

    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (context, child) => FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(scale: _scaleAnim, child: child),
      ),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 48,
                spreadRadius: -4,
                offset: const Offset(0, 20),
              ),
              const BoxShadow(
                color: Color(0x12000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Gradient header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
                child: Column(
                  children: [
                    // Title row
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Avatar ───────────────────────────────────────────
                    Selector<UserProfileProvider, Uint8List?>(
                      selector: (_, p) => p.avatarBytes,
                      builder: (context, avatarBytes, _) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).pop();
                            context
                                .read<UserProfileProvider>()
                                .pickAndUpdateAvatar();
                          },
                          child: AnimatedBuilder(
                            animation: _avatarPulseAnim,
                            builder: (_, child) => Transform.scale(
                              scale: _avatarPulseAnim.value,
                              child: child,
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Glow ring
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: avatarBytes != null
                                        ? Image.memory(
                                            avatarBytes,
                                            fit: BoxFit.cover,
                                            width: 88,
                                            height: 88,
                                          )
                                        : Container(
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                            child: const Icon(
                                              Icons.person_rounded,
                                              size: 44,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                // Camera badge
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.15,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.camera_alt_rounded,
                                      size: 15,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to change photo',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Fields ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hint banner (shown when opened from suggestion box guard)
                    if (widget.hint != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: accent,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                widget.hint!,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: accent,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    // Name field
                    _buildAnimatedField(
                      index: 0,
                      child: _AnimatedEditField(
                        controller: _nameCtrl,
                        focusNode: _nameFocus,
                        hasFocus: _nameHasFocus,
                        hintText: 'Your name',
                        icon: Icons.person_outline_rounded,
                        accent: accent,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Phone field
                    _buildAnimatedField(
                      index: 1,
                      child: _AnimatedEditField(
                        controller: _phoneCtrl,
                        focusNode: _phoneFocus,
                        hasFocus: _phoneHasFocus,
                        hintText: 'Your phone number',
                        icon: Icons.phone_outlined,
                        accent: accent,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photo button
                    _buildAnimatedField(
                      index: 2,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop();
                          context
                              .read<UserProfileProvider>()
                              .pickAndUpdateAvatar();
                        },
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.22),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.photo_library_outlined,
                                  size: 17,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Change Profile Photo',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Remove photo (conditional)
                    if (_hasAvatar) ...[
                      const SizedBox(height: 8),
                      _buildAnimatedField(
                        index: 2,
                        child: GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await context
                                .read<UserProfileProvider>()
                                .clearAvatar();
                            if (mounted) Navigator.of(context).pop();
                          },
                          child: Container(
                            width: double.infinity,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F0),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFFCCCC),
                                width: 1.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                  color: Color(0xFFD94040),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Remove Photo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFD94040),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Save button
                    _buildAnimatedField(
                      index: 3,
                      child: ScaleTransition(
                        scale: _saveBtnScale,
                        child: GestureDetector(
                          onTap: _isSaving ? null : _save,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accent, secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: -4,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: _isSaving
                                ? const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedField({required int index, required Widget child}) {
    return FadeTransition(
      opacity: _fieldFade[index],
      child: SlideTransition(position: _fieldSlide[index], child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Edit Field with focus-driven highlight
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedEditField extends StatelessWidget {
  const _AnimatedEditField({
    required this.controller,
    required this.focusNode,
    required this.hasFocus,
    required this.hintText,
    required this.icon,
    required this.accent,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasFocus;
  final String hintText;
  final IconData icon;
  final Color accent;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: hasFocus
            ? accent.withValues(alpha: 0.05)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus ? accent : const Color(0xFFE8EAED),
          width: hasFocus ? 1.8 : 1.2,
        ),
        boxShadow: hasFocus
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
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: hasFocus
                  ? accent.withValues(alpha: 0.15)
                  : const Color(0xFFEEF0F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: hasFocus ? accent : const Color(0xFF9AA0A6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              inputFormatters: inputFormatters,
              cursorColor: accent,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
                letterSpacing: 0.1,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFBEC2C8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CreditInfoCard
// ─────────────────────────────────────────────────────────────────────────────

class CreditInfoCard extends StatefulWidget {
  const CreditInfoCard({super.key});

  @override
  State<CreditInfoCard> createState() => _CreditInfoCardState();
}

class _CreditInfoCardState extends State<CreditInfoCard> {
  bool _isLoading = false;
  bool _isPremium = false;
  double _balance = 0.0;
  String? _lastPhone;
  bool _checkingEligibility = false;
  bool _isExpanded = false;
  String? _requestStatus;

  @override
  void initState() {
    super.initState();
    _checkPremiumAndWallet();
  }

  Future<void> _checkPremiumAndWallet() async {
    final userProfileProvider = context.read<UserProfileProvider>();
    final normalizedPhone = userProfileProvider.phone.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (normalizedPhone.length < 10) {
      if (mounted) {
        setState(() {
          _isPremium = false;
          _isLoading = false;
          _checkingEligibility = false;
          _requestStatus = null;
        });
      }
      return;
    }

    if (mounted && !_checkingEligibility && !_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final last10Digits = normalizedPhone.substring(
        normalizedPhone.length - 10,
      );

      final responses = await Future.wait([
        FirebaseDatabase.instance.ref('root/walletusers/$last10Digits').get(),
        FirebaseDatabase.instance.ref('root/walletrequest/$last10Digits').get(),
      ]);

      final walletSnap = responses[0];
      final reqSnap = responses[1];

      double balance = 0.0;
      bool isEnabled = false;

      if (walletSnap.exists && walletSnap.value is Map) {
        final data = walletSnap.value as Map;
        balance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
        isEnabled = data['walletEnabled'] == true;
      }

      String? requestStatus;
      if (reqSnap.exists && reqSnap.value is Map) {
        final reqData = reqSnap.value as Map;
        requestStatus = reqData['requeststatus'] as String?;
      }

      if (mounted) {
        setState(() {
          _isPremium = isEnabled || requestStatus == 'approved';
          _balance = balance;
          _requestStatus = requestStatus;
          _isLoading = false;
          _checkingEligibility = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPremium = false;
          _requestStatus = null;
          _isLoading = false;
          _checkingEligibility = false;
        });
      }
    }
  }

  void _toggleEligibilityCriteria() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  Future<void> _requestWallet() async {
    final profile = context.read<UserProfileProvider>();
    final appTheme = AppThemeScope.themeOf(context);

    if (profile.phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => _ProfileEditDialog(
          appTheme: appTheme,
          hint: 'Please enter your phone number to proceed with your wallet request.',
        ),
      );
      // Wait for provider updates to process
      await Future.delayed(const Duration(milliseconds: 150));
      
      if (profile.phone.replaceAll(RegExp(r'\D'), '').length < 10) {
        return; // Still no valid phone number
      }
    }

    final normalizedPhone = profile.phone.replaceAll(RegExp(r'\D'), '');
    final last10Digits = normalizedPhone.substring(normalizedPhone.length - 10);
    
    setState(() => _checkingEligibility = true);
    try {
      await FirebaseDatabase.instance
          .ref('root/walletrequest/$last10Digits')
          .update({'requeststatus': 'waiting'});
      
      if (mounted) {
        setState(() {
          _requestStatus = 'waiting';
          _checkingEligibility = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingEligibility = false);
      }
    }
  }

  void _showWaitingDialog(BuildContext context, AppThemeData appTheme) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time_filled_rounded,
                    color: Color(0xFFD97706),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Application Under Review',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please wait for up to 24 hours. We are currently analyzing your profile activity and purchase history to determine your eligibility for Daily Club Credit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Once verified, your wallet will be activated automatically, and you can enjoy seamless shopping!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appTheme.primaryAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, userProfile, child) {
        final appTheme = AppThemeScope.themeOf(context);

        // Auto-refresh if phone changes
        if (userProfile.phone != _lastPhone) {
          _lastPhone = userProfile.phone;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _checkPremiumAndWallet(),
          );
        }

        return Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(
                      Tween<Offset>(
                        begin: const Offset(0.0, 0.1),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeOutCubic)),
                    ),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                key: ValueKey(_isPremium),
                onTap: () {
                  if (_isPremium && !_isLoading) {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WalletPage(),
                      ),
                    );
                  } else if (!_isPremium && !_isLoading) {
                    _toggleEligibilityCriteria();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _isPremium
                        ? appTheme.primaryAccent.withValues(alpha: 0.12)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: _isPremium
                        ? Border.all(color: appTheme.primaryAccent, width: 1.2)
                        : Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                    boxShadow: _isExpanded ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ] : [],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _isPremium
                                  ? appTheme.primaryAccent.withValues(alpha: 0.18)
                                  : appTheme.primaryAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _isPremium
                                  ? Icons.account_balance_wallet_rounded
                                  : Icons.info_rounded,
                              color: appTheme.primaryAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isLoading)
                                  const SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else if (_isPremium) ...[
                                  Text(
                                    'Available Wallet Balance',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '₹${_balance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: appTheme.primaryAccent,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ] else if (_requestStatus == 'waiting') ...[
                                  const Text(
                                    'Request Under Review',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'We are checking your profile',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: appTheme.primaryAccent,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ] else if (_requestStatus == 'rejected') ...[
                                  const Text(
                                    'Wallet Not Eligible',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Sorry, you are not eligible',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFD94040),
                                    ),
                                  ),
                                ] else ...[
                                  const Text(
                                    'Unable to use Daily Club Credit',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isExpanded ? 'Tap to close' : 'Tap to view eligibility criteria',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: appTheme.primaryAccent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_isPremium && !_isLoading)
                            Icon(
                              Icons.check_circle_rounded,
                              color: appTheme.primaryAccent,
                              size: 22,
                            ),
                          if (!_isPremium && !_isLoading)
                            AnimatedRotation(
                              turns: _isExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: appTheme.primaryAccent,
                              ),
                            ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutQuart,
                        alignment: Alignment.topCenter,
                        child: !_isExpanded
                            ? const SizedBox(height: 0, width: double.infinity)
                            : Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFEFF6FF), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Eligibility Requirements:', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155))),
                                    const SizedBox(height: 10),
                                    const _BulletText('Minimum ₹5000 monthly purchase for ≥ 2 months.'),
                                    const SizedBox(height: 6),
                                    const _BulletText('Delivery success rate ≥ 90%.'),
                                    const SizedBox(height: 6),
                                    const _BulletText('No unjustified cancelled orders.'),
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7).withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.stars_rounded, color: Color(0xFF16A34A), size: 16),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Benefit: Buy now, pay later with 0 interest!',
                                              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                                            ),
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (!_isPremium && !_isLoading) ...[
              if (_requestStatus == 'waiting') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text(
                            'Request Submitted',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 8,
                      child: ElevatedButton(
                        onPressed: () => _showWaitingDialog(context, appTheme),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appTheme.primaryAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_requestStatus == 'rejected') ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Center(
                    child: Text(
                      'Eligibility Rejected',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _checkingEligibility ? null : _requestWallet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appTheme.primaryAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _checkingEligibility
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Request for Wallet',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ],

            if (_isPremium && !_isLoading) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 17,
                    child: Material(
                      color: appTheme.primaryAccent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const WalletPage(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.sizeOf(context).width * 0.035,
                            vertical: MediaQuery.sizeOf(context).height * 0.012,
                          ),
                          child: Row(
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Activate Wallet',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 8,
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: appTheme.primaryAccent,
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (ctx) =>
                              _ProfileEditDialog(appTheme: appTheme),
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 36,
                          child: Center(
                            child: Text(
                              'Edit',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: appTheme.primaryAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DrawerMenuItem
// ─────────────────────────────────────────────────────────────────────────────

class DrawerMenuItem extends StatefulWidget {
  const DrawerMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.appTheme,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final AppThemeData appTheme;
  final VoidCallback? onTap;

  @override
  State<DrawerMenuItem> createState() => _DrawerMenuItemState();
}

class _DrawerMenuItemState extends State<DrawerMenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.965 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(14),
          splashColor: widget.appTheme.primaryAccent.withValues(alpha: 0.12),
          highlightColor: widget.appTheme.primaryAccent.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.appTheme.primaryAccent.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.appTheme.primaryAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DrawerFooter
// ─────────────────────────────────────────────────────────────────────────────

class DrawerFooter extends StatefulWidget {
  const DrawerFooter({super.key});

  @override
  State<DrawerFooter> createState() => _DrawerFooterState();
}

class _DrawerFooterState extends State<DrawerFooter> {
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = 'v${info.version}+${info.buildNumber}';
        });
      }
    } catch (_) {
      // Fallback if package info fails
      if (mounted) {
        setState(() {
          _version = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeScope.themeOf(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEBEE),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: appTheme.primaryAccent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.local_grocery_store_rounded,
                color: Colors.white,
                size: 12,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Daily Club',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555),
                  ),
                ),
                if (_version.isNotEmpty) ...[
                  const Text(
                    ' • ',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                  Text(
                    _version,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4, right: 8),
          child: Icon(Icons.circle, size: 5, color: Color(0xFF64748B)),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
