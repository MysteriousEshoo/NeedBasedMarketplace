import 'package:flutter/material.dart';
import '../models/need_model.dart'
    as legacy; // Ensure it points correctly to your model class structure
import '../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  // ✅ Explicitly matched to match the precise legacy 'Need' array passing channel from MainShell
  final List<legacy.Need> needs;
  final int postSignal;
  final void Function(legacy.Need need) onOpenDetail;

  const HomeScreen({
    super.key,
    required this.needs,
    required this.postSignal,
    required this.onOpenDetail,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // ✅ Restored constant local category layout mapping to completely eliminate MockData errors
  final List<String> _localCategories = [
    'All',
    'Mobile Phone',
    'Tech & Development',
    'Local Services',
    'Electronics',
    'Vehicles'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = isDark ? AppColors.surface : Colors.white;
    final Color borderColor =
        isDark ? AppColors.border : const Color(0xFFE2E8F0);
    final Color textPrimary =
        isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final Color textSecondary =
        isDark ? AppColors.textSecondary : const Color(0xFF475569);
    final Color textTertiary =
        isDark ? AppColors.textTertiary : const Color(0xFF94A3B8);

    // 🔍 Real-time local filtering engine array execution nodes
    final filteredNeeds = widget.needs.where((need) {
      final matchesCategory =
          _selectedCategory == 'All' || need.category == _selectedCategory;
      final matchesSearch = need.title
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          need.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          need.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header display configurations
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SYSTEM USER ACTIVE',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('Marketplace Needs',
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),

            // Search input field pipeline layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor)),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textPrimary),
                  decoration: const InputDecoration(
                      hintText: 'Search needs by keyword, type...',
                      border: InputBorder.none,
                      icon: Icon(Icons.search)),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),

            // Category Horizontal Scrollable Chips Row
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _localCategories.length,
                itemBuilder: (context, index) {
                  final cat = _localCategories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                          color: isSelected ? Colors.white : textSecondary,
                          fontWeight: FontWeight.bold),
                      backgroundColor: surfaceColor,
                      onSelected: (bool selected) {
                        setState(
                            () => _selectedCategory = selected ? cat : 'All');
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Active Listing Data Core Stream View
            Expanded(
              child: filteredNeeds.isEmpty
                  ? Center(
                      child: Text('No active matching needs identified.',
                          style: TextStyle(color: textSecondary)))
                  : ListView.builder(
                      itemCount: filteredNeeds.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemBuilder: (context, index) {
                        final need = filteredNeeds[index];
                        return _buildNeedCard(need, surfaceColor, borderColor,
                            textPrimary, textSecondary, textTertiary);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedCard(legacy.Need need, Color surface, Color border,
      Color textPrimary, Color textSecondary, Color textTertiary) {
    return Card(
      color: surface,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border)),
      child: InkWell(
        onTap: () => widget.onOpenDetail(need),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(need.category,
                        style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  Text(need.timeElapsed,
                      style: TextStyle(color: textTertiary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              Text(need.title,
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(need.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: textSecondary, fontSize: 13, height: 1.4)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rs. ${need.budget}',
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        need.urgency.toString().split('.').last.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
