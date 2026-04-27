import 'package:flutter/material.dart';

import 'optimized_network_image.dart';

import '../debug/perf_logger.dart';
import '../layout/responsive_layout.dart';
import '../models/category_model.dart';
import '../pages/items_page.dart';
import '../providers/category_provider.dart';
import '../providers/user_profile_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/personalize_service.dart';
import '../utils/share_helper.dart';
import '../utils/share_helper.dart';

// Deterministic pastel background colours for each tile
const _kTileColors = [
  Color(0xffFEF2F2),
  Color(0xffEFF6FF),
  Color(0xffECFDF3),
  Color(0xffEEF2FF),
  Color(0xffFFFBEB),
  Color(0xffFEF2FF),
  Color(0xffF5F3FF),
  Color(0xffECFEFF),
  Color(0xffFFF7ED),
  Color(0xffF0FDF4),
];

class CategoryGrid extends StatefulWidget {
  const CategoryGrid({super.key});

  @override
  State<CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<CategoryGrid> {
  Future<List<CategoryModel>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Perf.start('CategoryGrid', 'Name fetch');
      setState(() {
        _future = CategoryProvider.getCategoriesOnce();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryModel>>(
      initialData: CategoryProvider.cachedCategories,
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Could not load categories.',
                style: TextStyle(fontFamily: "PlusJakartaSans", 
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }

        if (_future == null || !snapshot.hasData) {
          return SliverToBoxAdapter(child: _CategoryShimmer());
        }

        Perf.end('CategoryGrid', 'Name fetch');

        final categories = snapshot.data!;
        if (categories.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.of(context).screenPadding,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: AppGridConfig.of(context).maxCrossAxisExtent,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _CategoryTile(
                  category: categories[index],
                  bgColor: _kTileColors[index % _kTileColors.length],
                );
              },
              childCount: categories.length,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual tile
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({required this.category, required this.bgColor});

  final CategoryModel category;
  final Color bgColor;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tileSize = AppSpacing.of(context).tileSize;
    final ts = AppTextScale.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: widget.bgColor.withOpacity(0.6),
        highlightColor: widget.bgColor.withOpacity(0.3),
        onTap: () {
          Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (context) => ItemsPage(initialCategory: widget.category.name),
            ),
          );
        },
        onLongPress: () {
          ShareHelper.shareCategory(
            widget.category.name,
            categoryCode: widget.category.code,
            categoryImage: widget.category.picUrl,
          );
          if (mounted) {
            final phone = context.read<UserProfileProvider>().phone;
            PersonalizeService.logShare(phone, widget.category.code);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: Ink(
                width: tileSize,
                height: tileSize,
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _CategoryImage(category: widget.category, size: tileSize),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "PlusJakartaSans",
                color: const Color.fromARGB(255, 62, 70, 81),
                fontSize: ts.label,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.category, required this.size});

  final CategoryModel category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = category.picUrl;
    if (url == null || url.isEmpty) {
      return Icon(
        Icons.category_outlined,
        size: size * 0.4,
        color: const Color(0xFF9CA3AF),
      );
    }
    return OptimizedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 100),
      trackLogLabel: 'CategoryGrid',
      trackLogName: category.name,
      placeholder: _ShimmerBox(width: size + 10, height: size + 10, radius: 18),
      errorWidget: Icon(
        Icons.category_outlined,
        size: size * 0.4,
        color: const Color(0xFF9CA3AF),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading shimmer placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryShimmer extends StatefulWidget {
  @override
  State<_CategoryShimmer> createState() => _CategoryShimmerState();
}

class _CategoryShimmerState extends State<_CategoryShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (_, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => _ShimmerBox(
                      width: 84,
                      height: 84,
                      radius: 20,
                      opacity: _anim.value,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => _ShimmerBox(
                      width: 60,
                      height: 10,
                      radius: 4,
                      opacity: _anim.value,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
    this.opacity = 1.0,
  });

  final double width;
  final double height;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Color.fromRGBO(203, 213, 225, opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
