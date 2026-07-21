import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/push_notification_service.dart';

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

  Future<void> _showForgotPasswordDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final emailCtrl = TextEditingController(text: _email.text.trim());
    String? fieldError;
    var sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submit() async {
              final trimmed = emailCtrl.text.trim();
              if (trimmed.isEmpty) {
                setDialogState(() => fieldError = 'Please enter your email.');
                return;
              }
              if (!trimmed.contains('@')) {
                setDialogState(
                  () => fieldError = 'Please enter a valid email address.',
                );
                return;
              }
              setDialogState(() {
                sending = true;
                fieldError = null;
              });
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: trimmed,
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Check your email for a reset link.'),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                setDialogState(() {
                  sending = false;
                  if (e.code == 'invalid-email') {
                    fieldError = 'Please enter a valid email address.';
                  } else if (e.code == 'user-not-found') {
                    fieldError = 'No account found with this email.';
                  } else {
                    fieldError = 'Could not send reset email. Try again.';
                  }
                });
              } catch (_) {
                setDialogState(() {
                  sending = false;
                  fieldError = 'Could not send reset email. Try again.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Reset password'),
              content: SingleChildScrollView(
                child: TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    errorText: fieldError,
                  ),
                  onChanged: (_) =>
                      setDialogState(() => fieldError = null),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: sending ? null : submit,
                  child: sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Reset Link'),
                ),
              ],
            );
          },
        );
      },
    );
    emailCtrl.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLoginMode) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());
        if (mounted) {
          final route =
              await PushNotificationService.instance.routeAfterLogin();
          await PushNotificationService.instance.onUserSignedIn();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, route);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PushNotificationService.instance.processPendingNotification();
          });
        }
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());
        if (mounted) Navigator.pushReplacementNamed(context, '/sign_up_confirmed');
      }
    } catch (e) {
      if (mounted) setState(() => _error = _getErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
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
                    Image.asset(
                      'assets/icon/icon.png',
                      height: 140,
                      semanticLabel: 'Peepl',
                    ),
                    SizedBox(height: 48),
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
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              _loading ? null : _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1565C0),
                            disabledForegroundColor: const Color(0x801565C0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF1565C0),
                              shadows: [
                                Shadow(
                                  color: Color(0xE6FFFFFF),
                                  blurRadius: 6,
                                ),
                                Shadow(
                                  color: Color(0xB3FFFFFF),
                                  blurRadius: 2,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
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