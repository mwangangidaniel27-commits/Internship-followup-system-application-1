import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../routes/app_routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
      ),
      body: Consumer<StudentProvider>(
        builder: (context, provider, child) {
          if (provider.student == null) {
            return const Center(child: Text('No profile data'));
          }

          final student = provider.student!;
          final authProvider = context.watch<AuthProvider>();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header with Avatar
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        student.fullName ?? 'Student',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.studentId,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFFBFDBFE),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Personal Information Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(Icons.email, 'Email', authProvider.user?.email ?? 'N/A'),
                          const Divider(height: 24),
                          _buildInfoRow(Icons.phone, 'Phone', 'Not set'),
                          const Divider(height: 24),
                          _buildInfoRow(Icons.school, 'Department', student.department),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Internship Details Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Internship Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(Icons.business, 'Company', student.companyName ?? 'Not assigned'),
                          const Divider(height: 24),
                          _buildInfoRow(Icons.location_on, 'Location', student.companyAddress ?? 'Not set'),
                          const Divider(height: 24),
                          _buildInfoRow(Icons.person, 'Supervisor', student.supervisorName ?? 'Not assigned'),
                          const Divider(height: 24),
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Start Date',
                            student.internshipStartDate != null
                                ? DateFormat('MMM d, yyyy').format(student.internshipStartDate!)
                                : 'Not set',
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            Icons.event,
                            'End Date',
                            student.internshipEndDate != null
                                ? DateFormat('MMM d, yyyy').format(student.internshipEndDate!)
                                : 'Not set',
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(Icons.timelapse, 'Duration', '${student.totalWeeks} weeks'),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Account Status Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                              const SizedBox(width: 12),
                              const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w500)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  student.status.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF059669),
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

                const SizedBox(height: 24),

                // Logout Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          await context.read<AuthProvider>().signOut();
                          context.read<StudentProvider>().clearData();
                          
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.login,
                              (route) => false,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}