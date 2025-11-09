import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sugmps/core/routes/routes.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart';

class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  State<Registration> createState() => _RegistrationState();
}

class _RegistrationState extends State<Registration> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _schoolEmailController = TextEditingController();
  final TextEditingController _otherEmailController = TextEditingController();
  final TextEditingController _matriculeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _programController = TextEditingController();

  String? name;
  String? schoolEmail;
  String? otherEmail;
  String? matricule;
  int? phone;
  String? password;
  String? confirmPassword;
  String? gender;
  String? program;
  File? profileImage;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _schoolEmailController.dispose();
    _otherEmailController.dispose();
    _matriculeController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _programController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        profileImage = File(pickedFile.path);
      });
    }
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (profileImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a profile image"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final authService = AuthService(baseUrl: AppRoutes.url);

    try {
      await authService.register(
        name: name!,
        schoolEmail: schoolEmail!,
        otherEmail: otherEmail!,
        phone: phone!,
        matricule: matricule!,
        password: password!,
        gender: gender!,
        program: program!,
        profileImage: profileImage!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushNamed(context, AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
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
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              width: screenWidth * 0.9,
              constraints: BoxConstraints(maxWidth: 500),
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
                      "Create Account",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.08,
                        color: const Color(0xFF3C3889),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    // Profile Image
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: screenWidth * 0.1,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            profileImage != null
                                ? FileImage(profileImage!)
                                : null,
                        child:
                            profileImage == null
                                ? Icon(
                                  Icons.camera_alt,
                                  color: Colors.grey.shade600,
                                  size: screenWidth * 0.08,
                                )
                                : null,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Text(
                      "Tap to add profile photo",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.04,
                      ),
                      decoration: _inputDecoration(
                        "Full Name",
                        Icons.person,
                        context,
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? "Enter your name"
                                  : null,
                      onSaved: (value) => name = value,
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    // School Email
                    TextFormField(
                      controller: _schoolEmailController,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.04,
                      ),
                      decoration: _inputDecoration(
                        "School Email",
                        Icons.email,
                        context,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Enter school email";
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return "Enter a valid email";
                        }
                        return null;
                      },
                      onSaved: (value) => schoolEmail = value,
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    // Other Email
                    TextFormField(
                      controller: _otherEmailController,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.04,
                      ),
                      decoration: _inputDecoration(
                        "Other Email",
                        Icons.alternate_email,
                        context,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Enter other email";
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return "Enter a valid email";
                        }
                        return null;
                      },
                      onSaved: (value) => otherEmail = value,
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    // Matricule Number
                    TextFormField(
                      controller: _matriculeController,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.04,
                      ),
                      decoration: _inputDecoration(
                        "Matricule Number",
                        Icons.badge,
                        context,
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? "Enter matricule"
                                  : null,
                      onSaved: (value) => matricule = value,
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    // Program
                    TextFormField(
                      controller: _programController,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.04,
                      ),
                      decoration: _inputDecoration(
                        "Program",
                        Icons.school,
                        context,
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? "Enter your program"
                                  : null,
                      onSaved: (value) => program = value,
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    // Gender Dropdown
                    DropdownButtonFormField<String>(
                      dropdownColor: Colors.white,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.04,
                      ),
                      decoration: _inputDecoration(
                        "Select Gender",
                        Icons.people,
                        context,
                      ),
                      value: gender,
                      items: const [
                        DropdownMenuItem(value: "M", child: Text("Male")),
                        DropdownMenuItem(value: "F", child: Text("Female")),
                        DropdownMenuItem(value: "Other", child: Text("Other")),
                      ],
                      onChanged: (value) => setState(() => gender = value),
                      validator:
                          (value) =>
                              value == null ? "Please choose gender" : null,
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.04,
                      ),
                      decoration: _inputDecoration(
                        "Phone Number",
                        Icons.phone,
                        context,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return "Enter your contact";
                        if (!RegExp(r'^\d{8,15}$').hasMatch(value)) {
                          return "Enter a valid phone number";
                        }
                        return null;
                      },
                      onSaved: (value) => phone = int.tryParse(value ?? ''),
                    ),
                    SizedBox(height: screenHeight * 0.02),

                    // Password
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
                    SizedBox(height: screenHeight * 0.02),

                    // Confirm Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: screenWidth * 0.04,
                      ),
                      decoration: _inputDecoration(
                        "Confirm Password",
                        Icons.lock_reset,
                        context,
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Confirm your password";
                        }
                        if (value != _passwordController.text) {
                          return "Passwords do not match";
                        }
                        return null;
                      },
                      onSaved: (value) => confirmPassword = value,
                    ),
                    SizedBox(height: screenHeight * 0.04),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      child:
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                onPressed: _register,
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
                                  "Register",
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.045,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
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
