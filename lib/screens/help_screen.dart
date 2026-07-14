import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../providers/theme_provider.dart';

// ✅ Class name HelpScreen (aapki file ke mutabiq)
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final List<FAQItem> _faqItems = [];
  bool _isLoading = true;
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();

  bool _isAdminMode = false;
  FAQItem? _editingItem;

  @override
  void initState() {
    super.initState();
    _loadFAQs();
    _checkIfAdmin();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _checkIfAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email == 'admin@needhub.com') {
      _isAdminMode = true;
    }
  }

  Future<void> _loadFAQs() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('faqs')
          .orderByChild('order')
          .get();

      _faqItems.clear();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final Map<String, dynamic> item =
              Map<String, dynamic>.from(value as Map);
          _faqItems.add(FAQItem(
            id: key,
            question: item['question'] ?? '',
            answer: item['answer'] ?? '',
            order: item['order'] ?? 0,
          ));
        });
      }

      if (_faqItems.isEmpty) {
        _addDefaultFAQs();
      }
    } catch (e) {
      _addDefaultFAQs();
    }

    setState(() => _isLoading = false);
  }

  void _addDefaultFAQs() {
    _faqItems.clear();
    _faqItems.addAll([
      FAQItem(
        id: 'default1',
        question: 'How do I post a new requirement?',
        answer:
            'Tap the + button on the home screen. Fill in the title, description, category, budget, and urgency. Then tap "Publish Need" to make it live.',
        order: 0,
      ),
      FAQItem(
        id: 'default2',
        question: 'How do I save/bookmark a need?',
        answer:
            'Tap the bookmark icon (📌) on any need card or on the detail screen. Your saved needs will appear in the "Saved" tab.',
        order: 1,
      ),
      FAQItem(
        id: 'default3',
        question: 'How can I submit an offer?',
        answer:
            'Open any need detail screen and tap "Submit an Offer". Set your price, delivery time, and add a cover letter explaining why you\'re the best fit.',
        order: 2,
      ),
      FAQItem(
        id: 'default4',
        question: 'How do I change my profile picture?',
        answer:
            'Go to Profile screen and tap the camera icon on your avatar. Select an image from your gallery and it will be uploaded.',
        order: 3,
      ),
      FAQItem(
        id: 'default5',
        question: 'Is my payment information secure?',
        answer:
            'Yes! All payment information is encrypted and stored securely. We use industry-standard security protocols to protect your data.',
        order: 4,
      ),
      FAQItem(
        id: 'default6',
        question: 'How do I contact a provider?',
        answer:
            'On any need detail screen, tap the chat icon (💬) to start a conversation with the provider. You can discuss details and negotiate.',
        order: 5,
      ),
      FAQItem(
        id: 'default7',
        question: 'What is the Buyer/Customer Mode?',
        answer:
            'When enabled, you see needs as a buyer/customer. When disabled, you see the provider/fulfiller view. You can toggle this in Settings.',
        order: 6,
      ),
      FAQItem(
        id: 'default8',
        question: 'How does the urgency level work?',
        answer:
            'Low = Flexible timeline, no rush. Medium = Needed within a few days. High = Needed as soon as possible. This helps providers prioritize.',
        order: 7,
      ),
    ]);

    setState(() {});
  }

  Future<void> _saveFAQToFirebase(FAQItem item, {bool isEdit = false}) async {
    try {
      final ref = FirebaseDatabase.instance.ref().child('faqs');

      if (isEdit && item.id.isNotEmpty && !item.id.startsWith('default')) {
        await ref.child(item.id).update({
          'question': item.question,
          'answer': item.answer,
          'order': item.order,
        });
      } else if (isEdit && item.id.startsWith('default')) {
        final newRef = ref.push();
        await newRef.set({
          'question': item.question,
          'answer': item.answer,
          'order': _faqItems.length,
        });
        _faqItems.removeWhere((i) => i.id == item.id);
      } else {
        await ref.push().set({
          'question': item.question,
          'answer': item.answer,
          'order': _faqItems.length,
        });
      }

      await _loadFAQs();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving FAQ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteFAQ(String id) async {
    if (id.startsWith('default')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default FAQs cannot be deleted.'),
          backgroundColor: AppColors.urgentMedium,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await FirebaseDatabase.instance.ref().child('faqs').child(id).remove();

      await _loadFAQs();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FAQ deleted successfully.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting FAQ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddEditDialog({FAQItem? item}) {
    final bool isEdit = item != null;
    _questionController.text = isEdit ? item!.question : '';
    _answerController.text = isEdit ? item!.answer : '';
    _editingItem = item;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit FAQ' : 'Add New FAQ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _questionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  hintText: 'Enter the FAQ question...',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _answerController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  hintText: 'Enter the detailed answer...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final question = _questionController.text.trim();
              final answer = _answerController.text.trim();

              if (question.isEmpty || answer.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill both fields.'),
                    backgroundColor: AppColors.urgentMedium,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              final newItem = FAQItem(
                id: isEdit
                    ? _editingItem!.id
                    : 'temp_${DateTime.now().millisecondsSinceEpoch}',
                question: question,
                answer: answer,
                order: isEdit ? _editingItem!.order : _faqItems.length,
              );

              await _saveFAQToFirebase(newItem, isEdit: isEdit);
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.background : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDarkMode ? AppColors.surface : Colors.white,
        title: const Text('Help & FAQs'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_isAdminMode)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _showAddEditDialog(),
              tooltip: 'Add FAQ',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFAQs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _faqItems.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _faqItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _faqItems[index];
                    return FAQCard(
                      item: item,
                      isDarkMode: isDarkMode,
                      isAdmin: _isAdminMode,
                      onEdit: () => _showAddEditDialog(item: item),
                      onDelete: () => _deleteFAQ(item.id),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    final c = context.palette;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.surface,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            child: Icon(
              Icons.help_outline_rounded,
              size: 48,
              color: c.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No FAQs Available',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for help articles.',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// FAQ Model
// ----------------------------------------------------------------------------

class FAQItem {
  final String id;
  final String question;
  final String answer;
  final int order;

  FAQItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.order,
  });
}

// ----------------------------------------------------------------------------
// FAQ Card Widget
// ----------------------------------------------------------------------------

class FAQCard extends StatefulWidget {
  final FAQItem item;
  final bool isDarkMode;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FAQCard({
    super.key,
    required this.item,
    required this.isDarkMode,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<FAQCard> createState() => _FAQCardState();
}

class _FAQCardState extends State<FAQCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final Color surfaceColor =
        widget.isDarkMode ? AppColors.surface : Colors.white;
    final Color textColor =
        widget.isDarkMode ? AppColors.textPrimary : Colors.black87;
    final Color subTextColor =
        widget.isDarkMode ? AppColors.textSecondary : Colors.black54;
    final Color borderColor =
        widget.isDarkMode ? AppColors.border : const Color(0xFFE2E8F0);
    final c = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            title: Text(
              widget.item.question,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    color: AppColors.primaryLight,
                    onPressed: widget.onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: AppColors.urgentHigh,
                    onPressed: widget.onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: c.textTertiary,
                ),
              ],
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.item.answer,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
