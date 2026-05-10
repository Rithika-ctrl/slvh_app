/// ManageBannersScreen
///
/// Admin screen for uploading, toggling, reordering and deleting
/// promotional banners.  Reached via `/admin/banners`.
///
/// Features
/// ─────────
/// • Live list of all banners streamed from Firestore
/// • Upload new banner (image_picker → Firebase Storage)
/// • Set deeplink, active status, sort order
/// • Toggle active/inactive with a switch
/// • Delete with confirmation dialog
/// • Drag-to-reorder (updates sortOrder in Firestore batch)

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../models/banner_model.dart';
import '../services/banner_service.dart';

class ManageBannersScreen extends StatefulWidget {
  const ManageBannersScreen({super.key});

  @override
  State<ManageBannersScreen> createState() => _ManageBannersScreenState();
}

class _ManageBannersScreenState extends State<ManageBannersScreen> {
  final BannerService _service = BannerService();
  final ImagePicker _picker = ImagePicker();

  bool _uploading = false;

  // ── Upload flow ───────────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    // Collect optional meta from dialog
    final meta = await _showBannerMetaDialog();
    if (meta == null) return; // user cancelled

    setState(() => _uploading = true);
    try {
      await _service.addBanner(
        imageFile: File(picked.path),
        deeplink: meta.deeplink,
        isActive: meta.isActive,
        sortOrder: meta.sortOrder,
      );
      if (mounted) {
        _showSnack('Banner uploaded successfully ✅');
      }
    } catch (e) {
      if (mounted) _showSnack('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Meta dialog ───────────────────────────────────────────────────────────

  Future<_BannerMeta?> _showBannerMetaDialog({BannerModel? existing}) async {
    final deeplinkCtrl =
        TextEditingController(text: existing?.deeplink ?? '');
    final sortOrderCtrl =
        TextEditingController(text: '${existing?.sortOrder ?? 0}');
    bool isActive = existing?.isActive ?? true;

    return showDialog<_BannerMeta>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppColors.bgCream,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? 'New Banner' : 'Edit Banner',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Deeplink
                _Field(
                  controller: deeplinkCtrl,
                  label: 'Deeplink (optional)',
                  hint: 'e.g. /products/xyz',
                  prefixIcon: Icons.link_rounded,
                ),
                const SizedBox(height: 14),

                // Sort order
                _Field(
                  controller: sortOrderCtrl,
                  label: 'Sort Order',
                  hint: '0 = first',
                  prefixIcon: Icons.sort_rounded,
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 14),

                // Active toggle
                Row(
                  children: [
                    const Icon(Icons.visibility_rounded,
                        size: 20, color: AppColors.textHint),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Show on home screen',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: isActive,
                      activeColor: AppColors.success,
                      onChanged: (v) => setDlgState(() => isActive = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(
                  ctx,
                  _BannerMeta(
                    deeplink: deeplinkCtrl.text.trim(),
                    sortOrder: int.tryParse(sortOrderCtrl.text.trim()) ?? 0,
                    isActive: isActive,
                  ),
                );
              },
              child: Text(existing == null ? 'Upload' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit existing banner meta ─────────────────────────────────────────────

  Future<void> _editBanner(BannerModel banner) async {
    final meta = await _showBannerMetaDialog(existing: banner);
    if (meta == null) return;

    try {
      await _service.updateBanner(
        bannerId: banner.id,
        deeplink: meta.deeplink,
        isActive: meta.isActive,
        sortOrder: meta.sortOrder,
      );
      if (mounted) _showSnack('Banner updated ✅');
    } catch (e) {
      if (mounted) _showSnack('Update failed: $e', isError: true);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteBanner(BannerModel banner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Banner?',
          style: TextStyle(
              fontWeight: FontWeight.w900, color: AppColors.textDark),
        ),
        content: const Text(
          'This will permanently remove the image and banner record.',
          style: TextStyle(color: AppColors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteBanner(banner);
      if (mounted) _showSnack('Banner deleted');
    } catch (e) {
      if (mounted) _showSnack('Delete failed: $e', isError: true);
    }
  }

  // ── Reorder ───────────────────────────────────────────────────────────────

  Future<void> _onReorder(
      List<BannerModel> current, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = List<BannerModel>.from(current);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    // Persist immediately (optimistic – list is driven by Firestore stream)
    await _service.reorder(reordered);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        backgroundColor: AppColors.bgCream,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Banner Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          if (_uploading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.orange),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_photo_alternate_rounded,
                    size: 18),
                label: const Text('Add Banner'),
                onPressed: _pickAndUpload,
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<BannerModel>>(
        stream: _service.watchAllBanners(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.orange),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style:
                    const TextStyle(color: AppColors.error, fontSize: 14),
              ),
            );
          }

          final banners = snapshot.data ?? [];

          if (banners.isEmpty) {
            return const _EmptyState();
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: banners.length,
            onReorder: (o, n) => _onReorder(banners, o, n),
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              child: child,
            ),
            itemBuilder: (context, index) {
              final b = banners[index];
              return _BannerTile(
                key: ValueKey(b.id),
                banner: b,
                onToggle: (v) =>
                    _service.toggleActive(b.id, active: v),
                onEdit: () => _editBanner(b),
                onDelete: () => _deleteBanner(b),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner tile
// ─────────────────────────────────────────────────────────────────────────────

class _BannerTile extends StatelessWidget {
  final BannerModel banner;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BannerTile({
    super.key,
    required this.banner,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB47820).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.drag_handle_rounded,
                color: AppColors.textHint, size: 22),
          ),

          // Banner image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: CachedNetworkImage(
              imageUrl: banner.imageUrl,
              width: 110,
              height: 70,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 110,
                height: 70,
                color: AppColors.bgCreamLight,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 110,
                height: 70,
                color: AppColors.bgCreamLight,
                child: const Icon(Icons.broken_image_rounded,
                    color: AppColors.textHint),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sort + active badge
                Row(
                  children: [
                    _Chip(
                      label: 'Order: ${banner.sortOrder}',
                      color: AppColors.catBlue,
                    ),
                    const SizedBox(width: 6),
                    _Chip(
                      label: banner.isActive ? 'Active' : 'Hidden',
                      color: banner.isActive
                          ? AppColors.success
                          : AppColors.textHint,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (banner.deeplink?.isNotEmpty == true) ...[
                  Row(
                    children: [
                      const Icon(Icons.link_rounded,
                          size: 13, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          banner.deeplink!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else
                  const Text(
                    'No deeplink',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
              ],
            ),
          ),

          // Controls
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch.adaptive(
                value: banner.isActive,
                activeColor: AppColors.success,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: onToggle,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.catBlue),
                    tooltip: 'Edit',
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.error),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🖼️',
              style:
                  const TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'No banners yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap "Add Banner" to upload the first promotional image.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final TextInputType keyboard;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, size: 18, color: AppColors.textHint),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.cardBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.cardBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.orange, width: 2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DTO for dialog return value
// ─────────────────────────────────────────────────────────────────────────────

class _BannerMeta {
  final String deeplink;
  final int sortOrder;
  final bool isActive;

  const _BannerMeta({
    required this.deeplink,
    required this.sortOrder,
    required this.isActive,
  });
}