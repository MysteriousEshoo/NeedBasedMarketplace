import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import 'main_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignupMode = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// 🔐 EMAIL/PASSWORD CORE SYSTEM
  void _processEmailAuthentication() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      if (_isSignupMode) {
        UserCredential credential = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await credential.user?.updateDisplayName(_nameController.text.trim());
        await credential.user?.reload();

        await firestore.collection('users').doc(credential.user?.uid).set({
          'uid': credential.user?.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'isSellerMode': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      if (!mounted) return;
      _navigateToApplicationShell();
    } catch (e) {
      _displayFeedbackMessage('⚠️ Authentication Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 🌐 GOOGLE AUTH AUTOMATED PIPELINE
  void _processGoogleSignPipeline() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        final firestore = FirebaseFirestore.instance;
        final userDoc = await firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          await firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': user.displayName ?? 'Google Account User',
            'email': user.email,
            'isSellerMode': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (!mounted) return;
        _navigateToApplicationShell();
      }
    } catch (e) {
      _displayFeedbackMessage(
          '⚠️ Google Authentication failure: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToApplicationShell() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _displayFeedbackMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.urgentHigh),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color currentTextPrimary =
        isDark ? AppColors.textPrimary : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight))
          : SafeArea(
              child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSignupMode ? 'Create Account' : 'Welcome Back',
                        style: TextStyle(
                            color: currentTextPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 32),

                      if (_isSignupMode) ...[
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(color: currentTextPrimary),
                          decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_rounded)),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Please enter your name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: currentTextPrimary),
                        decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_rounded)),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Please enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(color: currentTextPrimary),
                        decoration: const InputDecoration(
                            labelText: 'Security Password',
                            prefixIcon: Icon(Icons.lock_rounded)),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16))),
                          onPressed: _processEmailAuthentication,
                          child: Text(
                            _isSignupMode ? 'SIGN UP' : 'LOGIN',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ FIXED: Google Icon
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side:
                                const BorderSide(color: AppColors.primaryLight),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _processGoogleSignPipeline,
                          icon: const Icon(
                            Icons.g_mobiledata, // ✅ FIXED: Removed _rounded
                            size: 32,
                            color: AppColors.primaryLight,
                          ),
                          label: Text(
                            _isSignupMode
                                ? 'Signup with Google'
                                : 'Login with Google',
                            style: TextStyle(
                                color: currentTextPrimary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      TextButton(
                        onPressed: () =>
                            setState(() => _isSignupMode = !_isSignupMode),
                        child: Text(
                          _isSignupMode
                              ? 'Already have an account? Login here'
                              : "Don't have an account? Sign up here",
                          style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
    );
  }
}
