import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Levels of urgency a need can carry, each mapped to its own
/// label, foreground color and soft background tint.
enum Urgency {
  low('Low Urgency', AppColors.urgentLow, AppColors.urgentLowSoft),
  medium('Medium Urgency', AppColors.urgentMedium, AppColors.urgentMediumSoft),
  high('High Urgency', AppColors.urgentHigh, AppColors.urgentHighSoft);

  const Urgency(this.label, this.color, this.softColor);

  final String label;
  final Color color;
  final Color softColor;

  /// Short form used in compact selectors ("Low", "Medium", "High").
  String get shortLabel => label.split(' ').first;
}

/// A single marketplace "need" posted by a buyer.
class Need {
  const Need({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.budget,
    required this.timeElapsed,
    required this.urgency,
    required this.authorName,
    required this.offers,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final int budget;
  final String timeElapsed;
  final Urgency urgency;
  final String authorName;
  final int offers;

  /// Budget formatted with thousands separators and a PKR prefix.
  String get formattedBudget {
    final raw = budget.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return 'PKR $buffer';
  }
}

/// Sample data used to drive the UI in this frontend-only build.
class MockData {
  MockData._();

  static const List<String> categories = [
    'Tech & Development',
    'Local Services',
    'Design & Creative',
    'Delivery & Logistics',
    'Home & Repair',
    'Tutoring',
  ];

  static const List<String> filterChips = [
    'Trending',
    'Tech',
    'Local Services',
    'Urgent',
    'Design',
    'Delivery',
  ];

  static const List<Need> needs = [
    Need(
      id: 'n1',
      title: 'Flutter developer for food delivery MVP',
      description:
          'Looking for an experienced Flutter dev to build a 4-screen MVP '
          'with live order tracking and Stripe payments. Designs are ready.',
      category: 'Tech & Development',
      budget: 85000,
      timeElapsed: '12m ago',
      urgency: Urgency.high,
      authorName: 'Ayesha K.',
      offers: 7,
    ),
    Need(
      id: 'n2',
      title: 'AC repair & gas refill in DHA Phase 5',
      description:
          'Two split units not cooling properly. Need a certified technician '
          'today for inspection, gas refill and servicing.',
      category: 'Home & Repair',
      budget: 6500,
      timeElapsed: '34m ago',
      urgency: Urgency.medium,
      authorName: 'Bilal R.',
      offers: 3,
    ),
    Need(
      id: 'n3',
      title: 'Brand identity & logo for organic skincare',
      description:
          'Premium, minimalist brand kit: logo, color system, packaging '
          'mockups and a one-page brand guideline.',
      category: 'Design & Creative',
      budget: 40000,
      timeElapsed: '1h ago',
      urgency: Urgency.low,
      authorName: 'Hira S.',
      offers: 11,
    ),
    Need(
      id: 'n4',
      title: 'Same-day documents delivery (Lahore → Islamabad)',
      description:
          'Sealed envelope pickup from Gulberg, drop at Blue Area before 6pm. '
          'Rider with a clean record preferred.',
      category: 'Delivery & Logistics',
      budget: 4500,
      timeElapsed: '2h ago',
      urgency: Urgency.high,
      authorName: 'Usman T.',
      offers: 5,
    ),
    Need(
      id: 'n5',
      title: 'O-Level Maths tutor, 3 sessions a week',
      description:
          'Need a patient tutor for my son, focus on past papers and exam '
          'technique. Evenings preferred, online is fine.',
      category: 'Tutoring',
      budget: 25000,
      timeElapsed: '4h ago',
      urgency: Urgency.medium,
      authorName: 'Sana M.',
      offers: 2,
    ),
  ];
}
