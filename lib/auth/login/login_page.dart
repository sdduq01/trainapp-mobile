import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../register/register_page.dart';

const _blue = Color(0xFF1565C0);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService  = AuthService();

  bool _isLoading = false;
  bool _obscure   = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await _authService.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Credenciales inválidas');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 56),

              // ── Logo ────────────────────────────────────
              Image.asset(
                'assets/icon/logo.jpeg',
                width: 210,
              ),
              const SizedBox(height: 12),

              // ── Lema ────────────────────────────────────
              const Text(
                'Stay strong, Stay stoic!!!!!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: _blue,
                  letterSpacing: 0.4,
                ),
              ),

              const SizedBox(height: 48),

              // ── Divisor ──────────────────────────────────
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Inicia sesión',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 24),

              // ── Email ────────────────────────────────────
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  label: 'Email',
                  icon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // ── Contraseña ───────────────────────────────
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: _inputDecoration(
                  label: 'Contraseña',
                  icon: Icons.lock_outlined,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              // ── Error ────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 28),

              // ── Botón login ──────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Iniciar sesión',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Registro ─────────────────────────────────
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                ),
                child: const Text(
                  '¿No tienes cuenta? Regístrate',
                  style: TextStyle(color: _blue),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _blue),
      labelStyle: const TextStyle(color: Colors.black54),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _blue, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}
