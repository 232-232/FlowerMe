import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../location_provider.dart';
import '../location_service.dart';
import '../places_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────────────────────────

class MapLocationPickerPage extends StatelessWidget {
  const MapLocationPickerPage({
    super.key,
    required this.initialPosition,
    required this.initialAddress,
  });

  final LatLng initialPosition;
  final String initialAddress;

  @override
  Widget build(BuildContext context) {
    final initialResult = LocationResult(
      latitude: initialPosition.latitude,
      longitude: initialPosition.longitude,
      formattedAddress: initialAddress,
    );

    // Web: Google Maps JS API requires additional index.html setup.
    // Show a polished web fallback so the app works without that setup.
    if (kIsWeb) {
      return _WebFallbackPage(initialResult: initialResult);
    }

    return ChangeNotifierProvider<LocationProvider>(
      create: (_) => LocationProvider(initialResult: initialResult),
      child: _MapPickerBody(initialPosition: initialPosition),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Native map body
// ─────────────────────────────────────────────────────────────────────────────

class _MapPickerBody extends StatefulWidget {
  const _MapPickerBody({required this.initialPosition});
  final LatLng initialPosition;

  @override
  State<_MapPickerBody> createState() => _MapPickerBodyState();
}

class _MapPickerBodyState extends State<_MapPickerBody> {
  GoogleMapController? _mapController;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late LocationProvider _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<LocationProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSuggestionSelected(PlaceSuggestion suggestion) {
    final ctrl = _mapController;
    if (ctrl == null) return;
    _provider.selectSuggestion(suggestion, ctrl, context);
  }

  void _onCurrentLocationPressed() {
    final ctrl = _mapController;
    if (ctrl == null) return;
    _provider.fetchCurrentLocation(context, ctrl);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_searchCtrl.text.isNotEmpty) {
          _searchCtrl.clear();
          _provider.clearSuggestions();
          _searchFocus.unfocus();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // ── 1. Full-screen Google Map ──────────────────────────────────
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.initialPosition,
                zoom: 16,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              onMapCreated: (c) => _mapController = c,
              onCameraMoveStarted: _provider.onCameraMoveStarted,
              onCameraMove: (pos) => _provider.onCameraMove(pos.target),
              onCameraIdle: () => _provider.onCameraIdle(context),
              onTap: (_) => FocusScope.of(context).unfocus(),
              markers: const {},
            ),

            // ── 2. Fixed animated center pin ───────────────────────────────
            const Center(
              child: IgnorePointer(child: _CenterPin()),
            ),

            // ── 3. Floating search bar + suggestions dropdown ──────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _SearchArea(
                searchCtrl: _searchCtrl,
                searchFocus: _searchFocus,
                onSuggestionSelected: _onSuggestionSelected,
              ),
            ),

            // ── 4. GPS button + bottom confirmation card ───────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: Consumer<LocationProvider>(
                builder: (ctx, prov, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 16, bottom: 12),
                        child: _CurrentLocationButton(
                          isLoading: prov.isFetchingLocation,
                          onPressed: _onCurrentLocationPressed,
                        ),
                      ),
                    ),
                    _BottomCard(provider: prov),
                  ],
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
//  Floating search bar + autocomplete dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _SearchArea extends StatefulWidget {
  const _SearchArea({
    required this.searchCtrl,
    required this.searchFocus,
    required this.onSuggestionSelected,
  });

  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final void Function(PlaceSuggestion suggestion) onSuggestionSelected;

  @override
  State<_SearchArea> createState() => _SearchAreaState();
}

