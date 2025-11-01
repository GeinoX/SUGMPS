import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugmps/routes.dart';
import '../../services/auth_service.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _matriculeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? matricule;
  String? password;

  // Gradient for icons
  static const _iconGradient = LinearGradient(
    colors: [Color(0xFFE77B22), Color.fromARGB(255, 20, 3, 119)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void dispose() {
    _matriculeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: ShaderMask(
        shaderCallback: (bounds) => _iconGradient.createShader(bounds),
        child: Icon(icon, color: Colors.white),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blueAccent),
        borderRadius: BorderRadius.circular(8),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
    );
  }

  // Updated login function
  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    try {
      final authService = AuthService(baseUrl: AppRoutes.url);
      final data = await authService.login(
        schoolEmail: matricule!,
        password: password!,
      );

      // Store access and refresh tokens
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', data['access']);
      await prefs.setString('refreshToken', data['refresh']);

      // Redirect to main/dashboard page
      Navigator.pushReplacementNamed(context, AppRoutes.homepage);
    } catch (e) {
      // Show error to user
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF202020),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 330,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    "Login",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 25,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 25),
                  // Matricule input
                  TextFormField(
                    controller: _matriculeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("School Email", Icons.badge),
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? "Enter email"
                                : null,
                    onSaved: (value) => matricule = value,
                  ),
                  const SizedBox(height: 15),
                  // Password input
                  TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Password", Icons.lock),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Enter password";
                      }
                      if (value.length < 6) {
                        return "Password must be at least 6 chars";
                      }
                      return null;
                    },
                    onSaved: (value) => password = value,
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.25),
                      side: const BorderSide(color: Colors.black, width: 1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 100,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Login",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Don't have an account? Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don’t have an account? ",
                        style: TextStyle(color: Colors.white70),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.registration);
                        },
                        child: const Text(
                          "Register",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
