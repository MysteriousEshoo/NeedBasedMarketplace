import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/need_model.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_loading_button.dart';

/// Screen 3 — Step-by-step "Post a Need" form.
///
/// Three logical steps are presented behind a segmented progress indicator,
/// with animated transitions between steps. The final step publishes with a
/// loading animation before returning to the feed.
class PostNeedScreen extends StatefulWidget {
  const PostNeedScreen({super.key});

  @override
  State<PostNeedScreen> createState() => _PostNeedScreenState();
}

class _PostNeedScreenState extends State<PostNeedScreen> {
  static const int _totalSteps = 3;

  final _pageController = PageController();
  int _currentStep = 0;
  bool _isPublishing = false;

  // ---- Form state ----
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  String? _selectedCategory;
  Urgency _selectedUrgency = Urgency.medium;

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _publish();
    }
  }

  void _back() {
    if (_currentStep == 0) {
      Navigator.of(context).pop();
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Assembles the user's input into a [Need] structure.
  Need _buildNeed(String authorName, String authorId) {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final budget = int.tryParse(
          _budgetController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    return Need(
      id: 'n${DateTime.now().millisecondsSinceEpoch}',
      title: title.isEmpty ? 'Untitled need' : title,
      description:
          description.isEmpty ? 'No description provided yet.' : description,
      category: _selectedCategory ?? MockData.categories.first,
      budget: budget,
      timeElapsed: 'Just now',
      urgency: _selectedUrgency,
      authorName: authorName,
      offers: 0,
    );
  }

  Future<void> _publish() async {
    setState(() => _isPublishing = true);

    try {
      // 1. Current logged-in user ki details nikaalein
      final currentUser = FirebaseAuth.instance.currentUser;
      final String authorId = currentUser?.uid ?? 'unknown_user';

      // Defensively user ka naam nikaalna:
      // Pehle user ka display name check hoga, agar khaali hua toh email ka shuruati hissa utha lengey
      String currentUserName = 'Anonymous User';
      if (currentUser != null) {
        if (currentUser.displayName != null &&
            currentUser.displayName!.isNotEmpty) {
          currentUserName = currentUser.displayName!;
        } else if (currentUser.email != null) {
          currentUserName = currentUser.email!.split('@').first;
        }
      }

      // 2. Inputs se data collect karein
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final budget = int.tryParse(
              _budgetController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
          0;

      // 3. Map tayaar karein jo database mein save hoga (FULLY DYNAMIC AUTHOR LINKED)
      final Map<String, dynamic> needData = {
        'title': title.isEmpty ? 'Untitled need' : title,
        'description':
            description.isEmpty ? 'No description provided yet.' : description,
        'category': _selectedCategory ?? 'General',
        'budget': budget,
        'urgency':
            _selectedUrgency.toString().split('.').last, // low, medium, high
        'authorId': authorId, // TRACKING ID ADDED
        'authorName': currentUserName, // DYNAMIC LIVE USER NAME
        'timestamp': ServerValue.timestamp, // Firebase server side time
        'offers': 0,
      };

      // 4. Realtime Database mein 'needs' naam ka folder bana kar push karein
      final DatabaseReference dbRef =
          FirebaseDatabase.instance.ref().child('needs');
      await dbRef.push().set(needData);

      if (!mounted) return;
      setState(() => _isPublishing = false);

      // 5. Data save hone ke baad screen band karein
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Need Published Successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPublishing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error publishing: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _back,
        ),
        title: const Text('Post a Need'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildStepOne(),
                  _buildStepTwo(),
                  _buildStepThree(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Progress
  // --------------------------------------------------------------------------

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Steps
  // --------------------------------------------------------------------------

  Widget _buildStepOne() {
    return _StepScaffold(
      step: 'Step 1 of 3',
      title: 'What do you need?',
      subtitle: 'Give your need a clear title and pick a category.',
      children: [
        const _FieldLabel('Need title'),
        TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Flutter developer for a delivery app',
          ),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Category'),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          hint: const Text('Choose a category'),
          borderRadius: BorderRadius.circular(16),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: MockData.categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategory = v),
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return _StepScaffold(
      step: 'Step 2 of 3',
      title: 'Add the details',
      subtitle: 'Describe what you need and set an estimated budget.',
      children: [
        const _FieldLabel('Description'),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.4),
          ),
          child: Column(
            children: [
              _buildFakeToolbar(),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Share scope, expectations, location, timeline…',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Estimated budget'),
        TextField(
          controller: _budgetController,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          decoration: InputDecoration(
            hintText: '0',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Container(
                alignment: Alignment.center,
                width: 44,
                child: const Text(
                  'PKR',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
      ],
    );
  }

  Widget _buildStepThree() {
    return _StepScaffold(
      step: 'Step 3 of 3',
      title: 'How urgent is it?',
      subtitle: 'This helps providers prioritise the right requests.',
      children: [
        ...Urgency.values.map(
          (u) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _UrgencyCard(
              urgency: u,
              selected: _selectedUrgency == u,
              onTap: () => setState(() => _selectedUrgency = u),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFakeToolbar() {
    const icons = [
      Icons.format_bold_rounded,
      Icons.format_italic_rounded,
      Icons.format_list_bulleted_rounded,
      Icons.link_rounded,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: icons
            .map(
              (i) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(i, size: 20, color: AppColors.textSecondary),
              ),
            )
            .toList(),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Bottom bar
  // --------------------------------------------------------------------------

  Widget _buildBottomBar() {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _back,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 3,
              child: PrimaryLoadingButton(
                label: isLast ? 'Publish Need' : 'Continue',
                icon: isLast ? Icons.rocket_launch_rounded : null,
                isLoading: _isPublishing,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Private helpers
// ----------------------------------------------------------------------------

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String step;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: textTheme.headlineMedium?.copyWith(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _UrgencyCard extends StatelessWidget {
  const _UrgencyCard({
    required this.urgency,
    required this.selected,
    required this.onTap,
  });

  final Urgency urgency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? urgency.softColor : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? urgency.color : AppColors.border,
            width: selected ? 1.8 : 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: urgency.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                color: urgency.color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    urgency.shortLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitleFor(urgency),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: Icon(Icons.check_circle_rounded, color: urgency.color),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(Urgency u) {
    switch (u) {
      case Urgency.low:
        return 'Flexible timeline, no rush';
      case Urgency.medium:
        return 'Needed within a few days';
      case Urgency.high:
        return 'Needed as soon as possible';
    }
  }
}
