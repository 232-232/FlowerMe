import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeScope.themeOf(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: isSelected ? appTheme.primaryAccent : Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: isSelected
                  ? null
                  : const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                splashColor: (isSelected ? Colors.white : appTheme.primaryAccent).withOpacity(0.15),
                highlightColor: (isSelected ? Colors.white : appTheme.primaryAccent).withOpacity(0.08),
                onTap: () => onSelected(category),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF444444),
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