class _SearchAreaState extends State<_SearchArea> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.searchCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.searchCtrl.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Search bar pill ──────────────────────────────────────────────
        Container(
          margin: EdgeInsets.fromLTRB(14, topPad + 10, 14, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left icon: back arrow (closes page or clears search)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_hasText) {
                    widget.searchCtrl.clear();
                    context.read<LocationProvider>().clearSuggestions();
                    widget.searchFocus.unfocus();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                child: const SizedBox(
                  width: 50,
                  height: 54,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: Color(0xFF424242),
                  ),
                ),
              ),
              // Vertical divider
              Container(
                width: 1,
                height: 22,
                color: const Color(0xFFE0E0E0),
              ),
              // Text field
              Expanded(
                child: TextField(
                  controller: widget.searchCtrl,
                  focusNode: widget.searchFocus,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search for a location...',
                    hintStyle: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 17,
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    context.read<LocationProvider>().onSearchChanged(value);
                  },
                ),
              ),
              // Right icon: clear when text present, search icon when empty
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _hasText
                    ? GestureDetector(
                        key: const ValueKey('clear'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          widget.searchCtrl.clear();
                          context
                              .read<LocationProvider>()
                              .clearSuggestions();
                          widget.searchFocus.unfocus();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFF757575),
                          ),
                        ),
                      )
                    : const Padding(
                        key: ValueKey('search'),
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(
                          Icons.search_rounded,
                          size: 22,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
              ),
            ],
          ),
        ),

        // ── Suggestions dropdown ─────────────────────────────────────────
        Consumer<LocationProvider>(
          builder: (ctx, prov, _) {
            final suggestions = prov.suggestions;
            final isLoading = prov.isLoadingSuggestions;

            if (!_hasText) return const SizedBox.shrink();
            if (!isLoading && suggestions.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: isLoading && suggestions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF43A047),
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const BouncingScrollPhysics(),
                          itemCount: suggestions.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            indent: 58,
                            endIndent: 16,
                            color: Color(0xFFF0F0F0),
                          ),
                          itemBuilder: (ctx, i) => _SuggestionItem(
                            suggestion: suggestions[i],
                            onTap: () {
                              widget.searchCtrl.clear();
                              widget.searchFocus.unfocus();
                              widget.onSuggestionSelected(suggestions[i]);
                            },
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Individual suggestion row
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionItem extends StatelessWidget {
  const _SuggestionItem({
    required this.suggestion,
    required this.onTap,
  });

  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFFE8F5E9),
        highlightColor: const Color(0xFFF1F8F1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF43A047),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.mainText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        height: 1.3,
                      ),
                    ),
                    if (suggestion.secondaryText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        suggestion.secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Animated center pin
// ─────────────────────────────────────────────────────────────────────────────

class _CenterPin extends StatefulWidget {
  const _CenterPin();

  @override
  State<_CenterPin> createState() => _CenterPinState();
}

class _CenterPinState extends State<_CenterPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _lift;
  late final Animation<double> _shadowScale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _lift = Tween<double>(begin: 0, end: -18).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _shadowScale = Tween<double>(begin: 1.0, end: 0.45).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<LocationProvider, bool>(
      selector: (_, p) => p.isMapMoving,
      builder: (_, isMoving, _) {
        if (isMoving) {
          _ctrl.animateTo(
            1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
          );
        } else {
          _ctrl.animateTo(
            0.0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
          );
        }
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, _lift.value),
                child: const _PinIcon(),
              ),
              Transform.scale(
                scale: _shadowScale.value,
                child: Container(
                  width: 16,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(64),
                    borderRadius: BorderRadius.circular(8),
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

class _PinIcon extends StatelessWidget {
  const _PinIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF43A047).withAlpha(51),
            shape: BoxShape.circle,
          ),
        ),
        const Icon(
          Icons.location_on_rounded,
          size: 54,
          color: Color(0xFF388E3C),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Floating GPS / current location button
// ─────────────────────────────────────────────────────────────────────────────

class _CurrentLocationButton extends StatelessWidget {
  const _CurrentLocationButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.white,
      shadowColor: Colors.black.withAlpha(40),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : onPressed,
        splashColor: const Color(0xFFE8F5E9),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF43A047),
                      ),
                    )
                  : const Icon(
                      key: ValueKey('gps'),
                      Icons.gps_fixed_rounded,
                      color: Color(0xFF43A047),
                      size: 24,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom confirmation card
// ─────────────────────────────────────────────────────────────────────────────

class _BottomCard extends StatefulWidget {
  const _BottomCard({required this.provider});
  final LocationProvider provider;

  @override
  State<_BottomCard> createState() => _BottomCardState();
}

class _BottomCardState extends State<_BottomCard> {
  bool _pressed = false;

  LocationProvider get _p => widget.provider;

  bool get _canConfirm =>
      !_p.isFetchingAddress &&
      _p.errorMessage == null &&
      _p.selectedAddress.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(31),
                blurRadius: 28,
                spreadRadius: 0,
                offset: const Offset(0, -6),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AddressRow(provider: _p),
              const SizedBox(height: 20),
              _ConfirmButton(
                canConfirm: _canConfirm,
                isFetching: _p.isFetchingAddress,
                isPressed: _pressed,
                onTapDown: () => setState(() => _pressed = true),
                onTapUp: () {
                  setState(() => _pressed = false);
                  if (_canConfirm) {
                    Navigator.of(context)
                        .pop<LocationResult>(_p.currentResult);
                  }
                },
                onTapCancel: () => setState(() => _pressed = false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.provider});
  final LocationProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.place_rounded,
            color: Color(0xFF43A047),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DELIVER TO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9E9E9E),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              _addressContent(provider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _addressContent(LocationProvider p) {
    if (p.isFetchingAddress) return const _LoadingAddress();
    if (p.errorMessage != null) {
      return Text(
        p.errorMessage!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.redAccent,
          height: 1.4,
        ),
      );
    }
    return Text(
      p.selectedAddress,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
        height: 1.4,
      ),
    );
  }
}

