import 'package:flutter/material.dart';
import 'main_shell.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_loading_button.dart';
import 'home_screen.dart';

/// Screen 1 — Premium dual authentication interface.
///
/// A single screen hosts both Login and Sign Up via an animated segmented
/// tab control. Inputs use floating labels, leading icons and live
/// validation styling. Social and phone auth are offered as custom buttons.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  bool get _isLogin => _tabController.index == 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, animation, __) => const MainShell(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBrandMark(),
              const SizedBox(height: 36),
              Text(
                _isLogin ? 'Welcome back' : 'Create your account',
                style: textTheme.displaySmall?.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Sign in to pick up where you left off.'
                    : 'Join thousands posting and fulfilling needs daily.',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              _buildSegmentedTabs(),
              const SizedBox(height: 28),
              _buildForm(),
              const SizedBox(height: 24),
              PrimaryLoadingButton(
                label: _isLogin ? 'Sign In' : 'Create Account',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 28),
              _buildDivider(),
              const SizedBox(height: 24),
              _buildSocialButtons(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Sections
  // --------------------------------------------------------------------------

  Widget _buildBrandMark() {
    return Row(
      children: [
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.glow,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Text(
          'NeedHub',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
        ),
      ],
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        tabs: const [
          Tab(text: 'Login'),
          Tab(text: 'Sign Up'),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Name field only appears in Sign Up mode, with a smooth reveal.
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _isLogin
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PremiumField(
                      controller: _nameController,
                      label: 'Full name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your name'
                          : null,
                    ),
                  ),
          ),
          _PremiumField(
            controller: _emailController,
            label: 'Email address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter your email';
              final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+').hasMatch(v);
              return ok ? null : 'Enter a valid email address';
            },
          ),
          const SizedBox(height: 16),
          _PremiumField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            validator: (v) => (v == null || v.length < 6)
                ? 'Password must be at least 6 characters'
                : null,
            suffix: IconButton(
              splashRadius: 20,
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          if (_isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or continue with',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () {},
          icon: const _GoogleGlyph(),
          label: const Text('Sign in with Google'),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () {},
          icon:
              const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
          label: const Text('Continue with phone number'),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Private helpers
// ----------------------------------------------------------------------------

/// A styled text field with a floating label, leading icon and live
/// validation borders, used across the auth form.
class _PremiumField extends StatelessWidget {
  const _PremiumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        suffixIcon: suffix,
      ),
    );
  }
}

/// A small multi-color "G" mark so the Google button feels authentic
/// without bundling external image assets.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
