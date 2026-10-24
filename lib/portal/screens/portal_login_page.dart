import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../core/widgets/trainapp_brand.dart';
import '../../trainer/services/user_directory_service.dart';

/// Ingreso al portal con la misma cuenta de TrainApp, o creación de una
/// cuenta nueva (para dueños de gimnasio que no usan la app).
class PortalLoginPage extends StatefulWidget {
  const PortalLoginPage({super.key});

  @override
  State<PortalLoginPage> createState() => _PortalLoginPageState();
}

class _PortalLoginPageState extends State<PortalLoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _registering = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  static String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email o contraseña incorrectos.';
      case 'invalid-email':
        return 'El email no es válido.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese email. Ingresa con tu contraseña.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e intenta de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet.';
      default:
        return 'Error: ${e.message ?? e.code}';
    }
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Escribe tu email y contraseña.');
      return;
    }
    if (_registering && password != _confirmCtrl.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      if (_registering) {
        await AuthService().signUpWithEmail(email: email, password: password);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          // Necesario para que lo puedan invitar por email.
          await UserDirectoryService()
              .ensureDirectoryEntry(uid, email)
              .catchError((_) {});
        }
      } else {
        await AuthService().signInWithEmail(email: email, password: password);
      }
      // PortalApp cambia de pantalla solo al detectar la sesión.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _authMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Escribe tu email para enviarte el enlace.');
      return;
    }
    try {
      await AuthService().sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Te enviamos un enlace a $email.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _authMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const TrainAppBrand(markSize: 48),
                const SizedBox(height: 8),
                const Text(
                  'Portal de gimnasios',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _registering ? 'Crear cuenta' : 'Ingresar',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _registering
                                ? 'Con esta cuenta también podrás usar la app TrainApp.'
                                : 'Usa la misma cuenta de la app TrainApp.',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(labelText: 'Email'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            autofillHints: [
                              _registering
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            onSubmitted: _registering ? null : (_) => _submit(),
                            decoration:
                                const InputDecoration(labelText: 'Contraseña'),
                          ),
                          if (_registering) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmCtrl,
                              obscureText: true,
                              onSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                  labelText: 'Confirmar contraseña'),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: TextStyle(color: Colors.red.shade700)),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48)),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(_registering ? 'Crear cuenta' : 'Ingresar'),
                          ),
                          if (!_registering)
                            TextButton(
                              onPressed: _loading ? null : _forgotPassword,
                              child: const Text('Olvidé mi contraseña'),
                            ),
                          const Divider(height: 24),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() {
                                      _registering = !_registering;
                                      _error = null;
                                    }),
                            child: Text(_registering
                                ? '¿Ya tienes cuenta? Ingresa'
                                : '¿No tienes cuenta? Créala'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
