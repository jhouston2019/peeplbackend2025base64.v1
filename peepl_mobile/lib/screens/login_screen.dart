import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _isLoginMode = true;

  String _getErrorMessage(String error) {
    if (error.contains('user-not-found')) return 'No account found with this email address.';
    if (error.contains('wrong-password')) return 'Incorrect password. Please try again.';
    if (error.contains('email-already-in-use')) return 'An account already exists with this email.';
    if (error.contains('weak-password')) return 'Password should be at least 6 characters.';
    if (error.contains('invalid-email')) return 'Please enter a valid email address.';
    return 'An error occurred. Please try again.';
  }

  String _passwordResetErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      default:
        return 'Could not send reset email. Try again.';
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email address, then tap Forgot password again.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('If an account exists, we sent a reset link to your email.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _passwordResetErrorMessage(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not send reset email. Try again.';
      });
    }
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLoginMode) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());
      }
    } catch (e) {
      setState(() { _error = _getErrorMessage(e.toString()); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=2071&q=80'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.3)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    SizedBox(height: 80),
                    Text('Peepl', style: TextStyle(color: Color(0xFF1565C0), fontSize: 64, fontWeight: FontWeight.bold)),
                    SizedBox(height: 100),
                    Align(alignment: Alignment.centerLeft,
                      child: Text('Email Address', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w600))),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                      child: TextFormField(
                        controller: _email,
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || v.isEmpty ? 'Please enter your email' : !v.contains('@') ? 'Please enter a valid email' : null,
                      ),
                    ),
                    SizedBox(height: 32),
                    Align(alignment: Alignment.centerLeft,
                      child: Text('Password', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w600))),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                      child: TextFormField(
                        controller: _pass,
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                        obscureText: true,
                        validator: (v) => v == null || v.isEmpty ? 'Please enter your password' : v.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                    ),
                    if (_isLoginMode) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _sendPasswordReset,
                          child: Text('Forgot password?', style: TextStyle(color: Color(0xFF1565C0), fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ] else
                      SizedBox(height: 8),
                    SizedBox(height: 24),
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: TextStyle(color: Colors.white, fontSize: 14)),
                      ),
                    SizedBox(
                      width: double.infinity, height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _authenticate,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: _loading ? CircularProgressIndicator(color: Colors.white) : Text(_isLoginMode ? 'Log In' : 'Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    SizedBox(height: 30),
                    if (!_loading)
                      TextButton(
                        onPressed: () => setState(() { _isLoginMode = !_isLoginMode; _error = null; }),
                        child: Text(_isLoginMode ? "Don't have an account? Sign Up" : 'Already have an account? Log In',
                          style: TextStyle(color: Color(0xFF1565C0), fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }
}