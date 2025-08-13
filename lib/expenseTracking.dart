import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

class ExpenseTrackerPage extends StatefulWidget {
  const ExpenseTrackerPage({super.key});

  @override
  _ExpenseTrackerPageState createState() => _ExpenseTrackerPageState();
}

class _ExpenseTrackerPageState extends State<ExpenseTrackerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _userId;

  final Map<String, List<Map<String, dynamic>>> _expenses = {
    'Housing': [],
    'Food': [],
    'Transportation': [],
    'Healthcare': [],
    'Personal Care': [],
    'Entertainment': [],
    'Education': [],
    'Clothing': [],
    'Other Expenses': [],
  };

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

  final Map<String, bool> _isExpanded = {
    'Housing': false,
    'Food': false,
    'Transportation': false,
    'Healthcare': false,
    'Personal Care': false,
    'Entertainment': false,
    'Education': false,
    'Clothing': false,
    'Other Expenses': false,
  };

  bool _isLoading = true;
  DateTime _currentViewDate = DateTime.now();
  final picker = ImagePicker();
  double _dailyTotal = 0.0;

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
      await _fetchExpensesFromFirestore(_currentViewDate);
      await _fetchMonthlyTotals(_currentViewDate);
      await _fetchDailyTotal(_currentViewDate);
      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not authenticated. Please log in.')),
      );
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
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch budgets: $e')),
      );
    }
  }

  Future<void> _fetchExpensesFromFirestore(DateTime date) async {
    try {
      _clearExpenses();
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      QuerySnapshot expensesDocs = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('finance')
          .doc('expense_tracker')
          .collection(formattedDate)
          .get();

      setState(() {
        for (var doc in expensesDocs.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String category = data['category'] ?? 'Other Expenses';
          if (_expenses.containsKey(category)) {
            _expenses[category]!.add({
              'id': doc.id,
              'name': data['name'] ?? '',
              'amount': (data['amount'] as num).toDouble(),
              'notes': data['notes'] ?? '',
              'date': data['date'] ?? formattedDate,
            });
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch expenses: $e')),
      );
    }
  }

  void _clearExpenses() {
    for (String category in _expenses.keys) {
      _expenses[category]!.clear();
    }
  }

  Future<void> _fetchMonthlyTotals(DateTime date) async {
    try {
      String monthYear = DateFormat('MMMM-yyyy').format(date);
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
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch monthly totals: $e')),
      );
    }
  }

  Future<void> _fetchDailyTotal(DateTime date) async {
    try {
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      DocumentSnapshot dailyTotalDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('finance')
          .doc('daily_expense_total')
          .collection('daily_totals')
          .doc(formattedDate)
          .get();

      if (dailyTotalDoc.exists) {
        Map<String, dynamic> data = dailyTotalDoc.data() as Map<String, dynamic>;
        setState(() {
          _dailyTotal = (data['total'] as num).toDouble();
        });
      } else {
        setState(() {
          _dailyTotal = 0.0;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch daily total: $e')),
      );
    }
  }

  Future<void> _updateMonthlyTotals(DateTime date) async {
    try {
      String monthYear = DateFormat('MMMM-yyyy').format(date);
      Map<String, double> monthlyTotals = {};
      for (String category in _expenses.keys) {
        monthlyTotals[category] = 0.0;
      }

      DateTime startOfMonth = DateTime(date.year, date.month, 1);
      DateTime endOfMonth = DateTime(date.year, date.month + 1, 0);

      for (int day = startOfMonth.day; day <= endOfMonth.day; day++) {
        String dateStr = DateFormat('yyyy-MM-dd')
            .format(DateTime(date.year, date.month, day));
        QuerySnapshot expensesDocs = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('finance')
            .doc('expense_tracker')
            .collection(dateStr)
            .get();

        for (var doc in expensesDocs.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String category = data['category'] ?? 'Other Expenses';
          if (monthlyTotals.containsKey(category)) {
            monthlyTotals[category] = monthlyTotals[category]! +
                (data['amount'] as num).toDouble();
          }
        }
      }

      double totalMonthlyExpense =
          monthlyTotals.values.fold(0.0, (sum, value) => sum + value);
      monthlyTotals['total_monthly_expense'] = totalMonthlyExpense;

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('finance')
          .doc('expense_totals')
          .collection(monthYear)
          .doc('totals')
          .set(monthlyTotals);

      setState(() {
        _monthlyTotals.addAll(monthlyTotals);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update monthly totals: $e')),
      );
    }
  }

  Future<void> _updateDailyTotal(DateTime date) async {
    try {
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      double total = 0.0;

      QuerySnapshot expensesDocs = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('finance')
          .doc('expense_tracker')
          .collection(formattedDate)
          .get();

      for (var doc in expensesDocs.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        total += (data['amount'] as num).toDouble();
      }

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('finance')
          .doc('daily_expense_total')
          .collection('daily_totals')
          .doc(formattedDate)
          .set({'total': total});

      setState(() {
        _dailyTotal = total;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update daily total: $e')),
      );
    }
  }

  Future<void> _changeViewDate(DateTime date) async {
    setState(() {
      _isLoading = true;
      _currentViewDate = date;
    });
    await _fetchExpensesFromFirestore(date);
    await _fetchMonthlyTotals(date);
    await _fetchDailyTotal(date);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveBudgetsToFirestore(Map<String, double> budgets) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('finance')
          .doc('budgets')
          .set(budgets);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save budgets: $e')),
      );
    }
  }

  Future<void> _addExpenseToFirestore(
      String category, Map<String, dynamic> expense) async {
    try {
      String date =
          expense['date'] ?? DateTime.now().toString().substring(0, 10);
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('finance')
          .doc('expense_tracker')
          .collection(date)
          .add({
        'name': expense['name'],
        'amount': expense['amount'],
        'notes': expense['notes'],
        'date': date,
        'category': category,
        'timestamp': FieldValue.serverTimestamp(),
      });
      expense['id'] = docRef.id;

      await _updateMonthlyTotals(DateTime.parse(date));
      await _updateDailyTotal(DateTime.parse(date));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add expense: $e')),
      );
    }
  }

  Future<void> _deleteExpenseFromFirestore(String category, int index) async {
    try {
      Map<String, dynamic> expense = _expenses[category]![index];
      String date =
          expense['date'] ?? DateTime.now().toString().substring(0, 10);
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('finance')
          .doc('expense_tracker')
          .collection(date)
          .doc(expense['id'])
          .delete();

      await _updateMonthlyTotals(DateTime.parse(date));
      await _updateDailyTotal(DateTime.parse(date));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete expense: $e')),
      );
    }
  }

  Future<Map<String, dynamic>> _scanReceipt(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return {};

      final imageFile = File(pickedFile.path);
      final inputImage = InputImage.fromFile(imageFile);
      final textDetector = TextRecognizer();
      final RecognizedText recognizedText =
          await textDetector.processImage(inputImage);

      String extractedText = "";
      List<String> lines = [];
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += line.text + "\n";
          lines.add(line.text);
        }
      }
      print('Extracted Text: $extractedText');

      // Merchant name extraction
      String name = "Unknown Merchant";
      final merchantKeywords = [
        'store',
        'shop',
        'mart',
        'restaurant',
        'cafe',
        'market',
        'supermarket',
        'co.',
        'ltd',
        'inc'
      ];
      RegExp numericCheck = RegExp(r'^\d+$');
      RegExp specialCharCheck = RegExp(r'^[₹$\d\s.,]+$');

      for (int i = 0; i < lines.length && i < 10; i++) {
        String line = lines[i].trim();
        if (line.isNotEmpty &&
            !numericCheck.hasMatch(line) &&
            !specialCharCheck.hasMatch(line) &&
            line.length > 3) {
          if (line == line.toUpperCase() ||
              merchantKeywords.any((keyword) =>
                  line.toLowerCase().contains(keyword)) ||
              (i < 3 && line.length > 5)) {
            name = line.length > 30 ? line.substring(0, 30) : line;
            break;
          }
        }
      }

      // Date extraction
      String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final dateFormats = [
        RegExp(r'\d{2}/\d{2}/\d{4}'),
        RegExp(r'\d{2}-\d{2}-\d{4}'),
        RegExp(r'\d{4}-\d{2}-\d{2}'),
        RegExp(r'\d{2}\s+[A-Za-z]+\s+\d{4}'),
      ];

      for (String line in lines) {
        for (RegExp pattern in dateFormats) {
          var match = pattern.firstMatch(line);
          if (match != null) {
            String dateStr = match.group(0)!;
            try {
              if (dateStr.contains('/')) {
                date = DateFormat('dd/MM/yyyy')
                    .parse(dateStr)
                    .toString()
                    .substring(0, 10);
              } else if (dateStr.contains('-')) {
                date = DateFormat('dd-MM-yyyy')
                    .parse(dateStr)
                    .toString()
                    .substring(0, 10);
              } else {
                date = DateFormat('dd MMMM yyyy')
                    .parse(dateStr)
                    .toString()
                    .substring(0, 10);
              }
              break;
            } catch (e) {
              continue;
            }
          }
        }
        if (date != DateFormat('yyyy-MM-dd').format(DateTime.now())) break;
      }

      // Amount extraction - Check entire receipt, stop at first match
      double amount = 0.0;
      final totalKeywords = [
        'grand total',
        'total',
        'price',
        'fee',
        'amount due',
        'net total',
        'final total',
        'amount',
        'subtotal',
        'total amount',
        'payable',
        'due',
        'cost',
        'charge'
      ];
      final amountRegex = RegExp(r'(?:₹|\$)?\s*[\d,.]+(?:\.\d{1,2})?');

      for (String line in lines) {
        String lowerLine = line.toLowerCase();
        for (String keyword in totalKeywords) {
          if (lowerLine.contains(keyword)) {
            var match = amountRegex.firstMatch(line);
            if (match != null) {
              String amountStr = match.group(0)!
                  .replaceAll('₹', '')
                  .replaceAll('\$', '')
                  .replaceAll(',', '')
                  .trim();
              amount = double.tryParse(amountStr) ?? 0.0;
              if (amount > 0) break;
            }
          }
        }
        if (amount > 0) break; // Stop at first valid amount
      }

      // Limit notes to 3 lines
      List<String> notesLines = lines.take(3).toList();
      if (lines.length > 3) {
        notesLines.add('etc');
      }
      String notes = notesLines.join('\n');

      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not extract a valid amount from receipt')),
        );
      }
      if (name == "Unknown Merchant") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not identify merchant name from receipt')),
        );
      }

      textDetector.close();
      return {
        'name': name,
        'amount': amount,
        'date': date,
        'notes': notes
      };
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to scan receipt: $e')),
      );
      return {};
    }
  }

  void _openExpenseDetails(String category) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Expense to $category'),
          content: ExpenseForm(
            initialDate: _currentViewDate,
            onScanReceipt: _scanReceipt,
          ),
        );
      },
    );

    if (result != null) {
      await _addExpenseToFirestore(category, result);
      if (result['date'] == DateFormat('yyyy-MM-dd').format(_currentViewDate)) {
        setState(() {
          _expenses[category]!.add(result);
          _isExpanded[category] = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Expense added for ${result['date']}. Switch date to view it.'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                _changeViewDate(DateTime.parse(result['date']));
              },
            ),
          ),
        );
      }
    }
  }

  void _openBudgetDialog() async {
    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set Budget for Each Category'),
          content: BudgetForm(budgets: _budgets),
        );
      },
    );

    if (result != null) {
      await _saveBudgetsToFirestore(result);
      setState(() {
        _budgets.addAll(result);
      });
    }
  }

  void _deleteExpense(String category, int index) async {
    await _deleteExpenseFromFirestore(category, index);
    setState(() {
      _expenses[category]!.removeAt(index);
    });
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentViewDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 1)),
    );

    if (picked != null && picked != _currentViewDate) {
      _changeViewDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF002386);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Expense Tracker'),
          centerTitle: true,
          backgroundColor: primaryColor,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    String formattedViewDate =
        DateFormat('EEEE, MMM d, yyyy').format(_currentViewDate);

    return Scaffold(
      appBar: AppBar(
        title: Text('Expense Tracker'),
        centerTitle: true,
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: _openBudgetDialog,
          ),
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _selectDate,
            tooltip: 'Select Date',
          ),
        ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0), // Corrected to 'bottom'
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Date: $formattedViewDate",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      "Total: ₹${_dailyTotal.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'My Expenses',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: _expenses.keys.map((category) {
                    double monthlySpent = _monthlyTotals[category] ?? 0;
                    double budget = _budgets[category] ?? 0;
                    double percentage =
                        budget > 0 ? (monthlySpent / budget) * 100 : 0;

                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle,
                                    color: primaryColor,
                                  ),
                                  onPressed: () => _openExpenseDetails(category),
                                  tooltip: 'Add $category expense',
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text(
                                    'Budget: ₹${budget.toStringAsFixed(2)} | Spent: ₹${monthlySpent.toStringAsFixed(2)}'),
                                SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: budget > 0
                                      ? (monthlySpent / budget).clamp(0.0, 1.0)
                                      : 0,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    percentage > 100
                                        ? Colors.red
                                        : percentage > 80
                                            ? Colors.orange
                                            : primaryColor,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: percentage > 100
                                        ? Colors.red
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_expenses[category]!.length}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _isExpanded[category]!
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isExpanded[category] =
                                          !_isExpanded[category]!;
                                    });
                                  },
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                          if (_isExpanded[category]! &&
                              _expenses[category]!.isNotEmpty)
                            Container(
                              color: Colors.grey[50],
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: _expenses[category]!.length,
                                itemBuilder: (context, index) {
                                  final expense = _expenses[category]![index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                primaryColor.withOpacity(0.2),
                                            child: Icon(Icons.receipt,
                                                color: primaryColor),
                                          ),
                                          title: Text(expense['name']),
                                          subtitle: expense['notes']
                                                  .toString()
                                                  .isNotEmpty
                                              ? Text(expense['notes'])
                                              : null,
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '₹${expense['amount'].toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              IconButton(
                                                icon: Icon(Icons.delete_outline,
                                                    color: Colors.red[400]),
                                                onPressed: () => _deleteExpense(
                                                    category, index),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (index <
                                            _expenses[category]!.length - 1)
                                          Divider(height: 1),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (_isExpanded[category]! &&
                              _expenses[category]!.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'No expenses in this category today',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpenseForm extends StatefulWidget {
  final DateTime initialDate;
  final Future<Map<String, dynamic>> Function(ImageSource) onScanReceipt;

  const ExpenseForm({
    super.key,
    required this.initialDate,
    required this.onScanReceipt,
  });

  @override
  _ExpenseFormState createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 1)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addExpense() {
    if (_nameController.text.isNotEmpty && _amountController.text.isNotEmpty) {
      final expense = {
        'name': _nameController.text,
        'amount': double.tryParse(_amountController.text) ?? 0,
        'notes': _notesController.text,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      };
      Navigator.of(context).pop(expense);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _scanReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _scanReceipt(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scanReceipt(ImageSource source) async {
    final scannedData = await widget.onScanReceipt(source);
    if (scannedData.isNotEmpty) {
      setState(() {
        _nameController.text = scannedData['name'] ?? 'Unknown Merchant';
        _amountController.text = scannedData['amount'].toStringAsFixed(2);
        _selectedDate = DateTime.parse(scannedData['date']);
        _notesController.text = scannedData['notes'] ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.currency_rupee),
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 16),
          InkWell(
            onTap: _selectDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                DateFormat('yyyy-MM-dd').format(_selectedDate),
              ),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
            maxLines: 3,
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showImageSourceDialog,
            icon: Icon(Icons.upload_file),
            label: Text('Scan Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00569B),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _addExpense,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF002386),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              textStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Text('Add Expense'),
          ),
        ],
      ),
    );
  }
}

class BudgetForm extends StatefulWidget {
  final Map<String, double> budgets;

  const BudgetForm({super.key, required this.budgets});

  @override
  _BudgetFormState createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  late Map<String, TextEditingController> _budgetControllers;

  @override
  void initState() {
    super.initState();
    _budgetControllers = {};
    widget.budgets.forEach((category, budget) {
      _budgetControllers[category] =
          TextEditingController(text: budget.toString());
    });
  }

  @override
  void dispose() {
    _budgetControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _saveBudgets() {
    Map<String, double> updatedBudgets = {};
    _budgetControllers.forEach((category, controller) {
      updatedBudgets[category] = double.tryParse(controller.text) ?? 0;
    });
    Navigator.of(context).pop(updatedBudgets);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ...widget.budgets.keys.map((category) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _budgetControllers[category],
                decoration: InputDecoration(
                  labelText: '$category Budget',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  prefixText: '₹ ',
                ),
                keyboardType: TextInputType.number,
              ),
            );
          }).toList(),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveBudgets,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF002386),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              textStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Text('Save Budgets'),
          ),
        ],
      ),
    );
  }
}