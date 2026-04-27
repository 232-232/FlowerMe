import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../location_service.dart';
import '../models/saved_address.dart';
import '../providers/delivery_location_provider.dart';
import '../providers/user_profile_provider.dart';

/// Shows the full address book bottom sheet.
Future<SavedAddress?> showAddressBookSheet(
  BuildContext context, {
  bool selectionMode = false, // true = pick an address; false = manage only
}) {
  return showModalBottomSheet<SavedAddress?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (_) => AddressBookSheet(selectionMode: selectionMode),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet root
// ─────────────────────────────────────────────────────────────────────────────

class AddressBookSheet extends StatefulWidget {
  const AddressBookSheet({super.key, this.selectionMode = false});

  /// When true the sheet returns a [SavedAddress] on tap instead of just
  /// setting it as default and staying open.
  final bool selectionMode;

  @override
  State<AddressBookSheet> createState() => _AddressBookSheetState();
}

class _AddressBookSheetState extends State<AddressBookSheet>
    with TickerProviderStateMixin {
  // Entrance animation for each address card
  late final AnimationController _listCtrl;

  // Whether we're showing the inline "add address" form
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  void _openAddForm() {
    HapticFeedback.selectionClick();
    setState(() => _showAddForm = true);
  }

  void _closeAddForm() => setState(() => _showAddForm = false);

  void _onAddressSaved() {
    _closeAddForm();
    // Re-run list entrance animation so new item slides in
    _listCtrl.reset();
    _listCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 60, 0, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──────────────────────────────────────────────────
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.place_rounded,
                      color: Color(0xFF16A34A),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.selectionMode
                              ? 'Choose Delivery Address'
                              : 'Saved Addresses',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Text(
                          'Home • Work • Others',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 24, indent: 24, endIndent: 24),

            // ── Address List ─────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Consumer<UserProfileProvider>(
                  builder: (context, profile, _) {
                    final addresses = profile.addresses;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (addresses.isEmpty && !_showAddForm)
                          _EmptyAddressHint(onAdd: _openAddForm)
                        else ...[
                          ...addresses.asMap().entries.map((entry) {
                            final i = entry.key;
                            final addr = entry.value;
                            final start =
                                (i * 0.12).clamp(0.0, 0.7);
                            final end = (start + 0.4).clamp(0.0, 1.0);
                            final fade = Tween<double>(begin: 0, end: 1)
                                .animate(CurvedAnimation(
                              parent: _listCtrl,
                              curve: Interval(start, end,
                                  curve: Curves.easeOut),
                            ));
                            final slide =
                                Tween<Offset>(
                                        begin: const Offset(0, 0.25),
                                        end: Offset.zero)
                                    .animate(CurvedAnimation(
                              parent: _listCtrl,
                              curve: Interval(start, end,
                                  curve: Curves.easeOutCubic),
                            ));
                            return FadeTransition(
                              opacity: fade,
                              child: SlideTransition(
                                position: slide,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _AddressCard(
                                    address: addr,
                                    selectionMode: widget.selectionMode,
                                    onSelect: () {
                                      HapticFeedback.lightImpact();
                                      if (widget.selectionMode) {
                                        Navigator.of(context).pop(addr);
                                      } else {
                                        profile.setDefaultAddress(addr.id);
                                      }
                                    },
                                    onDelete: () async {
                                      HapticFeedback.mediumImpact();
                                      await profile.removeAddress(addr.id);
                                      _listCtrl.reset();
                                      _listCtrl.forward();
                                    },
                                    onEdit: () {
                                      setState(() {
                                        _showAddForm = true;
                                      });
                                      // Pass the address to edit form
                                      // (handled by _showAddForm + editTarget)
                                    },
                                    editTarget: addr,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],

                        // ── Add form ─────────────────────────────────────────
                        if (_showAddForm)
                          _AddAddressForm(
                            onSaved: (_) => _onAddressSaved(),
                            onCancel: _closeAddForm,
                          ),

                        // ── Add new button ────────────────────────────────────
                        if (!_showAddForm) ...[
                          const SizedBox(height: 4),
                          _AddNewButton(onTap: _openAddForm),
                        ],

                        const SizedBox(height: 16),
                      ],
                    );
                  },
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
// Single address card
// ─────────────────────────────────────────────────────────────────────────────

class _AddressCard extends StatefulWidget {
  const _AddressCard({
    required this.address,
    required this.selectionMode,
    required this.onSelect,
    required this.onDelete,
    required this.onEdit,
    this.editTarget,
  });

  final SavedAddress address;
  final bool selectionMode;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final SavedAddress? editTarget;

  @override
  State<_AddressCard> createState() => _AddressCardState();
}

class _AddressCardState extends State<_AddressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.address.label.toLowerCase()) {
      case 'home':  return Icons.home_rounded;
      case 'work':  return Icons.work_rounded;
      default:      return Icons.location_on_rounded;
    }
  }

  Color get _iconBg {
    switch (widget.address.label.toLowerCase()) {
      case 'home':  return const Color(0xFFDCFCE7);
      case 'work':  return const Color(0xFFDDE9FF);
      default:      return const Color(0xFFFEF3C7);
    }
  }

  Color get _iconColor {
    switch (widget.address.label.toLowerCase()) {
      case 'home':  return const Color(0xFF16A34A);
      case 'work':  return const Color(0xFF3B6FE8);
      default:      return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = widget.address.isDefault;

    return ScaleTransition(
      scale: _pressScale,
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onSelect();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: isDefault
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDefault
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFE2E8F0),
              width: isDefault ? 1.5 : 1,
            ),
            boxShadow: isDefault
                ? [
                    const BoxShadow(
                      color: Color(0x1222C55E),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon, color: _iconColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.address.label[0].toUpperCase() +
                                widget.address.label.substring(1),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDefault
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          if (isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'DEFAULT',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.address.fullAddress,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: isDefault
                              ? const Color(0xFF166534)
                              : const Color(0xFF64748B),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Actions
                Column(
                  children: [
                    _ActionBtn(
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFEF4444),
                      bg: const Color(0xFFFFF1F1),
                      onTap: widget.onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add new address form (inline)
// ─────────────────────────────────────────────────────────────────────────────

class _AddAddressForm extends StatefulWidget {
  const _AddAddressForm({
    required this.onSaved,
    required this.onCancel,
    this.editAddress,
  });

  final ValueChanged<SavedAddress> onSaved;
  final VoidCallback onCancel;
  final SavedAddress? editAddress; // non-null = edit mode

  @override
  State<_AddAddressForm> createState() => _AddAddressFormState();
}

class _AddAddressFormState extends State<_AddAddressForm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  final _textCtrl = TextEditingController();
  String _selectedLabel = 'home';
  bool _isFetchingGps = false;
  String? _gpsCoords;
  bool _setAsDefault = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.editAddress != null) {
      _textCtrl.text = widget.editAddress!.fullAddress;
      _selectedLabel = widget.editAddress!.label;
      _gpsCoords = widget.editAddress!.gpsCoords;
      _setAsDefault = widget.editAddress!.isDefault;
    } else {
      // Check which labels already exist; auto-pick the first missing one
      final profile = context.read<UserProfileProvider>();
      final used = profile.addresses.map((a) => a.label.toLowerCase()).toSet();
      if (!used.contains('home')) {
        _selectedLabel = 'home';
      } else if (!used.contains('work')) {
        _selectedLabel = 'work';
      } else {
        _selectedLabel = 'other';
      }
      _setAsDefault = profile.addresses.isEmpty;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    if (_isFetchingGps) return;
    setState(() => _isFetchingGps = true);
    try {
      final result = await LocationService.getCurrentLocation(context);
      if (!mounted) return;
      if (result != null) {
        _textCtrl.text = result.formattedAddress;
        _gpsCoords =
            '${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}';
        context
            .read<DeliveryLocationProvider>()
            .update(result.formattedAddress);
      }
    } finally {
      if (mounted) setState(() => _isFetchingGps = false);
    }
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();

    final profile = context.read<UserProfileProvider>();
    final id = widget.editAddress?.id ??
        '${_selectedLabel}_${DateTime.now().millisecondsSinceEpoch}';

    final addr = SavedAddress(
      id: id,
      label: _selectedLabel,
      fullAddress: text,
      gpsCoords: _gpsCoords,
      isDefault: _setAsDefault,
    );

    if (widget.editAddress != null) {
      await profile.updateAddress(addr);
    } else {
      await profile.addAddress(addr);
    }
    widget.onSaved(addr);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Label chips ──────────────────────────────────────────────
              const Text(
                'Address type',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _LabelChip(
                    label: 'home',
                    icon: Icons.home_rounded,
                    selected: _selectedLabel == 'home',
                    onTap: () => setState(() => _selectedLabel = 'home'),
                  ),
                  const SizedBox(width: 8),
                  _LabelChip(
                    label: 'work',
                    icon: Icons.work_rounded,
                    selected: _selectedLabel == 'work',
                    onTap: () => setState(() => _selectedLabel = 'work'),
                  ),
                  const SizedBox(width: 8),
                  _LabelChip(
                    label: 'other',
                    icon: Icons.location_on_rounded,
                    selected: _selectedLabel == 'other',
                    onTap: () => setState(() => _selectedLabel = 'other'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Address text field ────────────────────────────────────────
              const Text(
                'Full address',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: _textCtrl,
                  minLines: 2,
                  maxLines: 3,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    color: Color(0xFF1E293B),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Street, area, landmark…',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFFCBD5E1),
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── GPS button ────────────────────────────────────────────────
              GestureDetector(
                onTap: _getLocation,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF22C55E),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isFetchingGps)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF22C55E),
                          ),
                        )
                      else
                        const Icon(Icons.my_location_rounded,
                            size: 16, color: Color(0xFF22C55E)),
                      const SizedBox(width: 8),
                      const Text(
                        'Use current location',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Set as default toggle ─────────────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _setAsDefault = !_setAsDefault),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _setAsDefault
                            ? const Color(0xFF22C55E)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _setAsDefault
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      child: _setAsDefault
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Set as default address',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Save / Cancel ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onCancel,
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _save,
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Save Address',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Label chip (Home / Work / Other)
// ─────────────────────────────────────────────────────────────────────────────

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDCFCE7) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? const Color(0xFF22C55E)
                : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            Text(
              label[0].toUpperCase() + label.substring(1),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state hint
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyAddressHint extends StatelessWidget {
  const _EmptyAddressHint({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_location_alt_rounded,
              size: 36,
              color: Color(0xFF22C55E),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No saved addresses yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your home, work, or any other\ndelivery address for faster checkout.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                '+ Add First Address',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
// Add new address button
// ─────────────────────────────────────────────────────────────────────────────

class _AddNewButton extends StatelessWidget {
  const _AddNewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF22C55E),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 20, color: Color(0xFF22C55E)),
            SizedBox(width: 8),
            Text(
              'Add New Address',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
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
// Compact address selector row — used inside checkout
// ─────────────────────────────────────────────────────────────────────────────

/// A horizontal row of address chips shown in checkout/payment pages.
/// Tapping one sets it; tapping "+" opens the full sheet.
class AddressSelector extends StatelessWidget {
  const AddressSelector({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.accent = const Color(0xFF22C55E),
  });

  final String? selectedId;
  final ValueChanged<SavedAddress> onSelected;
  final Color accent;

  static IconData _icon(String label) {
    switch (label.toLowerCase()) {
      case 'home': return Icons.home_rounded;
      case 'work': return Icons.work_rounded;
      default:     return Icons.location_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, profile, _) {
        final list = profile.addresses;
        if (list.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              ...list.map((addr) {
                final isSelected = (selectedId ?? profile.defaultAddress?.id) == addr.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelected(addr);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent.withValues(alpha: 0.10)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected ? accent : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _icon(addr.label),
                            size: 14,
                            color: isSelected ? accent : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            addr.label[0].toUpperCase() + addr.label.substring(1),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? accent
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Manage button
              GestureDetector(
                onTap: () async {
                  final picked = await showAddressBookSheet(
                    context,
                    selectionMode: true,
                  );
                  if (picked != null) onSelected(picked);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
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
