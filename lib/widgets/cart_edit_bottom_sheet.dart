import 'package:flutter/material.dart';
import '../cart_controller.dart';
import '../theme/app_colors.dart';
import 'optimized_network_image.dart';

class CartEditBottomSheet {
  static void show(BuildContext context, CartController cart) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ListenableBuilder(
          listenable: cart,
          builder: (context, _) {
            if (cart.count == 0) {
              // Auto close if cart gets completely emptied
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              });
              return const SizedBox(height: 200);
            }
            return _CartEditSheetContent(cart: cart);
          },
        );
      },
    );
  }
}

class _CartEditSheetContent extends StatelessWidget {
  const _CartEditSheetContent({required this.cart});
  final CartController cart;

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.themeOf(context);
    final accent = theme.primaryAccent;
    
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Remove Items',
                  style: TextStyle(fontFamily: "PlusJakartaSans", 
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 20, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          // Items List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: cart.entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final entry = cart.entries[index];
                return Row(
                  children: [
                    // Image
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: OptimizedNetworkImage(
                          imageUrl: entry.product.image,
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: "PlusJakartaSans", 
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entry.variantLabel}  ·  Qty: ${entry.quantity}',
                            style: TextStyle(fontFamily: "PlusJakartaSans", 
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${entry.lineTotal.toStringAsFixed(0)}',
                            style: TextStyle(fontFamily: "PlusJakartaSans", 
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Delete Button
                    GestureDetector(
                      onTap: () {
                        // User specifically said "chan only dlete 1 item" meaning drop quantity by 1 OR remove the whole row.
                        // We will remove the entire row since the icon is a delete trash icon which implies full removal.
                        // Or wait, if we drop quantity:
                        // final newQ = entry.quantity - 1;
                        // cart.updateQuantityAt(index, newQ);
                        // Let's drop quantity by 1 to perfectly fit "dlete 1 item", and if it drops to 0 it deletes the row.
                        final newQuantity = entry.quantity - 1;
                        cart.updateQuantityAt(index, newQuantity);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFFF5252),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Clear all button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextButton(
              onPressed: () {
                cart.clear();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Text(
                'Clear Entire Cart',
                style: TextStyle(fontFamily: "PlusJakartaSans", 
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
