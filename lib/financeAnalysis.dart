import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class FinanceAnalysisPage extends StatefulWidget {
  const FinanceAnalysisPage({super.key});

  @override
  _FinanceAnalysisPageState createState() => _FinanceAnalysisPageState();
}

class _FinanceAnalysisPageState extends State<FinanceAnalysisPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _userId;

  final Map<String, double> _budgets = {
    'Housing': 0,
    'Food': 0,
    'Transportation': 0,
    'Healthcare': 0,
    'Personal Care': 0,
    'Entertainment': 0,
    'Education': 0,
    'Clothing': 0,
    'Other Expenses': 0,
  };

  final Map<String, double> _monthlyTotals = {
    'Housing': 0,
    'Food': 0,
    'Transportation': 0,
    'Healthcare': 0,
    'Personal Care': 0,
    'Entertainment': 0,
    'Education': 0,
    'Clothing': 0,
    'Other Expenses': 0,
  };

  final Map<String, double> _monthlyIncomes = {};
  double _totalMonthlyExpense = 0.0;
  double _totalBudget = 0.0;
  bool _isLoading = true;
  bool _showBudgetChart = true; // Toggle between budget and expense pie chart

  @override
  void initState() {
    super.initState();
    _initializeUserId();
  }

  Future<void> _initializeUserId() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _userId = currentUser.uid;
      await _fetchBudgetsFromFirestore();
      await _fetchMonthlyTotalsFromFirestore();
      await _fetchMonthlyIncomes(DateTime.now().year); // Fetch for current year
      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBudgetsFromFirestore() async {
    try {
      DocumentSnapshot budgetDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('finance')
          .doc('budgets')
          .get();

      if (budgetDoc.exists) {
        Map<String, dynamic> data = budgetDoc.data() as Map<String, dynamic>;
        setState(() {
          for (String category in _budgets.keys) {
            if (data.containsKey(category)) {
              _budgets[category] = (data[category] as num).toDouble();
            }
          }
          _totalBudget = _budgets.values.fold(0.0, (sum, value) => sum + value);
        });
      }
    } catch (e) {
      print('Error fetching budgets: $e');
    }
  }

  Future<void> _fetchMonthlyTotalsFromFirestore() async {
    try {
      String monthYear = DateFormat('MMMM-yyyy').format(DateTime.now());
      DocumentSnapshot totalsDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('finance')
          .doc('expense_totals')
          .collection(monthYear)
          .doc('totals')
          .get();

      if (totalsDoc.exists) {
        Map<String, dynamic> data = totalsDoc.data() as Map<String, dynamic>;
        setState(() {
          for (String category in _monthlyTotals.keys) {
            if (data.containsKey(category)) {
              _monthlyTotals[category] = (data[category] as num).toDouble();
            }
          }
          _totalMonthlyExpense = data['total_monthly_expense'] != null
              ? (data['total_monthly_expense'] as num).toDouble()
              : _monthlyTotals.values.fold(0.0, (sum, value) => sum + value);
        });
      }
    } catch (e) {
      print('Error fetching monthly totals: $e');
    }
  }

  Future<void> _fetchMonthlyIncomes(int year) async {
    try {
      for (int month = 1; month <= 12; month++) {
        String monthKey = DateFormat('MMM').format(DateTime(year, month));
        String incomePath = DateFormat('yyyy-MM').format(DateTime(year, month));

        DocumentSnapshot incomeDoc = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('finance')
            .doc('total_monthly_income')
            .collection(incomePath)
            .doc('total')
            .get();

        _monthlyIncomes[monthKey] = incomeDoc.exists
            ? (incomeDoc['total_income'] as num?)?.toDouble() ?? 0.0
            : 0.0;
      }
      setState(() {});
    } catch (e) {
      print('Error fetching monthly incomes: $e');
    }
  }

  List<PieChartSectionData> _generatePieChartSections(bool isBudget) {
    final dataMap = isBudget ? _budgets : _monthlyTotals;
    final total = isBudget ? _totalBudget : _totalMonthlyExpense;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.yellow,
      Colors.pink,
      Colors.grey,
    ];

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    dataMap.forEach((category, value) {
      if (value > 0) {
        final percentage = total > 0 ? (value / total) * 100 : 0;
        sections.add(
          PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: value,
            title: '$category\n${percentage.toStringAsFixed(1)}%',
            radius: 100,
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        colorIndex++;
      }
    });

    return sections;
  }

  List<BarChartGroupData> _generateIncomeBarChartGroups() {
    List<BarChartGroupData> groups = [];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    for (int i = 0; i < months.length; i++) {
      double income = _monthlyIncomes[months[i]] ?? 0.0;

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: income,
              color: Colors.green,
              width: 15,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF002386);
    final currentYear = DateTime.now().year;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Finance Analysis',style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22, // Cap font size for web
          ),),
          centerTitle: true,
          backgroundColor: primaryColor,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    String currentMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Finance Analysis',style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22, // Cap font size for web
          ),),
        centerTitle: true,
        backgroundColor: primaryColor,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFE6EEFF)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget vs. Expense - $currentMonthYear',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showBudgetChart = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _showBudgetChart
                                    ? primaryColor
                                    : Colors.grey,
                              ),
                              child: Text('Budget'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showBudgetChart = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !_showBudgetChart
                                    ? primaryColor
                                    : Colors.grey,
                              ),
                              child: Text('Expense'),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: PieChart(
                            PieChartData(
                              sections: _generatePieChartSections(_showBudgetChart),
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          _showBudgetChart
                              ? 'Total Budget: ₹${_totalBudget.toStringAsFixed(2)}'
                              : 'Total Spent: ₹${_totalMonthlyExpense.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Budget:', style: TextStyle(fontSize: 16)),
                            Text(
                              '₹${_totalBudget.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Spent:', style: TextStyle(fontSize: 16)),
                            Text(
                              '₹${_totalMonthlyExpense.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _totalMonthlyExpense > _totalBudget
                                    ? Colors.red
                                    : primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Balance:',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              '₹${(_totalBudget - _totalMonthlyExpense).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _totalBudget > _totalMonthlyExpense
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Monthly Income - $currentYear',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 300,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 800, // Wide enough for 12 months
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  barGroups: _generateIncomeBarChartGroups(),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            '₹${(value.toInt() / 1000).toStringAsFixed(0)}k',
                                            style: TextStyle(fontSize: 12),
                                          );
                                        },
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final months = [
                                            'Jan',
                                            'Feb',
                                            'Mar',
                                            'Apr',
                                            'May',
                                            'Jun',
                                            'Jul',
                                            'Aug',
                                            'Sep',
                                            'Oct',
                                            'Nov',
                                            'Dec'
                                          ];
                                          return Text(
                                            months[value.toInt()],
                                            style: TextStyle(fontSize: 12),
                                          );
                                        },
                                      ),
                                    ),
                                    rightTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      tooltipPadding: EdgeInsets.all(8),
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        return BarTooltipItem(
                                          'Income: ₹${rod.toY.toStringAsFixed(2)}',
                                          TextStyle(color: Colors.white),
                                        );
                                      },
                                    ),
                                  ),
                                  gridData: FlGridData(show: true),
                                  borderData: FlBorderData(show: false),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              color: Colors.green,
                            ),
                            SizedBox(width: 4),
                            Text('Income'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}