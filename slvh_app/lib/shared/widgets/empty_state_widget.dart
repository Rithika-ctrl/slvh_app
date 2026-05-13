import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Reusable Empty State Widget
///
/// Displays a consistent empty state UI across all screens (empty search results,
/// no orders yet, no products, 404 errors, etc.)
///
/// Example:
/// ```dart
/// EmptyStateWidget(
///   icon: Icons.shopping_bag_outlined,
///   title: 'No Orders Yet',
///   subtitle: 'Start shopping to create your first order',
///   actionButton: ElevatedButton(
///     onPressed: () => Navigator.pop(context),
///     child: const Text('Start Shopping'),
///   ),
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  /// Icon to display (e.g., Icons.shopping_bag_outlined)
  final IconData icon;

  /// Main title text (e.g., "No Orders Yet")
  final String title;

  /// Subtitle/description text (e.g., "Start shopping to create your first order")
  final String subtitle;

  /// Optional action button (e.g., ElevatedButton to navigate or retry)
  final Widget? actionButton;

  /// Icon size (default: 64)
  final double iconSize;

  /// Icon color (default: textHint)
  final Color? iconColor;

  /// Whether to center content vertically (full screen)
  final bool fullHeight;

  /// Custom height if fullHeight is false (default: 280)
  final double? height;

  /// Text alignment (default: center)
  final TextAlign textAlign;

  /// Spacing between elements
  final double spacing;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionButton,
    this.iconSize = 64,
    this.iconColor,
    this.fullHeight = true,
    this.height,
    this.textAlign = TextAlign.center,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final widget = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Icon(
            icon,
            size: iconSize,
            color: iconColor ?? AppColors.textHint,
          ),

          // Spacing
          SizedBox(height: spacing),

          // Title
          Text(
            title,
            textAlign: textAlign,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
          ),

          // Subtitle spacing
          SizedBox(height: spacing * 0.5),

          // Subtitle
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing * 1.25),
            child: Text(
              subtitle,
              textAlign: textAlign,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),

          // Action button (if provided)
          if (actionButton != null) ...[
            SizedBox(height: spacing * 1.5),
            actionButton!,
          ],
        ],
      ),
    );

    if (fullHeight) {
      return SizedBox.expand(child: widget);
    }

    return SizedBox(
      height: height ?? 280,
      child: widget,
    );
  }
}

/// Error State Widget
///
/// Displays error states with optional retry button
///
/// Example:
/// ```dart
/// ErrorStateWidget(
///   message: 'Could not load orders',
///   onRetry: () => _loadOrders(),
/// )
/// ```
class ErrorStateWidget extends StatelessWidget {
  /// Error message to display
  final String message;

  /// Optional callback for retry button
  final VoidCallback? onRetry;

  /// Icon to display (default: error icon)
  final IconData icon;

  /// Custom error color (default: red)
  final Color? errorColor;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.errorColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = errorColor ?? Colors.red;

    return EmptyStateWidget(
      icon: icon,
      title: 'Something went wrong',
      subtitle: message,
      iconColor: color.withOpacity(0.7),
      actionButton: onRetry != null
          ? ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
            )
          : null,
    );
  }
}

/// Loading State Widget
///
/// Displays loading indicator with optional message
///
/// Example:
/// ```dart
/// LoadingStateWidget(message: 'Loading orders...')
/// ```
class LoadingStateWidget extends StatelessWidget {
  /// Optional message to display below spinner
  final String? message;

  /// Spinner color (default: orange)
  final Color? spinnerColor;

  const LoadingStateWidget({
    super.key,
    this.message,
    this.spinnerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              spinnerColor ?? AppColors.orange,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 404 Not Found Widget
///
/// Specific empty state for 404/not found scenarios
///
/// Example:
/// ```dart
/// NotFoundWidget(
///   itemName: 'Product',
///   onGoBack: () => Navigator.pop(context),
/// )
/// ```
class NotFoundWidget extends StatelessWidget {
  /// Name of the item not found (e.g., "Product", "Order", "User")
  final String itemName;

  /// Optional callback for back/home button
  final VoidCallback? onGoBack;

  const NotFoundWidget({
    super.key,
    required this.itemName,
    this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.search_off_outlined,
      title: '$itemName not found',
      subtitle: 'This $itemName no longer exists or the link is broken.',
      iconColor: Colors.grey,
      actionButton: onGoBack != null
          ? OutlinedButton.icon(
              onPressed: onGoBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            )
          : null,
    );
  }
}
