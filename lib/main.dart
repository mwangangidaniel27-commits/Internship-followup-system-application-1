import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// Import providers
import 'providers/auth_provider.dart';
import 'providers/student_provider.dart';

// Import screens
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/self_register_screen.dart';
import 'screens/student/student_dashboard_screen.dart';
import 'screens/student/log_form_screen.dart';
import 'screens/student/log_history_screen.dart';
import 'screens/student/feedback_screen.dart';
import 'screens/student/profile_screen.dart';
import 'screens/student/document_upload_screen.dart';
import 'screens/supervisor/supervisor_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/assign_supervisor_screen.dart'; // NEW
import 'screens/student/edit_profile_screen.dart';
import 'screens/student/student_report_screen.dart';
import 'screens/reporting/reports_screen.dart';

// Import routes
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
      ],
      child: MaterialApp(
        title: 'Internship Follow-Up System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: const Color(0xFF2563EB),
          scaffoldBackgroundColor: const Color(0xFFF9FAFB),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
            headlineMedium: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
            bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF374151)),
            bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.splash:
              return MaterialPageRoute(builder: (_) => const SplashScreen());
            case AppRoutes.login:
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case AppRoutes.selfRegister:
              return MaterialPageRoute(builder: (_) => const SelfRegisterScreen());
            case AppRoutes.studentDashboard:
              return MaterialPageRoute(
                  builder: (_) => const StudentDashboardScreen());
            case AppRoutes.supervisorDashboard:
              return MaterialPageRoute(
                  builder: (_) => const SupervisorDashboardScreen());
            case AppRoutes.adminDashboard:
              return MaterialPageRoute(
                  builder: (_) => const AdminDashboardScreen());
            case AppRoutes.logForm:
              return MaterialPageRoute(builder: (_) => const LogFormScreen());
            case AppRoutes.logHistory:
              return MaterialPageRoute(
                  builder: (_) => const LogHistoryScreen());
            case AppRoutes.feedback:
              return MaterialPageRoute(
                  builder: (_) => const FeedbackScreen());
            case AppRoutes.profile:
              return MaterialPageRoute(
                  builder: (_) => const ProfileScreen());
            case AppRoutes.documentUpload:
              return MaterialPageRoute(
                  builder: (_) => const DocumentUploadScreen());
            case AppRoutes.userManagement:
              return MaterialPageRoute(
                  builder: (_) => const UserManagementScreen());

            case AppRoutes.reports:
              return MaterialPageRoute(
                  builder: (_) => const ReportsScreen());

            case AppRoutes.studentReport:
              return MaterialPageRoute(
                  builder: (_) => const StudentReportScreen());

            case AppRoutes.editProfile:
              return MaterialPageRoute(
                  builder: (_) => const EditProfileScreen());

            // NEW — Assign Supervisor
            case AppRoutes.assignSupervisor:
              return MaterialPageRoute(
                  builder: (_) => const AssignSupervisorScreen());

            default:
              return MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: Center(
                    child: Text('No route defined for ${settings.name}'),
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}