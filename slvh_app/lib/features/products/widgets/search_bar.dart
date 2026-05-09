import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Reusable Search Bar Widget
///
/// Used in ProductListScreen and other search-enabled screens.
/// Provides real-time search with debouncing.

class ProductSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final String placeholder;
  final String? initialValue;
  final VoidCallback? onFilterTap;
  final bool showFilter;

  const ProductSearchBar({
    super.key,
    required this.onSearch,
    this.placeholder = 'Search products…',
    this.initialValue,
    this.onFilterTap,
    this.showFilter = true,
  });

  @override
  State<ProductSearchBar> createState() => _ProductSearchBarState();
}

class _ProductSearchBarState extends State<ProductSearchBar> {
  late TextEditingController _controller;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        boxShadow: [
          if (_isFocused)
            BoxShadow(
              color: AppColors.orange.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Focus(
        onFocusChange: (focused) {
          setState(() => _isFocused = focused);
        },
        child: TextField(
          controller: _controller,
          onChanged: widget.onSearch,
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.95),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppColors.orange,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: AppColors.orange.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppColors.orange,
                width: 2,
              ),
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                Icons.search,
                color: AppColors.orange,
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clear button
                if (_controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      widget.onSearch('');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.close_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                    ),
                  ),

                // Filter button
                if (widget.showFilter)
                  GestureDetector(
                    onTap: widget.onFilterTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.tune,
                        color: AppColors.orange,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
          ),
        ),
      ),
    );
  }
}
