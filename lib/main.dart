import 'package:finfit/billReminders.dart';
import 'package:finfit/customworkout.dart';
import 'package:finfit/expenseTracking.dart';
import 'package:finfit/financeAnalysis.dart';
import 'package:finfit/foodrecommend.dart'; // Contains FoodRecommender class
import 'package:finfit/incomeTracking.dart';
import 'package:finfit/financeHome.dart';
import 'package:finfit/nutritionpage.dart';
import 'package:finfit/splash_screen.dart';
import 'package:finfit/workoutpage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'loginpage.dart';
import 'signuppage.dart';
import 'homepage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => SplashScreen(),
        '/': (context) => LoginPage(),
        '/signup': (context) => SignUpPage(),
        '/home': (context) => HomePage(),
        '/nut': (context) => NutritionHomeScreen(),
        '/finance': (context) => FinanceHomeScreen(),
        '/workout': (context) => WorkoutHomePage(),
        '/income': (context) => IncomeTrackPage(),
        '/expense': (context) => ExpenseTrackerPage(),
        '/analysis': (context) => FinanceAnalysisPage(),
        '/bill': (context) => BillRemindersPage(),
        '/foodrec': (context) => FoodRecommender(
          remainingCalories: 0, // Default values, will be overridden by Navigator.push
          remainingProtein: 0,
        ),
        '/custom': (context) => CustomWorkout(),
      },
    );
  }
}