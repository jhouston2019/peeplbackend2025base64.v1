import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MerchantSignInScreen extends StatefulWidget {
  const MerchantSignInScreen({super.key});

  @override
  State<MerchantSignInScreen> createState() => _MerchantSignInScreenState();
}

class _MerchantSignInScreenState extends State<MerchantSignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure = true;
  bool _isRegister = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final UserCredential cred;
      if (_isRegister) {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      } else {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      }

      // Ensure merchant flag on the user document.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({'isMerchant': true}, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/merchant_portal',
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'user-not-found' => 'No account found with this email.',
        'wrong-password' || 'invalid-credential' =>
          'Incorrect email or password.',
        'email-already-in-use' =>
          'An account already exists with this email.',
        'weak-password' => 'Password must be at least 6 characters.',
        'invalid-email' => 'Please enter a valid email address.',
        _ => e.message ?? 'Authentication failed.',
      };
      if (mounted) {
        setState(() {
          _loading = false;
          _error = msg;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'An error occurred. Please try again.';
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark overlay for depth.
            Container(color: Colors.black.withValues(alpha: 0.32)),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 48, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBranding(),
                    const SizedBox(height: 40),
                    _buildFormCard(),
                    const SizedBox(height: 20),
                    _buildToggleLink(),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/login'),
                        child: const Text(
                          'Back to Peepl user sign in',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        const Text(
          'peepl',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.6),
            ),
          ),
          child: const Text(
            'FOR MERCHANTS',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isRegister ? 'Create Merchant Account' : 'Merchant Sign In',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 22),

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _field('Email address', Icons.email_outlined),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your email' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: _field('Password', Icons.lock_outlined).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[600],
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter your password' : null,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isRegister ? 'Create Account' : 'Sign In',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleLink() {
    return TextButton(
      onPressed: () => setState(() {
        _isRegister = !_isRegister;
        _error = null;
      }),
      child: Text(
        _isRegister
            ? 'Already have an account? Sign in'
            : 'New merchant? Create account',
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  InputDecoration _field(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }
}
