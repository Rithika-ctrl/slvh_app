import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../features/categories/models/category_model.dart';
import '../../../core/constants/app_colors.dart';

/// CategoryRow
///
/// Horizontally scrollable row of category chips / cards.
/// Each chip shows the category image + name.
/// Tapping fires [onCategoryTap] with the selected [CategoryModel].
class CategoryRow extends StatefulWidget {
  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel>? onCategoryTap;

  const CategoryRow({
    super.key,
    required this.categories,
    this.onCategoryTap,
  });

  @override
  State<CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<CategoryRow> {
  String? _selectedId;

  static const List<Color> _palette = [
    AppColors.orange,
    AppColors.catPink,
    AppColors.catBlue,
    AppColors.catGreen,
    AppColors.catPurple,
    AppColors.catCyan,
    AppColors.catYellow,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 4),
        itemCount: widget.categories.length,
        itemBuilder: (_, i) {
          final cat = widget.categories[i];
          final color = _palette[i % _palette.length];
          final selected = _selectedId == cat.id;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedId = selected ? null : cat.id);
              widget.onCategoryTap?.call(cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              width: 72,
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(0.15)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? color : AppColors.cardBorder,
                  width: selected ? 2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(selected ? 0.18 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Image or fallback emoji
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: cat.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: cat.imageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _FallbackIcon(
                                color: color, letter: cat.name[0]),
                            errorWidget: (_, __, ___) =>
                                _FallbackIcon(color: color, letter: cat.name[0]),
                          )
                        : _FallbackIcon(color: color, letter: cat.name[0]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected ? color : AppColors.textDark,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final Color color;
  final String letter;
  const _FallbackIcon({required this.color, required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          letter.toUpperCase(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    );
  }
}
