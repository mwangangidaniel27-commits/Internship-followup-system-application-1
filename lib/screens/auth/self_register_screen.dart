import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class SelfRegisterScreen extends StatefulWidget {
  const SelfRegisterScreen({super.key});

  @override
  State<SelfRegisterScreen> createState() => _SelfRegisterScreenState();
}

class _SelfRegisterScreenState extends State<SelfRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _departmentController = TextEditingController();
  final _titleController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _role = 'student';
  String _supervisorType = 'university';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _departmentController.dispose();
    _titleController.dispose();
    _studentIdController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.registerUserPendingApproval(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _role,
      supervisorType: _supervisorType,
      department: _departmentController.text.trim(),
      title: _titleController.text.trim(),
      studentId: _studentIdController.text.trim(),
      companyName: _companyNameController.text.trim(),
      companyAddress: _companyAddressController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registration Submitted'),
          content: const Text(
            'Your account has been created and is pending admin approval. '
            'You will be able to sign in after approval.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authProvider.errorMessage ?? 'Registration failed'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = _role == 'student';
    final isSupervisor = _role == 'supervisor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Self Registration'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'I am registering as'),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _role = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (isSupervisor)
                  DropdownButtonFormField<String>(
                    value: _supervisorType,
                    decoration: const InputDecoration(labelText: 'Supervisor Type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'university',
                        child: Text('University Supervisor'),
                      ),
                      DropdownMenuItem(
                        value: 'company',
                        child: Text('Company Supervisor'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _supervisorType = value;
                      });
                    },
                  ),
                if (isSupervisor) const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _departmentController,
                  decoration: const InputDecoration(labelText: 'Department'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                if (isStudent)
                  TextFormField(
                    controller: _studentIdController,
                    decoration: const InputDecoration(labelText: 'Student ID'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                if (isStudent) const SizedBox(height: 12),
                if (isSupervisor)
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title (Optional)'),
                  ),
                if (isSupervisor) const SizedBox(height: 12),
                TextFormField(
                  controller: _companyNameController,
                  decoration: InputDecoration(
                    labelText: isStudent
                        ? 'Company Name (Optional)'
                        : _supervisorType == 'company'
                            ? 'Company Name'
                            : 'Affiliated Institution (Optional)',
                  ),
                  validator: (value) {
                    if (isSupervisor &&
                        _supervisorType == 'company' &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Company name is required for company supervisors';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyAddressController,
                  decoration:
                      const InputDecoration(labelText: 'Company Address (Optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _submit,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Submit for Admin Approval'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
