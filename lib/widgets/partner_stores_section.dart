import 'package:flutter/material.dart';

class PartnerStoresSection extends StatefulWidget {
  const PartnerStoresSection({super.key});

  @override
  State<PartnerStoresSection> createState() => _PartnerStoresSectionState();
}

class _PartnerStoresSectionState extends State<PartnerStoresSection> {
  int? _openIndex;

  void _toggleStore(int index) {
    setState(() {
      if (_openIndex == index) {
        _openIndex = null;
      } else {
        _openIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Partner Stores',
                style: TextStyle(
                  fontFamily: "PlusJakartaSans",
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '3 Stores',
                  style: TextStyle(
                    fontFamily: "PlusJakartaSans",
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D8A4E),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          itemCount: _storesData.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            return _StoreCard(
              index: index,
              store: _storesData[index],
              isOpen: _openIndex == index,
              onToggle: () => _toggleStore(index),
            );
          },
        ),
      ],
    );
  }
}

class _StoreCard extends StatefulWidget {
  final int index;
  final _Store store;
  final bool isOpen;
  final VoidCallback onToggle;

  const _StoreCard({
    required this.index,
    required this.store,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  State<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<_StoreCard> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isTapped = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final delay = widget.index * 0.08;
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(delay, 1.0, curve: Curves.easeOutQuart),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_fadeAnimation);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _showToast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('✓', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              msg,
              style: const TextStyle(
                fontFamily: "PlusJakartaSans",
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: const Color(0xFF0D1B12).withValues(alpha: 0.93),
        elevation: 24,
        margin: const EdgeInsets.only(bottom: 28, left: 40, right: 40),
        duration: const Duration(milliseconds: 2300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: AnimatedScale(
          scale: _isTapped ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: widget.isOpen
                    ? const Color.fromRGBO(28, 107, 58, 0.25)
                    : const Color.fromRGBO(28, 107, 58, 0.10),
                width: 1.5,
              ),
              boxShadow: [
                if (widget.isOpen)
                  const BoxShadow(
                    color: Color.fromRGBO(28, 107, 58, 0.13),
                    blurRadius: 32,
                    offset: Offset(0, 8),
                  )
                else
                  const BoxShadow(
                    color: Color.fromRGBO(28, 107, 58, 0.08),
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    // Header
                    InkWell(
                      onTapDown: (_) => setState(() => _isTapped = true),
                      onTapUp: (_) => setState(() => _isTapped = false),
                      onTapCancel: () => setState(() => _isTapped = false),
                      onTap: widget.onToggle,
                      splashColor: const Color(
                        0xFF1C6B3A,
                      ).withValues(alpha: 0.12),
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Row(
                          children: [
                            // Avatar
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              transform: Matrix4.identity()
                                ..scale(widget.isOpen ? 1.08 : 1.0)
                                ..rotateZ(
                                  widget.isOpen ? -4 * 3.14159 / 180 : 0,
                                ),
                              transformAlignment: Alignment.center,
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: widget.store.bgGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(17),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                widget.store.emoji,
                                style: const TextStyle(fontSize: 25),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.store.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: "PlusJakartaSans",
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0D1B12),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Color(0xFFFFB830),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        widget.store.rating,
                                        style: const TextStyle(
                                          fontFamily: "PlusJakartaSans",
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFFFB830),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '(${widget.store.reviews})',
                                        style: const TextStyle(
                                          fontFamily: "PlusJakartaSans",
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF4A6357),
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5EE),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          widget.store.status,
                                          style: const TextStyle(
                                            fontFamily: "PlusJakartaSans",
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1C6B3A),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '🚚 ${widget.store.delivery}',
                                    style: const TextStyle(
                                      fontFamily: "PlusJakartaSans",
                                      fontSize: 11,
                                      color: Color(0xFF8BA898),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Chevron
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: widget.isOpen
                                    ? const Color(0xFF1C6B3A)
                                    : const Color(0xFFE8F5EE),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: AnimatedRotation(
                                turns: widget.isOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: widget.isOpen
                                      ? Colors.white
                                      : const Color(0xFF1C6B3A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Ribbon
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.store.bgGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -30,
                              right: -30,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -40,
                              right: 20,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.07),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.store.offerText,
                                        style: const TextStyle(
                                          fontFamily: "PlusJakartaSans",
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        widget.store.offerSub,
                                        style: TextStyle(
                                          fontFamily: "PlusJakartaSans",
                                          fontSize: 11,
                                          color: Colors.white.withValues(
                                            alpha: 0.82,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    widget.store.offerTag,
                                    style: const TextStyle(
                                      fontFamily: "PlusJakartaSans",
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable Body
                    AnimatedSize(
                      duration: const Duration(milliseconds: 580),
                      curve: Curves.fastOutSlowIn,
                      alignment: Alignment.topCenter,
                      child: !widget.isOpen
                          ? const SizedBox.shrink()
                          : AnimatedOpacity(
                              opacity: widget.isOpen ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 380),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(18, 4, 18, 10),
                                    child: Text(
                                      '🛒 FRESH GROCERIES',
                                      style: TextStyle(
                                        fontFamily: "PlusJakartaSans",
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF4A6357),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 120,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      scrollDirection: Axis.horizontal,
                                      itemCount: widget.store.groceries.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 10),
                                      itemBuilder: (context, i) {
                                        final g = widget.store.groceries[i];
                                        return _GroceryItem(
                                          grocery: g,
                                          onAdd: () => _showToast(
                                            context,
                                            '${g.n} added to cart',
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      18,
                                      16,
                                      18,
                                      10,
                                    ),
                                    child: Text(
                                      '🏷️ TODAY\'S OFFERS',
                                      style: TextStyle(
                                        fontFamily: "PlusJakartaSans",
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF4A6357),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      0,
                                      14,
                                      16,
                                    ),
                                    child: Column(
                                      children: widget.store.offers
                                          .map(
                                            (o) => _OfferItem(
                                              offer: o,
                                              onAdd: o.price != null
                                                  ? () => _showToast(
                                                      context,
                                                      '${o.name} added!',
                                                    )
                                                  : null,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroceryItem extends StatefulWidget {
  final _Grocery grocery;
  final VoidCallback onAdd;

  const _GroceryItem({required this.grocery, required this.onAdd});

  @override
  State<_GroceryItem> createState() => _GroceryItemState();
}

class _GroceryItemState extends State<_GroceryItem> {
  bool _isHovered = false;
  bool _isBtnTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) {
        setState(() => _isHovered = false);
        widget.onAdd();
      },
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 84,
        padding: const EdgeInsets.fromLTRB(7, 11, 7, 9),
        decoration: BoxDecoration(
          color: _isHovered ? Colors.white : const Color(0xFFF2F5F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? const Color(0xFF4CAF79) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            if (_isHovered)
              const BoxShadow(
                color: Color.fromRGBO(28, 107, 58, 0.13),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
          ],
        ),
        transform: _isHovered
            ? (Matrix4.identity()
                ..translate(0.0, -3.0)
                ..scale(1.04))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: Column(
          children: [
            Text(
              widget.grocery.e,
              style: const TextStyle(fontSize: 27, height: 1),
            ),
            const SizedBox(height: 4),
            Text(
              widget.grocery.n,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontFamily: "PlusJakartaSans",
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1B12),
                height: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              '₹${widget.grocery.p}/${widget.grocery.u}',
              style: const TextStyle(
                fontFamily: "PlusJakartaSans",
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D8A4E),
              ),
            ),
            const SizedBox(height: 2),
            GestureDetector(
              onTapDown: (_) => setState(() => _isBtnTapped = true),
              onTapUp: (_) {
                setState(() => _isBtnTapped = false);
                widget.onAdd();
              },
              onTapCancel: () => setState(() => _isBtnTapped = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _isBtnTapped
                      ? const Color(0xFF2D8A4E)
                      : const Color(0xFF1C6B3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                transform: _isBtnTapped
                    ? (Matrix4.identity()..scale(0.84))
                    : Matrix4.identity(),
                transformAlignment: Alignment.center,
                alignment: Alignment.center,
                child: const Text(
                  '+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1,
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

class _OfferItem extends StatefulWidget {
  final _Offer offer;
  final VoidCallback? onAdd;

  const _OfferItem({required this.offer, this.onAdd});

  @override
  State<_OfferItem> createState() => _OfferItemState();
}

class _OfferItemState extends State<_OfferItem> {
  bool _isTapped = false;
  bool _isAddTapped = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isTapped = true),
        onTapUp: (_) => setState(() => _isTapped = false),
        onTapCancel: () => setState(() => _isTapped = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: _isTapped ? Colors.white : const Color(0xFFF2F5F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isTapped
                  ? const Color.fromRGBO(28, 107, 58, 0.10)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              if (_isTapped)
                const BoxShadow(
                  color: Color.fromRGBO(28, 107, 58, 0.08),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
            ],
          ),
          transform: _isTapped
              ? (Matrix4.identity()..translate(4.0, 0.0))
              : Matrix4.identity(),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.offer.icon,
                  style: const TextStyle(fontSize: 19),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.offer.name,
                      style: const TextStyle(
                        fontFamily: "PlusJakartaSans",
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D1B12),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.offer.desc,
                      style: const TextStyle(
                        fontFamily: "PlusJakartaSans",
                        fontSize: 11,
                        color: Color(0xFF4A6357),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: widget.offer.chipBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.offer.chip,
                      style: TextStyle(
                        fontFamily: "PlusJakartaSans",
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: widget.offer.chipText,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  if (widget.offer.price != null) ...[
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTapDown: (_) => setState(() => _isAddTapped = true),
                      onTapUp: (_) {
                        setState(() => _isAddTapped = false);
                        if (widget.onAdd != null) widget.onAdd!();
                      },
                      onTapCancel: () => setState(() => _isAddTapped = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _isAddTapped
                              ? const Color(0xFF2D8A4E)
                              : const Color(0xFF1C6B3A),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        transform: _isAddTapped
                            ? (Matrix4.identity()..scale(0.88))
                            : Matrix4.identity(),
                        transformAlignment: Alignment.center,
                        child: const Text(
                          'Add',
                          style: TextStyle(
                            fontFamily: "PlusJakartaSans",
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- DATA MODELS ---

class _Grocery {
  final String n; // name
  final String e; // emoji
  final int p; // price
  final String u; // unit
  const _Grocery(this.n, this.e, this.p, this.u);
}

class _Offer {
  final String icon;
  final String name;
  final String desc;
  final String chip;
  final Color chipBg;
  final Color chipText;
  final int? price;
  const _Offer(
    this.icon,
    this.name,
    this.desc,
    this.chip,
    this.chipBg,
    this.chipText,
    this.price,
  );
}

class _Store {
  final String id;
  final String name;
  final String emoji;
  final List<Color> bgGradient;
  final String rating;
  final String reviews;
  final String status;
  final String delivery;
  final String offerText;
  final String offerSub;
  final String offerTag;
  final List<_Grocery> groceries;
  final List<_Offer> offers;

  const _Store({
    required this.id,
    required this.name,
    required this.emoji,
    required this.bgGradient,
    required this.rating,
    required this.reviews,
    required this.status,
    required this.delivery,
    required this.offerText,
    required this.offerSub,
    required this.offerTag,
    required this.groceries,
    required this.offers,
  });
}

const _storesData = [
  _Store(
    id: 'naasak',
    name: 'Naasak Supermarket',
    emoji: '🏬',
    bgGradient: [Color(0xFF1C6B3A), Color(0xFF2D8A4E)],
    rating: '4.8',
    reviews: '2.1k',
    status: 'Open',
    delivery: 'Free · 25 min',
    offerText: 'Mega Weekend Sale',
    offerSub: 'Up to 40% off all products',
    offerTag: 'SALE',
    groceries: [
      _Grocery('Tomatoes', '🍅', 32, 'kg'),
      _Grocery('Spinach', '🥬', 25, 'bunch'),
      _Grocery('Red Apples', '🍎', 180, 'kg'),
      _Grocery('Basmati Rice', '🍚', 120, 'kg'),
      _Grocery('Full Milk', '🥛', 62, 'L'),
      _Grocery('Chicken', '🍗', 280, 'kg'),
      _Grocery('Eggs', '🥚', 7, 'pc'),
      _Grocery('Wheat Bread', '🍞', 45, 'pc'),
      _Grocery('Bananas', '🍌', 60, 'doz'),
      _Grocery('Oranges', '🍊', 90, 'kg'),
    ],
    offers: [
      _Offer(
        '🛒',
        'Buy 2 Get 1 Free',
        'All Aashirvaad products',
        'B2G1',
        Color(0xFFE8F5EE),
        Color(0xFF1C6B3A),
        null,
      ),
      _Offer(
        '🥗',
        'Fresh Salad Bundle',
        'Tomato + Cucumber + Onion',
        '₹89',
        Color(0xFFFFF3E0),
        Color(0xFFE65100),
        89,
      ),
      _Offer(
        '🎁',
        'Weekend Combo Pack',
        'Rice 5kg + Dal 1kg + Oil 1L',
        '15% OFF',
        Color(0xFFE8F5EE),
        Color(0xFF1C6B3A),
        null,
      ),
      _Offer(
        '🚚',
        'Free Delivery',
        'On all orders above ₹499',
        'FREE',
        Color(0xFFE3F2FD),
        Color(0xFF1565C0),
        null,
      ),
    ],
  ),
  _Store(
    id: 'kumaranchira',
    name: 'Kumaranchira Stores',
    emoji: '🏪',
    bgGradient: [Color(0xFFC75B00), Color(0xFFFF6D00)],
    rating: '4.6',
    reviews: '1.4k',
    status: 'Open',
    delivery: '₹20 · 20 min',
    offerText: 'Daily Fresh Deals',
    offerSub: 'Local favourites at best prices',
    offerTag: 'LOCAL',
    groceries: [
      _Grocery('Coconut', '🥥', 55, 'pc'),
      _Grocery('Banana', '🍌', 50, 'doz'),
      _Grocery('Bitter Gourd', '🥒', 60, 'kg'),
      _Grocery('Tapioca', '🫘', 40, 'kg'),
      _Grocery('Fresh Fish', '🐟', 250, 'kg'),
      _Grocery('Coconut Oil', '🫙', 210, 'L'),
      _Grocery('Jaggery', '🟫', 90, 'kg'),
      _Grocery('Raw Mango', '🥭', 75, 'kg'),
      _Grocery('Curd', '🍶', 48, '500g'),
      _Grocery('Prawns', '🦐', 380, 'kg'),
    ],
    offers: [
      _Offer(
        '🥥',
        'Coconut Deal',
        '2 fresh coconuts for just ₹99',
        '₹99',
        Color(0xFFFFF3E0),
        Color(0xFFE65100),
        99,
      ),
      _Offer(
        '🐟',
        'Monday Fish Offer',
        '10% off all seafood items',
        '10% OFF',
        Color(0xFFE3F2FD),
        Color(0xFF1565C0),
        null,
      ),
      _Offer(
        '🎉',
        'Onam Special Pack',
        'Traditional Kerala items bundle',
        '₹349',
        Color(0xFFF3EEFF),
        Color(0xFF6B3FA0),
        349,
      ),
      _Offer(
        '⭐',
        'Loyalty Points',
        'Earn 1 point per ₹10 spent',
        'EARN',
        Color(0xFFE8F5EE),
        Color(0xFF1C6B3A),
        null,
      ),
    ],
  ),
  _Store(
    id: 'patharam',
    name: 'Patharam Stores',
    emoji: '🌿',
    bgGradient: [Color(0xFF4A1D8A), Color(0xFF7C5CBF)],
    rating: '4.9',
    reviews: '876',
    status: 'Open',
    delivery: '₹30 · 30 min',
    offerText: 'Organic Spice Fest',
    offerSub: 'Certified authentic Kerala spices',
    offerTag: 'ORGANIC',
    groceries: [
      _Grocery('Cardamom', '🌱', 1800, 'kg'),
      _Grocery('Pepper', '⚫', 700, 'kg'),
      _Grocery('Turmeric', '🟡', 160, 'kg'),
      _Grocery('Fresh Ginger', '🫚', 90, 'kg'),
      _Grocery('Garlic', '🧄', 120, 'kg'),
      _Grocery('Red Chilli', '🌶️', 240, 'kg'),
      _Grocery('Cloves', '🌰', 900, 'kg'),
      _Grocery('Organic Rice', '🌾', 95, 'kg'),
      _Grocery('Cinnamon', '🪵', 600, 'kg'),
      _Grocery('Coriander', '🌿', 80, 'kg'),
    ],
    offers: [
      _Offer(
        '🌿',
        'Spice Master Pack',
        '10 premium spices combo box',
        '₹599',
        Color(0xFFF3EEFF),
        Color(0xFF6B3FA0),
        599,
      ),
      _Offer(
        '🌾',
        'Organic Bundle',
        'Rice + Dhal + Wheat flour',
        '20% OFF',
        Color(0xFFE8F5EE),
        Color(0xFF1C6B3A),
        null,
      ),
      _Offer(
        '📦',
        'Monthly Subscription',
        'Weekly fresh spice delivery',
        'SAVE ₹200',
        Color(0xFFFFF3E0),
        Color(0xFFE65100),
        null,
      ),
      _Offer(
        '🏆',
        'Premium Kerala Grade',
        'Certified farm-to-table origin',
        'PREMIUM',
        Color(0xFFF3EEFF),
        Color(0xFF6B3FA0),
        null,
      ),
    ],
  ),
];
