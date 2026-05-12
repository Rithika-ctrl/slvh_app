import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../auth/services/auth_service.dart';
import '../../orders/screens/order_history_screen.dart';
import '../widgets/profile_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  String _phone = '';
  String _name = '';
  String _appVersion = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final phone = await _authService.getCurrentUserPhone() ?? '';
    String name = '';

    // Load name from Firestore users/{phone}
    if (phone.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(phone)
            .get();
        name = (doc.data()?['name'] as String?) ?? '';
      } catch (_) {}
    }

    // App version — update this string with each release
    const String version = 'v1.0.0';

    if (!mounted) return;
    setState(() {
      _phone = phone;
      _name = name;
      _appVersion = version;
      _loading = false;
    });
  }

  // ── Edit name dialog ──────────────────────────────────────────────────────

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _name);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Name',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: const TextStyle(color: AppColors.textHint),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (saved == null || saved == _name) return;

    setState(() => _name = saved);

    // Persist to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_phone)
          .set({'name': saved}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save name'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out',
            style: TextStyle(
                fontWeight: FontWeight.w900, color: AppColors.textDark)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: AppColors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _authService.signOut();
    if (mounted) context.go('/');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'My Profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.orange,
                  strokeWidth: 2,
                ),
              )
            : ListView(
                children: [
                  // ── Header ──────────────────────────────────────────────
                  ProfileHeader(
                    phone: _phone,
                    name: _name,
                    onEditName: _editName,
                  ),

                  const SizedBox(height: 24),

                  // ── Menu tiles ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _MenuCard(
                          children: [
                            _Tile(
                              icon: Icons.person_outline_rounded,
                              iconColor: AppColors.catPurple,
                              label: 'Edit Name',
                              onTap: _editName,
                            ),
                            _divider(),
                            _Tile(
                              icon: Icons.phone_outlined,
                              iconColor: AppColors.catBlue,
                              label: 'Phone Number',
                              trailing: Text(
                                _phone,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        _MenuCard(
                          children: [
                            _Tile(
                              icon: Icons.receipt_long_rounded,
                              iconColor: AppColors.orange,
                              label: 'Order History',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderHistoryScreen(
                                    customerId: _phone,
                                    onOrderTap: (id) =>
                                        context.push('/order/$id'),
                                  ),
                                ),
                              ),
                            ),
                            _divider(),
                            _Tile(
                              icon: Icons.notifications_outlined,
                              iconColor: AppColors.catPink,
                              label: 'Notifications',
                              onTap: () => context.push('/notifications'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        _MenuCard(
                          children: [
                            _Tile(
                              icon: Icons.info_outline_rounded,
                              iconColor: AppColors.catCyan,
                              label: 'App Version',
                              trailing: Text(
                                _appVersion,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Logout button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text(
                              'Log Out',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _divider() => const Divider(
      height: 1, thickness: 1, color: Color(0x18DCA03C), indent: 56);
}

// ── Reusable card wrapper ─────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22DCA03C), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB47820).withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ── Single menu row ───────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
      ),
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint, size: 20)
              : null),
    );
  }
}