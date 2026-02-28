import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// Import providers
import 'providers/auth_provider.dart';

// Import screens
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard_screen.dart';
import 'screens/student/log_form_screen.dart';
import 'screens/student/log_history_screen.dart';
import 'screens/supervisor/supervisor_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

// Import routes
import 'routes/app_routes.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

// Global access to Supabase client
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Add other providers here as you create them
        // ChangeNotifierProvider(create: (_) => StudentProvider()),
        // ChangeNotifierProvider(create: (_) => SupervisorProvider()),
      ],
      child: MaterialApp(
        title: 'Internship Follow-Up System',
        debugShowCheckedModeBanner: false,
        
        // Theme configuration
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: const Color(0xFF2563EB), // Blue-600
          scaffoldBackgroundColor: const Color(0xFFF9FAFB), // Gray-50
          
          // AppBar theme
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          
          // Input decoration theme
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          
          // Button theme
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
          
          // Card theme
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
          ),
          
          // Text theme
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
            bodyLarge: TextStyle(
              fontSize: 16,
              color: Color(0xFF374151),
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        
        // Initial route
        initialRoute: AppRoutes.splash,
        
        // Route generation
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.splash:
              return MaterialPageRoute(builder: (_) => const SplashScreen());
            
            case AppRoutes.login:
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            
            case AppRoutes.studentDashboard:
              return MaterialPageRoute(builder: (_) => const StudentDashboardScreen());
            
            case AppRoutes.supervisorDashboard:
              return MaterialPageRoute(builder: (_) => const SupervisorDashboardScreen());
            
            case AppRoutes.adminDashboard:
              return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
            
            case AppRoutes.logForm:
              return MaterialPageRoute(builder: (_) => const LogFormScreen());
            
            case AppRoutes.logHistory:
              return MaterialPageRoute(builder: (_) => const LogHistoryScreen());
            
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