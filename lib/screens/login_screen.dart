import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password'), backgroundColor: const Color(0xFFE53935)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.login(username, password);

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Login failed'), backgroundColor: const Color(0xFFE53935)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection error. Please try again.'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/');
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 80),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/login_icon_1.png', width: 80, height: 80, fit: BoxFit.contain),
                    const SizedBox(width: 20),
                    Image.asset('assets/images/login_icon_2.png', width: 80, height: 80, fit: BoxFit.contain),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 20, left: 32, right: 32),
                child: Text('ひさしぶり!', style: TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 32, right: 32, bottom: 10),
                child: Text("It's nice to see you back", style: TextStyle(color: Colors.white70, fontSize: 15), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 20),
              _buildInputField(controller: _usernameController, hint: 'Username', iconPath: 'assets/images/username_icon.png'),
              _buildPasswordField(
                controller: _passwordController,
                hint: 'Password',
                iconPath: 'assets/images/password_icon.png',
                obscureText: _obscurePassword,
                onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 0, right: 33),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Forgot password feature coming soon'), backgroundColor: const Color(0xFFE53935)),
                      );
                    },
                    child: const Text('Forget Your Password?', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(40, 32, 40, 0),
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Log in', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account yet?", style: TextStyle(color: Colors.white70, fontSize: 15)),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: const Text('Sign up', style: TextStyle(color: Color(0xFFE53935), fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required String iconPath,
  }) {
    return Container(
      height: 60,
      margin: const EdgeInsets.fromLTRB(24, 14, 24, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Image.asset(iconPath, width: 24, height: 24),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
              maxLines: 1,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white70),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required String iconPath,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return Container(
      height: 60,
      margin: const EdgeInsets.fromLTRB(24, 14, 24, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Image.asset(iconPath, width: 24, height: 24),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
              maxLines: 1,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white70),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: Colors.white70,
              ),
              onPressed: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}
