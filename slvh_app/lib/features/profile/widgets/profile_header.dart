import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Displays the user's avatar, name, and phone number at the top of the
/// profile screen.  Name is editable inline via [onEditName].
class ProfileHeader extends StatelessWidget {
  final String phone;
  final String name;
  final VoidCallback onEditName;

  const ProfileHeader({
    super.key,
    required this.phone,
    required this.name,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB347), AppColors.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Center(
              child: Text('👤', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 14),

          // Name row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name.isNotEmpty ? name : 'Add your name',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: name.isNotEmpty
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEditName,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Phone
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_rounded,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 5),
              Text(
                phone,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}