import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Messages',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final names = [
            'Zeeshan Ali (Plumber)',
            'Maria B. (Designer)',
            'Kashif Tech'
          ];
          final snippets = [
            'Main kal subah 10 baje visit kar sakta hoon.',
            'I can design the luxury logo for you.',
            'Budget is fine, let\'s locked the deal'
          ];
          return ListTile(
            contentPadding: const EdgeInsets.all(12),
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border)),
            leading: CircleAvatar(
                backgroundColor: AppColors.accent,
                child: Text(names[index][0],
                    style: const TextStyle(color: Colors.white))),
            title: Text(names[index],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(snippets[index],
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
            onTap: () {},
          );
        },
      ),
    );
  }
}
