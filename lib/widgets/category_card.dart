import 'package:flutter/material.dart';

class DailyClubCategoryItem {
  const DailyClubCategoryItem({
    required this.title,
    required this.icon,
    required this.colors,
  });

  final String title;
  final IconData icon;
  final List<Color> colors;
}

/// Product tile with image-like artwork and label below.
class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.item});

  final DailyClubCategoryItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              // FIX 19: Removed 10px BoxShadow to completely flatten the graphics layer tree
              border: Border.all(color: const Color(0xFFE5E7EB), width: 0.7),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: item.colors,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -10,
                      right: -6,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -14,
                      left: -10,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 18),
                      ),
                    ),
                    const Positioned(
                      left: 8,
                      bottom: 8,
                      child: _MiniPack(
                        width: 10,
                        height: 22,
                        color: Color(0xFFFFF2D3),
                      ),
                    ),
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: _MiniPack(
                        width: 13,
                        height: 24,
                        color: Color(0xFFF6C04A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          item.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.15,
            color: Color(0xFF111111),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MiniPack extends StatelessWidget {
  const _MiniPack({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
