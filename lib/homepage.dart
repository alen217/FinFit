import 'package:finfit/userscreen.dart'; // Ensure this file exists or adjust the import
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        cardColor: Colors.grey[900],
      ),
      home: const HomePage(),
      // Define routes if using Navigator.pushNamed
      routes: {
        '/home': (context) => const HomePage(),
        '/finance': (context) => const Placeholder(), // Replace with actual screens
        '/nut': (context) => const Placeholder(),
        '/workout': (context) => const Placeholder(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _dailyGoal = 3000; // Water goal
  double _currentIntake = 0; // Water intake
  bool _goalAchieved = false;
  final List<int> _presetAmounts = [50, 150, 250, 350, 500];
  String _username = "Username";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _todayDate = '';
  List<Map<String, dynamic>> _weeklyNutritionData = [];
  List<Map<String, dynamic>> _weeklyWorkoutData = [];
  List<Map<String, dynamic>> _weeklyExpenseData = [];
  double _tdee = 0; // Calorie goal from metrics
  double _proteinNeeded = 0; // Protein goal from metrics
  int _workoutStreak = 0;
  double _monthlyIncome = 0;
  Map<String, dynamic> _closestBill = {};

  @override
  void initState() {
    super.initState();
    _todayDate = _getTodayString();
    _fetchUserData();
    _fetchWeeklyNutritionData();
    _fetchWeeklyWorkoutData();
    _fetchWeeklyExpenseData();
    _fetchMonthlyIncome();
    _fetchClosestBill();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userData =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (userData.exists) {
          Map<String, dynamic> data = userData.data() as Map<String, dynamic>;
          _username = currentUser.displayName ?? data['displayName'] ?? "Username";

          if (data.containsKey('metrics') && data['metrics'] is Map) {
            Map<String, dynamic> metrics = data['metrics'];
            if (metrics.containsKey('waterNeeded')) {
              _dailyGoal = metrics['waterNeeded'].toDouble();
            }
            _tdee = (metrics['tdee'] ?? 0).toDouble();
            _proteinNeeded = (metrics['proteinNeeded'] ?? 0).toDouble();
          }
        }

        DocumentSnapshot hydrationData = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('hydration_tracker')
            .doc(_todayDate)
            .get();

        if (hydrationData.exists) {
          Map<String, dynamic> data = hydrationData.data() as Map<String, dynamic>;
          setState(() {
            _currentIntake = data['currentIntake']?.toDouble() ?? 0;
            _goalAchieved = data['goalAchieved'] ?? false;
          });
        } else {
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('hydration_tracker')
              .doc(_todayDate)
              .set({
            'date': _todayDate,
            'currentIntake': 0,
            'dailyGoal': _dailyGoal,
            'goalAchieved': false,
            'timestamp': FieldValue.serverTimestamp(),
          });

          setState(() {
            _currentIntake = 0;
            _goalAchieved = false;
          });
        }
      } catch (e) {
        print("Error fetching user data: $e");
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  DateTime _getWeekStartDate() {
    DateTime now = DateTime.now();
    int daysSinceMonday = now.weekday - 1; // Monday is 1, Sunday is 7
    return now.subtract(Duration(days: daysSinceMonday));
  }

  Future<void> _fetchWeeklyNutritionData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        List<Map<String, dynamic>> weekData = [];
        DateTime weekStart = _getWeekStartDate();

        for (int i = 0; i < 7; i++) {
          DateTime date = weekStart.add(Duration(days: i));
          String dateString =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

          DocumentSnapshot nutritionData = await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('daily_nutrition_totals')
              .doc(dateString)
              .get();

          if (nutritionData.exists) {
            Map<String, dynamic> data = nutritionData.data() as Map<String, dynamic>;
            weekData.add({
              'date': dateString,
              'calories': (data['totalCalories'] ?? 0).toDouble(),
              'protein': (data['totalProtein'] ?? 0).toDouble(),
            });
          } else {
            weekData.add({
              'date': dateString,
              'calories': 0.0,
              'protein': 0.0,
            });
          }
        }

        setState(() {
          _weeklyNutritionData = weekData;
        });
      } catch (e) {
        print("Error fetching nutrition data: $e");
      }
    }
  }

  Future<void> _fetchWeeklyWorkoutData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        List<Map<String, dynamic>> weekData = [];
        DateTime weekStart = _getWeekStartDate();

        for (int i = 0; i < 7; i++) {
          DateTime date = weekStart.add(Duration(days: i));
          String dateString =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

          DocumentSnapshot workoutData = await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('daily_workout_time')
              .doc(dateString)
              .get();

          if (workoutData.exists) {
            Map<String, dynamic> data = workoutData.data() as Map<String, dynamic>;
            weekData.add({
              'date': dateString,
              'duration': (data['totalDuration'] ?? 0).toDouble(),
            });
          } else {
            weekData.add({
              'date': dateString,
              'duration': 0.0,
            });
          }
        }

        setState(() {
          _weeklyWorkoutData = weekData;
          _calculateWorkoutStreak();
        });
      } catch (e) {
        print("Error fetching workout data: $e");
      }
    }
  }

  Future<void> _fetchWeeklyExpenseData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        List<Map<String, dynamic>> weekData = [];
        DateTime weekStart = _getWeekStartDate();

        for (int i = 0; i < 7; i++) {
          DateTime date = weekStart.add(Duration(days: i));
          String dateString =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

          DocumentSnapshot expenseData = await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('finance')
              .doc('daily_expense_total')
              .collection('daily_totals')
              .doc(dateString)
              .get();

          if (expenseData.exists) {
            Map<String, dynamic> data = expenseData.data() as Map<String, dynamic>;
            weekData.add({
              'date': dateString,
              'total': (data['total'] ?? 0).toDouble(),
            });
          } else {
            weekData.add({
              'date': dateString,
              'total': 0.0,
            });
          }
        }

        setState(() {
          _weeklyExpenseData = weekData;
        });
      } catch (e) {
        print("Error fetching expense data: $e");
      }
    }
  }

  Future<void> _fetchMonthlyIncome() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DateTime now = DateTime.now();
        String monthYear = "${now.year}-${now.month.toString().padLeft(2, '0')}";

        DocumentSnapshot incomeData = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('finance')
            .doc('total_monthly_income')
            .collection(monthYear)
            .doc('total')
            .get();

        if (incomeData.exists) {
          Map<String, dynamic> data = incomeData.data() as Map<String, dynamic>;
          setState(() {
            _monthlyIncome = (data['total_income'] ?? 0).toDouble();
          });
        } else {
          setState(() {
            _monthlyIncome = 0.0;
          });
        }
      } catch (e) {
        print("Error fetching monthly income: $e");
      }
    }
  }

  Future<void> _fetchClosestBill() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        QuerySnapshot billsSnapshot = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('finance')
            .doc('bill_reminders')
            .collection('bills')
            .orderBy('timestamp')
            .get();

        DateTime now = DateTime.now();
        Map<String, dynamic>? closestBill;
        DateTime? closestDueDate;

        for (var doc in billsSnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          DateTime dueDate;
          if (data['timestamp'] is Timestamp) {
            dueDate = (data['timestamp'] as Timestamp).toDate();
          } else if (data['dueDate'] is String) {
            dueDate = DateFormat('yyyy-MM-dd').parse(data['dueDate']);
          } else {
            continue;
          }

          if (!data['isPaid'] && dueDate.isAfter(now)) {
            if (closestDueDate == null || dueDate.isBefore(closestDueDate)) {
              closestDueDate = dueDate;
              closestBill = {
                'name': data['name'],
                'amount': data['amount'].toDouble(),
                'dueDate': dueDate,
              };
            }
          }
        }

        setState(() {
          _closestBill = closestBill ?? {};
        });
      } catch (e) {
        print("Error fetching bills: $e");
        setState(() {
          _closestBill = {};
        });
      }
    }
  }

  void _calculateWorkoutStreak() {
    int streak = 0;
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    for (int i = 0; i <= 6; i++) {
      DateTime date = today.subtract(Duration(days: i));
      String dateString =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      var dayData = _weeklyWorkoutData.firstWhere(
        (data) => data['date'] == dateString,
        orElse: () => {'duration': 0.0},
      );
      if (dayData['duration'] > 0) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    setState(() {
      _workoutStreak = streak;
    });
  }

  String _getTodayString() {
    DateTime now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String formatIndianRupees(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  Future<void> _saveWaterIntake() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        bool isGoalAchieved = _currentIntake >= _dailyGoal;

        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('hydration_tracker')
            .doc(_todayDate)
            .update({
          'currentIntake': _currentIntake,
          'dailyGoal': _dailyGoal,
          'goalAchieved': isGoalAchieved,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        setState(() {
          _goalAchieved = isGoalAchieved;
        });
      } catch (e) {
        print("Error saving water intake: $e");
      }
    }
  }

  void _addWaterIntake(int amount) {
    setState(() {
      _currentIntake += amount;
      if (_currentIntake > _dailyGoal) {
        _currentIntake = _dailyGoal;
      }
    });
    _saveWaterIntake();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWeb = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF002386),
        elevation: 0,
        toolbarHeight: isWeb ? 100 : 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, $_username!",
              style: TextStyle(
                fontSize: isWeb ? 28 : 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Small steps lead to big changes',
              style: TextStyle(
                fontSize: isWeb ? 18 : 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle, size: isWeb ? 40 : 30, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserScreen()),
              ).then((_) => _fetchUserData());
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF002386)))
          : SafeArea(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
                    child: Padding(
                      padding: EdgeInsets.all(screenWidth * 0.02),
                      child: Column(
                        children: [
                          _buildFinanceSummary(screenWidth, screenHeight, isWeb),
                          SizedBox(height: screenHeight * 0.02),
                          _buildNutritionSummary(screenWidth, screenHeight, isWeb),
                          SizedBox(height: screenHeight * 0.02),
                          _buildWorkoutSummary(screenWidth, screenHeight, isWeb),
                          SizedBox(height: screenHeight * 0.02),
                          _buildHydrationTracker(screenWidth, screenHeight, isWeb),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(context, screenWidth, isWeb),
    );
  }

  Widget _buildFinanceSummary(double screenWidth, double screenHeight, bool isWeb) {
    final primaryColor = Color(0xFF002386);
    final primaryLight = Color(0xFF3949A0);
    final primaryLighter = Color(0xFF6872B8);
    final accentColor = Color(0xFF47A3FF);

    return Container(
      width: isWeb ? screenWidth * 0.8 : screenWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryLight.withOpacity(0.3), width: 1),
      ),
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Finance Summary",
            style: TextStyle(
              color: primaryColor,
              fontSize: isWeb ? 24 : screenWidth * 0.05,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          SizedBox(
            height: screenHeight * 0.25,
            child: _weeklyExpenseData.isEmpty
                ? Center(child: Text("Loading expense data...", style: TextStyle(color: primaryLighter)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _weeklyExpenseData
                              .map((data) => data['total'] as double)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              formatIndianRupees(_weeklyExpenseData[group.x.toInt()]['total']),
                              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  days[value.toInt()],
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: isWeb ? 16 : screenWidth * 0.03,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: screenWidth * 0.1,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                (value / 1000).toStringAsFixed(0) + 'k',
                                style: TextStyle(
                                  color: primaryLighter,
                                  fontSize: isWeb ? 14 : screenWidth * 0.025,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(color: primaryLight.withOpacity(0.2), strokeWidth: 1);
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _weeklyExpenseData.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> data = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data['total'] as double,
                              gradient: LinearGradient(
                                colors: [accentColor, primaryColor],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: screenWidth * 0.035,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: _weeklyExpenseData
                                        .map((data) => data['total'] as double)
                                        .reduce((a, b) => a > b ? a : b) *
                                    1.2,
                                color: primaryLighter.withOpacity(0.1),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
          SizedBox(height: screenHeight * 0.025),
          Container(
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.015,
              horizontal: screenWidth * 0.03,
            ),
            decoration: BoxDecoration(
              color: Color(0xFF47A3FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.arrow_upward, color: Color(0xFF47A3FF), size: screenWidth * 0.04),
                SizedBox(width: 8),
                Text(
                  "Monthly Income:",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: isWeb ? 16 : screenWidth * 0.035,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Text(
                  formatIndianRupees(_monthlyIncome),
                  style: TextStyle(
                    color: Color(0xFF47A3FF),
                    fontSize: isWeb ? 18 : screenWidth * 0.04,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          if (_closestBill.isNotEmpty)
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: primaryColor, size: screenWidth * 0.04),
                      SizedBox(width: 8),
                      Text(
                        "Next Bill Due",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: isWeb ? 16 : screenWidth * 0.035,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _closestBill['name'],
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: isWeb ? 18 : screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formatIndianRupees(_closestBill['amount']),
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: isWeb ? 18 : screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: primaryLighter, size: screenWidth * 0.03),
                      SizedBox(width: 4),
                      Text(
                        "Due: ${DateFormat('yyyy-MM-dd').format(_closestBill['dueDate'])}",
                        style: TextStyle(
                          color: primaryLighter,
                          fontSize: isWeb ? 14 : screenWidth * 0.03,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: primaryLighter.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: primaryLighter, size: screenWidth * 0.04),
                  SizedBox(width: 8),
                  Text(
                    "No upcoming bills",
                    style: TextStyle(
                      color: primaryLighter,
                      fontSize: isWeb ? 16 : screenWidth * 0.035,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummary(double screenWidth, double screenHeight, bool isWeb) {
    final primaryColor = Color(0xFF002386);
    final primaryLight = Color(0xFF3949A0);
    final primaryLighter = Color(0xFF6872B8);
    final caloriesColor = Color(0xFF47A3FF);
    final proteinColor = Color(0xFF61DBFB);

    Map<String, dynamic>? todayData = _weeklyNutritionData.isNotEmpty
        ? _weeklyNutritionData.lastWhere((data) => data['date'] == _todayDate,
            orElse: () => {'calories': 0.0, 'protein': 0.0})
        : {'calories': 0.0, 'protein': 0.0};

    double consumedCalories = todayData['calories'] as double;
    double consumedProtein = todayData['protein'] as double;
    double remainingCalories = _tdee - consumedCalories;
    double remainingProtein = _proteinNeeded - consumedProtein;
    double caloriePercentage = (_tdee > 0) ? (consumedCalories / _tdee).clamp(0.0, 1.5) : 0.0;
    double proteinPercentage = (_proteinNeeded > 0) ? (consumedProtein / _proteinNeeded).clamp(0.0, 1.5) : 0.0;

    return Container(
      width: isWeb ? screenWidth * 0.8 : screenWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryLight.withOpacity(0.3), width: 1),
      ),
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Nutrition Summary",
            style: TextStyle(
              color: primaryColor,
              fontSize: isWeb ? 24 : screenWidth * 0.05,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          SizedBox(
            height: screenHeight * 0.25,
            child: _weeklyNutritionData.isEmpty
                ? Center(child: Text("Loading nutrition data...", style: TextStyle(color: primaryLighter)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _weeklyNutritionData
                              .map((data) => (data['calories'] as double) > (data['protein'] as double)
                                  ? data['calories'] as double
                                  : data['protein'] as double)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            String value = rodIndex == 0 ? 'Calories: ' : 'Protein: ';
                            double amount = rodIndex == 0
                                ? _weeklyNutritionData[group.x.toInt()]['calories']
                                : _weeklyNutritionData[group.x.toInt()]['protein'];
                            String unit = rodIndex == 0 ? ' kcal' : ' g';
                            return BarTooltipItem(
                              value + amount.toStringAsFixed(0) + unit,
                              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  days[value.toInt()],
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: isWeb ? 16 : screenWidth * 0.03,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: screenWidth * 0.1,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: primaryLighter,
                                  fontSize: isWeb ? 14 : screenWidth * 0.025,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(color: primaryLight.withOpacity(0.2), strokeWidth: 1);
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _weeklyNutritionData.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> data = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data['calories'] as double,
                              gradient: LinearGradient(
                                colors: [caloriesColor.withOpacity(0.7), caloriesColor],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: screenWidth * 0.025,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            BarChartRodData(
                              toY: data['protein'] as double,
                              gradient: LinearGradient(
                                colors: [proteinColor.withOpacity(0.7), proteinColor],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: screenWidth * 0.025,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                          barsSpace: screenWidth * 0.01,
                        );
                      }).toList(),
                    ),
                  ),
          ),
          SizedBox(height: screenHeight * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: screenWidth * 0.025,
                    height: screenWidth * 0.025,
                    decoration: BoxDecoration(
                      color: caloriesColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  Text(
                    "Calories",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: isWeb ? 16 : screenWidth * 0.035,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(width: screenWidth * 0.06),
              Row(
                children: [
                  Container(
                    width: screenWidth * 0.025,
                    height: screenWidth * 0.025,
                    decoration: BoxDecoration(
                      color: proteinColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.015),
                  Text(
                    "Protein",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: isWeb ? 16 : screenWidth * 0.035,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.025),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Calories",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: isWeb ? 16 : screenWidth * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${consumedCalories.toStringAsFixed(0)} / ${_tdee.toStringAsFixed(0)} kcal",
                    style: TextStyle(
                      color: caloriesColor,
                      fontSize: isWeb ? 16 : screenWidth * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.01),
              Stack(
                children: [
                  Container(
                    height: screenHeight * 0.015,
                    decoration: BoxDecoration(
                      color: primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Container(
                    height: screenHeight * 0.015,
                    width: (isWeb ? screenWidth * 0.65 : screenWidth * 0.82) * caloriePercentage,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [caloriesColor.withOpacity(0.7), caloriesColor],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.005),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "Remaining: ",
                    style: TextStyle(
                      color: primaryLight,
                      fontSize: isWeb ? 14 : screenWidth * 0.03,
                    ),
                  ),
                  Text(
                    "${remainingCalories.toStringAsFixed(0)} kcal",
                    style: TextStyle(
                      color: remainingCalories < 0 ? Colors.redAccent : primaryLight,
                      fontSize: isWeb ? 14 : screenWidth * 0.03,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Protein",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: isWeb ? 16 : screenWidth * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${consumedProtein.toStringAsFixed(0)} / ${_proteinNeeded.toStringAsFixed(0)} g",
                    style: TextStyle(
                      color: proteinColor,
                      fontSize: isWeb ? 16 : screenWidth * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.01),
              Stack(
                children: [
                  Container(
                    height: screenHeight * 0.015,
                    decoration: BoxDecoration(
                      color: primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Container(
                    height: screenHeight * 0.015,
                    width: (isWeb ? screenWidth * 0.65 : screenWidth * 0.82) * proteinPercentage,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [proteinColor.withOpacity(0.7), proteinColor],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.005),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "Remaining: ",
                    style: TextStyle(
                      color: primaryLight,
                      fontSize: isWeb ? 14 : screenWidth * 0.03,
                    ),
                  ),
                  Text(
                    "${remainingProtein.toStringAsFixed(0)} g",
                    style: TextStyle(
                      color: remainingProtein < 0 ? Colors.redAccent : primaryLight,
                      fontSize: isWeb ? 14 : screenWidth * 0.03,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSummary(double screenWidth, double screenHeight, bool isWeb) {
    final primaryColor = Color(0xFF002386);
    final primaryLight = Color(0xFF3949A0);
    final primaryLighter = Color(0xFF6872B8);
    final accentColor = Color(0xFF00A3FF);

    return Container(
      width: isWeb ? screenWidth * 0.8 : screenWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryLight.withOpacity(0.3), width: 1),
      ),
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Workout Summary",
            style: TextStyle(
              color: primaryColor,
              fontSize: isWeb ? 24 : screenWidth * 0.05,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          SizedBox(
            height: screenHeight * 0.25,
            child: _weeklyWorkoutData.isEmpty
                ? Center(child: Text("Loading workout data...", style: TextStyle(color: primaryLighter)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _weeklyWorkoutData
                              .map((data) => data['duration'] as double)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            double minutes = _weeklyWorkoutData[group.x.toInt()]['duration'] as double;
                            return BarTooltipItem(
                              "${minutes.toStringAsFixed(0)} min",
                              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  days[value.toInt()],
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: isWeb ? 16 : screenWidth * 0.03,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: screenWidth * 0.1,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: primaryLighter,
                                  fontSize: isWeb ? 14 : screenWidth * 0.025,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(color: primaryLight.withOpacity(0.2), strokeWidth: 1);
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _weeklyWorkoutData.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> data = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data['duration'] as double,
                              gradient: LinearGradient(
                                colors: [accentColor.withOpacity(0.6), accentColor],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: screenWidth * 0.04,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: _weeklyWorkoutData
                                        .map((data) => data['duration'] as double)
                                        .reduce((a, b) => a > b ? a : b) *
                                    1.2,
                                color: primaryLighter.withOpacity(0.1),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
          SizedBox(height: screenHeight * 0.025),
          Container(
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.05), primaryLighter.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: accentColor,
                      size: screenWidth * 0.06,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      "Workout Streak",
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: isWeb ? 18 : screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  "$_workoutStreak day${_workoutStreak == 1 ? '' : 's'}",
                  style: TextStyle(
                    color: accentColor,
                    fontSize: isWeb ? 24 : screenWidth * 0.06,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_weeklyWorkoutData.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.01),
                    child: Text(
                      "Weekly Total: ${_weeklyWorkoutData.fold(0.0, (sum, item) => sum + (item['duration'] as double)).toStringAsFixed(0)} min",
                      style: TextStyle(
                        color: primaryLighter,
                        fontSize: isWeb ? 14 : screenWidth * 0.03,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationTracker(double screenWidth, double screenHeight, bool isWeb) {
    double remaining = _dailyGoal - _currentIntake;
    if (remaining < 0) remaining = 0;
    int percentage = (_currentIntake / _dailyGoal * 100).toInt();
    if (percentage > 100) percentage = 100;

    return Container(
      width: isWeb ? screenWidth * 0.8 : screenWidth,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(screenWidth * 0.02),
                    decoration: BoxDecoration(
                      color: const Color(0xFF002386),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Icon(
                      Icons.water_drop,
                      color: Colors.white,
                      size: isWeb ? 24 : screenWidth * 0.05,
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    'Drink Water',
                    style: TextStyle(
                      fontSize: isWeb ? 20 : screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  if (_goalAchieved)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.02, vertical: screenHeight * 0.005),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.white, size: screenWidth * 0.04),
                          SizedBox(width: screenWidth * 0.01),
                          Text(
                            'Goal Achieved',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isWeb ? 14 : screenWidth * 0.03,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),
              Text(
                'Record with one tap',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: isWeb ? 16 : screenWidth * 0.035,
                ),
              ),
              SizedBox(height: screenHeight * 0.015),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _presetAmounts.map((amount) {
                  return GestureDetector(
                    onTap: () => _addWaterIntake(amount),
                    child: Container(
                      width: isWeb ? 60 : screenWidth * 0.13,
                      height: isWeb ? 60 : screenWidth * 0.13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF002386).withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.water_drop,
                            color: const Color(0xFF002386),
                            size: isWeb ? 24 : screenWidth * 0.045,
                          ),
                          Text(
                            '$amount',
                            style: TextStyle(
                              color: const Color(0xFF002386),
                              fontWeight: FontWeight.bold,
                              fontSize: isWeb ? 16 : screenWidth * 0.035,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: screenHeight * 0.03),
              Row(
                children: [
                  Text(
                    '${_currentIntake.toInt()} mL · $percentage%',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: isWeb ? 16 : screenWidth * 0.035,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Remaining: ${remaining.toInt()} mL',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: isWeb ? 16 : screenWidth * 0.035,
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.01),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: const Color(0xFFD6E1F5),
                valueColor: AlwaysStoppedAnimation<Color>(_goalAchieved ? Colors.green : const Color(0xFF002386)),
                minHeight: screenHeight * 0.01,
                borderRadius: BorderRadius.circular(4),
              ),
              SizedBox(height: screenHeight * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, double screenWidth, bool isWeb) {
    return Container(
      height: isWeb ? 80 : 60,
      width: isWeb ? screenWidth * 0.8 : screenWidth,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 5)],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, Icons.home, "Home", true, '/home', screenWidth, isWeb),
          _buildNavItem(context, Icons.bar_chart, "Finance", false, '/finance', screenWidth, isWeb),
          _buildNavItem(context, Icons.restaurant, "Nutrition", false, '/nut', screenWidth, isWeb),
          _buildNavItem(context, Icons.fitness_center, "Workout", false, '/workout', screenWidth, isWeb),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isSelected,
      String route, double screenWidth, bool isWeb) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Color(0xFF002386) : Colors.grey,
            size: isWeb ? 32 : 24,
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Color(0xFF002386) : Colors.grey,
              fontSize: isWeb ? 14 : 11,
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}