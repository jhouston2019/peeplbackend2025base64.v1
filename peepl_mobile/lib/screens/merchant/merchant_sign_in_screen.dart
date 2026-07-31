import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/peepl_app_tokens.dart';

import '../../widgets/merchant/merchant_screen_scaffold.dart';
import '../../widgets/merchant/peepl_merchant_tokens.dart';

class MerchantSignInScreen extends StatefulWidget {
  const MerchantSignInScreen({super.key});

  @override
  State<MerchantSignInScreen> createState() => _MerchantSignInScreenState();
}

class _MerchantSignInScreenState extends State<MerchantSignInScreen>
    with SingleTickerProviderStateMixin {
  static const Color _blue = PeeplMerchantTokens.accentBlue;

  late final TabController _tabController;

  final _signInFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _signInEmailCtrl = TextEditingController();
  final _signInPassCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _registerEmailCtrl = TextEditingController();
  final _registerPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _loading = false;
  bool _obscureSignInPass = true;
  bool _obscureRegisterPass = true;
  bool _obscureConfirmPass = true;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailCtrl.dispose();
    _signInPassCtrl.dispose();
    _businessNameCtrl.dispose();
    _registerEmailCtrl.dispose();
    _registerPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : _blue,
      ),
    );
  }

  String _authErrorMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' => 'No account found with this email.',
      'wrong-password' || 'invalid-credential' =>
        'Incorrect email or password.',
      'email-already-in-use' => 'An account already exists with this email.',
      'weak-password' => 'Password must be at least 8 characters.',
      'invalid-email' => 'Please enter a valid email address.',
      _ => e.message ?? 'Authentication failed.',
    };
  }

  Future<void> _signIn() async {
    if (!_signInFormKey.currentState!.validate() || _loading) return;

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _signInEmailCtrl.text.trim(),
        password: _signInPassCtrl.text,
      );
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/merchant_portal',
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_authErrorMessage(e));
    } catch (_) {
      _showSnackBar('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _signInEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Enter your email address first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackBar(
        'Password reset email sent. Check your inbox.',
        isError: false,
      );
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Could not send reset email.');
    } catch (_) {
      _showSnackBar('Could not send reset email. Please try again.');
    }
  }

  Future<void> _createAccount() async {
    if (!_registerFormKey.currentState!.validate() || _loading) return;

    if (!_termsAccepted) {
      _showSnackBar('Please agree to Peepl\'s advertising terms.');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _registerEmailCtrl.text.trim(),
        password: _registerPassCtrl.text,
      );

      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(cred.user!.uid)
          .set({
        'businessName': _businessNameCtrl.text.trim(),
        'email': _registerEmailCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'tier': 'standard',
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/merchant_setup_step1',
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_authErrorMessage(e));
    } catch (_) {
      _showSnackBar('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: PeeplMerchantTokens.heroGradient(),
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBranding(),
                const SizedBox(height: 28),
                _buildFormCard(),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (_) => false,
                  ),
                  child: const Text(
                    'Back to Peepl',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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

  Widget _buildBranding() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/icon/icon.png',
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.store, color: PeeplAppTokens.textPrimary, size: 40),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Merchant Portal',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      decoration: BoxDecoration(
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: PeeplAppTokens.textPrimary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: _blue,
            unselectedLabelColor: PeeplAppTokens.textSecondary,
            indicatorColor: _blue,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            tabs: const [
              Tab(text: 'Sign In'),
              Tab(text: 'Create Account'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 420,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSignInTab(),
                _buildCreateAccountTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInTab() {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _signInEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _field('Email', Icons.email_outlined),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _signInPassCtrl,
            obscureText: _obscureSignInPass,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _signIn(),
            decoration: _field('Password', Icons.lock_outlined).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignInPass
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: PeeplAppTokens.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscureSignInPass = !_obscureSignInPass),
              ),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter your password' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading ? null : _forgotPassword,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: _blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _primaryButton(label: 'Sign In', onPressed: _signIn),
        ],
      ),
    );
  }

  Widget _buildCreateAccountTab() {
    return Form(
      key: _registerFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _businessNameCtrl,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: _field('Business name', Icons.store_outlined),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter your business name'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _registerEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _field('Email', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _registerPassCtrl,
              obscureText: _obscureRegisterPass,
              textInputAction: TextInputAction.next,
              decoration: _field('Password', Icons.lock_outlined).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureRegisterPass
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: PeeplAppTokens.textSecondary,
                  ),
                  onPressed: () => setState(
                      () => _obscureRegisterPass = !_obscureRegisterPass),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a password';
                if (v.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPassCtrl,
              obscureText: _obscureConfirmPass,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _createAccount(),
              decoration:
                  _field('Confirm password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPass
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: PeeplAppTokens.textSecondary,
                  ),
                  onPressed: () => setState(
                      () => _obscureConfirmPass = !_obscureConfirmPass),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirm your password';
                if (v != _registerPassCtrl.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _termsAccepted,
                    activeColor: _blue,
                    onChanged: (v) =>
                        setState(() => _termsAccepted = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _termsAccepted = !_termsAccepted),
                    child: Text(
                      'I agree to Peepl\'s advertising terms',
                      style: TextStyle(
                        fontSize: 13,
                        color: PeeplAppTokens.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _primaryButton(label: 'Create Account', onPressed: _createAccount),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: PeeplAppTokens.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: _loading ? null : onPressed,
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PeeplAppTokens.textPrimary,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  InputDecoration _field(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: PeeplAppTokens.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _blue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }
}
