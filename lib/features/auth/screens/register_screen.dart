import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final success = await auth.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      CustomSnackbar.showSuccess(context, 'Account created! Please sign in.');
      context.pop();
    } else {
      CustomSnackbar.showError(context, auth.errorMessage ?? 'Registration failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get Started',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create a new account on your Go backend',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'John Doe',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (v) => Validators.required(v, 'Name'),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'user@example.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'At least 6 characters',
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Sign Up',
                    isLoading: auth.isLoading,
                    onPressed: _submitRegister,
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
