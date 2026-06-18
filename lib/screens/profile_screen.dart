import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('My Profile',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 46,
              backgroundColor: AppColors.primary,
              child: Text('AK',
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            const Text('Ayesha Khan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const Text('ayesha.khan@example.com',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            _tile(Icons.history_rounded, 'My Posted Needs'),
            _tile(Icons.payment_rounded, 'Payment Methods'),
            _tile(Icons.security_rounded, 'Account Security'),
            _tile(Icons.help_outline_rounded, 'Help & Support'),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        onTap: () {},
      ),
    );
  }
}
