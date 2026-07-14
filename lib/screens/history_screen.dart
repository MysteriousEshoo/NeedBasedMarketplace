import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import '../models/need_model.dart';
import '../providers/theme_provider.dart';
import '../services/history_service.dart';
import '../theme/app_colors.dart';
import 'need_detail_screen.dart';

/// 📜 CHROME-STYLE ACTIVITY HISTORY
/// Real-time list of everything the user did — offers sent, seller requests,
/// needs visited and needs posted — grouped by day (Today / Yesterday / date)
/// exactly like a browser history. Backed live by RTDB `user_history/{uid}`.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmClearHistory(BuildContext context) async {
    final bool isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final Color surface = isDark ? AppColors.surface : Colors.white;
    final Color textPrimary =
        isDark ? AppColors.textPrimary : Colors.black87;
    final Color textSecondary =
        isDark ? AppColors.textSecondary : Colors.black54;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear history?',
            style: TextStyle(
                color: textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
        content: Text(
            'This will permanently remove your entire activity history. This cannot be undone.',
            style: TextStyle(color: textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.primaryLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear',
                style: TextStyle(
                    color: AppColors.urgentHigh, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HistoryService.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('🧹 History cleared'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  /// Opens the need referenced by a history entry (visited / offer / posted).
  Future<void> _openNeed(BuildContext context, String needId) async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref('needs').child(needId).get();
      if (!context.mounted) return;

      if (!snapshot.exists || snapshot.value is! Map) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('This need is no longer available.'),
            backgroundColor: AppColors.urgentMedium,
            behavior: SnackBarBehavior.floating));
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final need = Need(
        id: needId,
        title: data['title'] ?? 'Untitled',
        description: data['description'] ?? '',
        category: data['category'] ?? 'General',
        budget: data['budget'] ?? 0,
        timeElapsed: '',
        urgency: _parseUrgency(data['urgency']),
        authorName: data['authorName'] ?? 'Anonymous',
        offers: data['offers'] ?? 0,
        userId: data['userId'] ?? data['authorId'] ?? '',
        userName: data['userName'] ?? data['authorName'] ?? '',
        companyName: data['company'],
        condition: data['condition'] != null
            ? (data['condition'] == 'New'
                ? ProductCondition.new_
                : ProductCondition.used)
            : null,
        paymentMethod: data['paymentMethod'] != null
            ? (data['paymentMethod'] == 'Cash'
                ? PaymentMethod.cash
                : PaymentMethod.onlineDeposit)
            : null,
        location: data['location'],
        isPremium: data['isPremium'] ?? false,
        authorId: data['authorId'] ?? data['userId'],
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NeedDetailScreen(need: need)),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open this need. Please try again.'),
            backgroundColor: AppColors.urgentMedium,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Urgency _parseUrgency(dynamic raw) {
    switch (raw) {
      case 'high':
        return Urgency.high;
      case 'medium':
        return Urgency.medium;
      default:
        return Urgency.low;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final Color bg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final Color surface = isDark ? AppColors.surface : Colors.white;
    final Color border =
        isDark ? AppColors.border : const Color(0xFFCBD5E1);
    final Color textPrimary =
        isDark ? AppColors.textPrimary : Colors.black87;
    final Color textSecondary =
        isDark ? AppColors.textSecondary : Colors.black54;
    final Color textTertiary =
        isDark ? AppColors.textTertiary : const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        title: Text('History', style: TextStyle(color: textPrimary)),
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Clear history',
            icon: const Icon(Icons.delete_sweep_rounded,
                color: AppColors.urgentHigh, size: 22),
            onPressed: () => _confirmClearHistory(context),
          ),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: HistoryService.stream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primaryLight));
          }

          final entries = <_HistoryEntry>[];
          final value = snapshot.data?.snapshot.value;
          if (value is Map) {
            value.forEach((key, raw) {
              if (raw is! Map) return;
              final data = Map<String, dynamic>.from(raw);
              entries.add(_HistoryEntry(
                id: key.toString(),
                type: data['type']?.toString() ?? '',
                title: data['title']?.toString() ?? 'Activity',
                subtitle: data['subtitle']?.toString(),
                refId: data['refId']?.toString(),
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                    (data['timestamp'] is int)
                        ? data['timestamp'] as int
                        : int.tryParse('${data['timestamp']}') ?? 0),
              ));
            });
          }

          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded,
                      size: 72, color: textTertiary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No history yet',
                      style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                        'Your offers, seller requests and visited needs will appear here in real time.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: textSecondary, fontSize: 12)),
                  ),
                ],
              ),
            );
          }

          // Newest first, grouped by calendar day (like Chrome).
          entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          final groups = <String, List<_HistoryEntry>>{};
          for (final e in entries) {
            groups.putIfAbsent(_dayLabel(e.timestamp), () => []).add(e);
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              for (final day in groups.keys) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                  child: Text(day,
                      style: TextStyle(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.6)),
                ),
                for (final entry in groups[day]!)
                  _buildHistoryTile(context, entry, surface, border,
                      textPrimary, textSecondary, textTertiary),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryTile(
    BuildContext context,
    _HistoryEntry entry,
    Color surface,
    Color border,
    Color textPrimary,
    Color textSecondary,
    Color textTertiary,
  ) {
    final visual = _visualFor(entry.type);
    final bool canOpenNeed = entry.refId != null &&
        entry.type != HistoryService.typeSellerRequest;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: ListTile(
        onTap:
            canOpenNeed ? () => _openNeed(context, entry.refId!) : null,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: visual.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(visual.icon, color: visual.color, size: 20),
        ),
        title: Text(entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(visual.label,
                style: TextStyle(
                    color: visual.color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
            if (entry.subtitle != null && entry.subtitle!.isNotEmpty)
              Text(entry.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textSecondary, fontSize: 11)),
          ],
        ),
        trailing: Text(_timeLabel(entry.timestamp),
            style: TextStyle(color: textTertiary, fontSize: 11)),
      ),
    );
  }

  _HistoryVisual _visualFor(String type) {
    switch (type) {
      case HistoryService.typeOfferSent:
        return const _HistoryVisual(Icons.local_offer_rounded,
            AppColors.accent, 'Offer sent');
      case HistoryService.typeSellerRequest:
        return const _HistoryVisual(Icons.storefront_rounded,
            AppColors.primaryLight, 'Seller request');
      case HistoryService.typeNeedPosted:
        return const _HistoryVisual(Icons.post_add_rounded,
            AppColors.urgentLow, 'Need posted');
      case HistoryService.typeNeedVisited:
      default:
        return const _HistoryVisual(Icons.visibility_rounded,
            AppColors.urgentMedium, 'Visited');
    }
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${day.day} ${months[day.month - 1]} ${day.year}'.toUpperCase();
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.timestamp,
    this.subtitle,
    this.refId,
  });

  final String id;
  final String type;
  final String title;
  final String? subtitle;
  final String? refId;
  final DateTime timestamp;
}

class _HistoryVisual {
  const _HistoryVisual(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String label;
}
