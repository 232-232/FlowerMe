import 'package:flutter/material.dart';

import '../../layout/responsive_layout.dart';
import 'item_card_product.dart';
import 'add_button.dart';

class ItemDetails extends StatefulWidget {
  const ItemDetails({
    super.key,
    required this.product,
    required this.cartCount,
    required this.disableAdd,
    required this.stockQuantity,
    required this.displayPrice,
    required this.displayOldPrice,
    required this.displayDiscount,
    required this.displayUnitLabel,
    required this.onQuantityChanged,
  });

  final ItemCardProduct product;
  final int cartCount;
  final bool disableAdd;
  final int stockQuantity;
  final double displayPrice;
  final double displayOldPrice;
  final int displayDiscount;
  final String displayUnitLabel;
  final void Function(double price, double oldPrice, int discount, int newQty) onQuantityChanged;

  @override
  State<ItemDetails> createState() => _ItemDetailsState();
}

class _ItemDetailsState extends State<ItemDetails> {
  void _handleQuantityChanged(int newQty) {
    widget.onQuantityChanged(
      widget.displayPrice,
      widget.displayOldPrice,
      widget.displayDiscount,
      newQty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = AppTextScale.of(context);
    final sp = AppSpacing.of(context);

    final weightStyle = TextStyle(
      fontFamily: "PlusJakartaSans",
      fontSize: ts.overline,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      color: const Color(0xFF111827),
    );
    final nameStyle = TextStyle(
      fontFamily: "PlusJakartaSans",
      fontSize: ts.body,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF111827),
    );
    final priceStyle = TextStyle(
      fontFamily: "PlusJakartaSans",
      fontSize: ts.price,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF111827),
    );
    final strikePriceStyle = TextStyle(
      fontFamily: "PlusJakartaSans",
      fontSize: ts.label,
      fontWeight: FontWeight.w500,
      color: const Color.fromARGB(255, 53, 55, 58),
      decoration: TextDecoration.lineThrough,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: sp.cardPadding / 2, bottom: 2),
          child: Text(
            widget.product.weight.toUpperCase(),
            style: weightStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          widget.product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    children: [
                      if (widget.displayPrice == 0)
                        Container(
                          width: 48,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                      else ...[
                        Text(
                          '₹${widget.displayPrice.toStringAsFixed(0)}',
                          style: priceStyle,
                        ),
                        if (widget.displayOldPrice > widget.displayPrice)
                          Text(
                            '₹${widget.displayOldPrice.toStringAsFixed(0)}',
                            style: strikePriceStyle,
                          ),
                      ],
                    ],
                  ),
                  if (widget.displayUnitLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.displayUnitLabel.toUpperCase(),
                        style: weightStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            AddButton(
              externalQuantity: widget.cartCount,
              isDisabled: widget.disableAdd,
              onQuantityChanged: _handleQuantityChanged,
            ),
          ],
        ),
      ],
    );
  }
}