class _LoadingAddress extends StatelessWidget {
  const _LoadingAddress();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFF43A047)),
          ),
        ),
        SizedBox(width: 8),
        Text(
          'Finding address...',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF757575),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.canConfirm,
    required this.isFetching,
    required this.isPressed,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  final bool canConfirm;
  final bool isFetching;
  final bool isPressed;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapCancel,
      child: AnimatedScale(
        scale: isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: canConfirm
                ? const LinearGradient(
                    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: canConfirm ? null : const Color(0xFFEEEEEE),
            boxShadow: canConfirm
                ? [
                    BoxShadow(
                      color: const Color(0xFF43A047).withAlpha(102),
                      blurRadius: 14,
                      spreadRadius: 0,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isFetching
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Confirm Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: canConfirm
                          ? Colors.white
                          : const Color(0xFFBDBDBD),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Web fallback (no Google Maps JS API required)
// ─────────────────────────────────────────────────────────────────────────────

class _WebFallbackPage extends StatefulWidget {
  const _WebFallbackPage({required this.initialResult});
  final LocationResult initialResult;

  @override
  State<_WebFallbackPage> createState() => _WebFallbackPageState();
}

class _WebFallbackPageState extends State<_WebFallbackPage> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F0E9),
      body: Stack(
        children: [
          // ── Map placeholder ──────────────────────────────────────────────
          Positioned.fill(child: _MapPlaceholder()),

          // ── Static center pin ────────────────────────────────────────────
          Align(
            alignment: const Alignment(0, -0.1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF43A047).withAlpha(51),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(
                      Icons.location_on_rounded,
                      size: 56,
                      color: Color(0xFF388E3C),
                    ),
                  ],
                ),
                Container(
                  width: 16,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: topPad + 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(153),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: EdgeInsets.only(top: topPad),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      margin: const EdgeInsets.only(left: 14),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(38),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withAlpha(77),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Confirm location',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withAlpha(128),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 52),
                ],
              ),
            ),
          ),

          // ── Bottom card ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(31),
                        blurRadius: 28,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.place_rounded,
                              color: Color(0xFF43A047),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DELIVER TO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9E9E9E),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.initialResult.formattedAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTapDown: (_) => setState(() => _pressed = true),
                        onTapUp: (_) {
                          setState(() => _pressed = false);
                          Navigator.of(context).pop<LocationResult>(
                            widget.initialResult,
                          );
                        },
                        onTapCancel: () =>
                            setState(() => _pressed = false),
                        child: AnimatedScale(
                          scale: _pressed ? 0.97 : 1.0,
                          duration: const Duration(milliseconds: 100),
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF66BB6A),
                                  Color(0xFF43A047),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF43A047).withAlpha(102),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Confirm Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Web map placeholder (drawn grid to evoke a map aesthetic)
// ─────────────────────────────────────────────────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapGridPainter(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDCEEDC), Color(0xFFE8F0E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withAlpha(180)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final blockPaint = Paint()
      ..color = const Color(0xFFCCDDCC).withAlpha(120)
      ..style = PaintingStyle.fill;

    const double gridSize = 60;

    for (double x = 0; x < size.width; x += gridSize) {
      for (double y = 0; y < size.height; y += gridSize) {
        canvas.drawRect(
          Rect.fromLTWH(x + 4, y + 4, gridSize - 8, gridSize - 8),
          blockPaint,
        );
      }
    }
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
