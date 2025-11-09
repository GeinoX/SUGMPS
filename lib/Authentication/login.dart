import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugmps/core/routes/routes.dart';
import '../services/auth_service.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _matriculeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  String? matricule;
  String? password;

  @override
  void dispose() {
    _matriculeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
    BuildContext context,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: MediaQuery.of(context).size.width * 0.04,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF3C3889),
        size: MediaQuery.of(context).size.width * 0.06,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF3C3889), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.04,
        vertical: MediaQuery.of(context).size.height * 0.02,
      ),
    );
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final authService = AuthService(baseUrl: AppRoutes.url);
      final data = await authService.login(
        schoolEmail: matricule!,
        password: password!,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', data['access']);
      await prefs.setString('refreshToken', data['refresh']);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.homepage);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: screenWidth * 0.9,
              constraints: BoxConstraints(maxWidth: 400),
              margin: EdgeInsets.all(screenWidth * 0.05),
              padding: EdgeInsets.all(screenWidth * 0.06),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.08,
                        color: const Color(0xFF3C3889),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      "Sign in to continue",
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),

                    // School Email input
                    TextFormField(
                      controller: _matriculeController,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.04,
                      ),
                      decoration: _inputDecoration(
                        "School Email",
                        Icons.email,
                        context,
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? "Enter school email"
                                  : null,
                      onSaved: (value) => matricule = value,
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    // Password input
                    TextFormField(
                      controller: _passwordController,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.04,
                      ),
                      decoration: _inputDecoration(
                        "Password",
                        Icons.lock,
                        context,
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Enter password";
                        }
                        if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                      onSaved: (value) => password = value,
                    ),
                    SizedBox(height: screenHeight * 0.04),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      child:
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3C3889),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: screenHeight * 0.02,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.045,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.registration,
                            );
                          },
                          child: Text(
                            "Register",
                            style: TextStyle(
                              color: const Color(0xFF3C3889),
                              fontWeight: FontWeight.w600,
                              fontSize: screenWidth * 0.035,
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
      ),
    );
  }
}
