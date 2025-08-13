import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IncomeTrackPage extends StatefulWidget {
  const IncomeTrackPage({super.key});

  @override
  _IncomeTrackPageState createState() => _IncomeTrackPageState();
}

class _IncomeTrackPageState extends State<IncomeTrackPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDate;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF002386),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        final DateFormat formatter = DateFormat('yyyy-MM-dd');
        _dateController.text = formatter.format(picked);
      });
    }
  }

  String _getMonthYear(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  Future<void> _updateMonthlyTotal(String monthYear) async {
    try {
      final incomeSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance')
          .doc('income_tracker')
          .collection(monthYear)
          .get();

      final totalIncome = incomeSnapshot.docs.fold<double>(
        0,
        (sum, doc) => sum + (doc['amount'] as num).toDouble(),
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance')
          .doc('total_monthly_income')
          .collection(monthYear)
          .doc('total')
          .set({
        'total_income': totalIncome,
        'month_year': monthYear,
        'last_updated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating monthly total: $e');
    }
  }

  Future<double> _getMonthlyTotal(String monthYear) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance')
          .doc('total_monthly_income')
          .collection(monthYear)
          .doc('total')
          .get();

      if (doc.exists) {
        return (doc.data()?['total_income'] as num?)?.toDouble() ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      print('Error fetching monthly total: $e');
      return 0.0;
    }
  }

  Future<void> _addIncome() async {
    if (_nameController.text.isNotEmpty &&
        _amountController.text.isNotEmpty &&
        _dateController.text.isNotEmpty &&
        userId != null &&
        _selectedDate != null) {
      final income = {
        'name': _nameController.text,
        'amount': double.tryParse(_amountController.text) ?? 0,
        'date': _dateController.text,
        'notes': _notesController.text,
        'timestamp': Timestamp.fromDate(_selectedDate!),
      };

      final monthYear = _getMonthYear(_selectedDate!);

      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('finance')
            .doc('income_tracker')
            .collection(monthYear)
            .add(income);

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('finance')
            .doc('income_tracker')
            .set({
          'monthYears': FieldValue.arrayUnion([monthYear]),
        }, SetOptions(merge: true));

        await _updateMonthlyTotal(monthYear);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Income added successfully!'),
            backgroundColor: Color(0xFF002386),
            behavior: SnackBarBehavior.floating,
          ),
        );

        _nameController.clear();
        _amountController.clear();
        _dateController.clear();
        _notesController.clear();
        setState(() {
          _selectedDate = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding income: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteIncome(String monthYear, String docId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance')
          .doc('income_tracker')
          .collection(monthYear)
          .doc(docId)
          .delete();

      final remainingEntries = await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance')
          .doc('income_tracker')
          .collection(monthYear)
          .get();

      if (remainingEntries.docs.isEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('finance')
            .doc('income_tracker')
            .update({
          'monthYears': FieldValue.arrayRemove([monthYear]),
        });

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('finance')
            .doc('total_monthly_income')
            .collection(monthYear)
            .doc('total')
            .delete();
      } else {
        await _updateMonthlyTotal(monthYear);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Income entry deleted'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting income: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String formatIndianRupees(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  Future<List<String>> _getAllMonthYears() async {
    if (userId == null) return [];
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('finance')
        .doc('income_tracker')
        .get();

    if (!doc.exists || !doc.data()!.containsKey('monthYears')) {
      return [];
    }

    final monthYears = List<String>.from(doc['monthYears']);
    monthYears.sort((a, b) => b.compareTo(a));
    return monthYears;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final paddingScale = kIsWeb ? 0.02 : 0.04; // Smaller padding for web

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Income Tracker',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: screenWidth * 0.05 > 24 ? 24 : screenWidth * 0.05, // Cap font size
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF002386),
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(screenWidth * paddingScale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(screenWidth * 0.04),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(screenWidth * 0.05),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Income',
                              style: TextStyle(
                                fontSize: screenWidth * 0.05 > 20 ? 20 : screenWidth * 0.05,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF002386),
                              ),
                            ),
                            SizedBox(height: screenWidth * 0.04),
                            _buildTextField(
                              controller: _nameController,
                              label: 'Transaction Name',
                              icon: Icons.label_outline,
                              required: true,
                              screenWidth: screenWidth,
                            ),
                            SizedBox(height: screenWidth * 0.04),
                            _buildTextField(
                              controller: _amountController,
                              label: 'Amount',
                              icon: Icons.currency_rupee,
                              keyboardType: TextInputType.number,
                              required: true,
                              prefix: const Text('₹'),
                              screenWidth: screenWidth,
                            ),
                            SizedBox(height: screenWidth * 0.04),
                            GestureDetector(
                              onTap: _selectDate,
                              child: AbsorbPointer(
                                child: _buildTextField(
                                  controller: _dateController,
                                  label: 'Date',
                                  icon: Icons.calendar_today,
                                  required: true,
                                  suffixIcon: const Icon(Icons.arrow_drop_down),
                                  screenWidth: screenWidth,
                                ),
                              ),
                            ),
                            SizedBox(height: screenWidth * 0.04),
                            _buildTextField(
                              controller: _notesController,
                              label: 'Notes (optional)',
                              icon: Icons.note_alt_outlined,
                              maxLines: 3,
                              screenWidth: screenWidth,
                            ),
                            SizedBox(height: screenWidth * 0.06),
                            SizedBox(
                              width: double.infinity,
                              height: screenHeight * 0.06 > 60 ? 60 : screenHeight * 0.06, // Cap height
                              child: ElevatedButton(
                                onPressed: _addIncome,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF002386),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                  ),
                                  elevation: 2,
                                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                                ),
                                child: Text(
                                  'ADD INCOME',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04 > 18 ? 18 : screenWidth * 0.04,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.06),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: kIsWeb ? screenHeight * 0.5 : screenHeight * 0.6,
                      ),
                      child: FutureBuilder<List<String>>(
                        future: _getAllMonthYears(),
                        builder: (context, monthSnapshot) {
                          if (!monthSnapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final monthYears = monthSnapshot.data!;

                          if (monthYears.isEmpty) {
                            return Center(
                              child: Text(
                                'No income data available',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04 > 16 ? 16 : screenWidth * 0.04,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            physics: const ClampingScrollPhysics(),
                            itemCount: monthYears.length,
                            itemBuilder: (context, index) {
                              final monthYear = monthYears[index];
                              return StreamBuilder<QuerySnapshot>(
                                stream: _firestore
                                    .collection('users')
                                    .doc(userId)
                                    .collection('finance')
                                    .doc('income_tracker')
                                    .collection(monthYear)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return ListTile(
                                      title: Text(
                                        'Loading...',
                                        style: TextStyle(fontSize: screenWidth * 0.04 > 16 ? 16 : screenWidth * 0.04),
                                      ),
                                    );
                                  }
                                  final docs = snapshot.data!.docs;

                                  return Card(
                                    elevation: 4,
                                    margin: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                                    ),
                                    child: ExpansionTile(
                                      title: Text(
                                        monthYear,
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.045 > 18 ? 18 : screenWidth * 0.045,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF002386),
                                        ),
                                      ),
                                      subtitle: FutureBuilder<double>(
                                        future: _getMonthlyTotal(monthYear),
                                        builder: (context, totalSnapshot) {
                                          if (!totalSnapshot.hasData) {
                                            return Text(
                                              'Total: Calculating...',
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.04 > 16 ? 16 : screenWidth * 0.04,
                                                color: Colors.green,
                                              ),
                                            );
                                          }
                                          return Text(
                                            'Total: ${formatIndianRupees(totalSnapshot.data!)}',
                                            style: TextStyle(
                                              fontSize: screenWidth * 0.04 > 16 ? 16 : screenWidth * 0.04,
                                              color: Colors.green,
                                            ),
                                          );
                                        },
                                      ),
                                      children: [
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: docs.length,
                                          separatorBuilder: (context, index) => Divider(
                                            color: Colors.grey.shade300,
                                            height: 1,
                                          ),
                                          itemBuilder: (context, index) {
                                            final entry = docs[index].data() as Map<String, dynamic>;
                                            final docId = docs[index].id;

                                            return Dismissible(
                                              key: Key(docId),
                                              background: Container(
                                                color: Colors.red,
                                                alignment: Alignment.centerRight,
                                                padding: EdgeInsets.only(right: screenWidth * 0.05),
                                                child: Icon(
                                                  Icons.delete,
                                                  color: Colors.white,
                                                  size: screenWidth * 0.06 > 24 ? 24 : screenWidth * 0.06,
                                                ),
                                              ),
                                              direction: DismissDirection.endToStart,
                                              onDismissed: (direction) {
                                                _deleteIncome(monthYear, docId);
                                              },
                                              child: ListTile(
                                                contentPadding: EdgeInsets.symmetric(
                                                  horizontal: screenWidth * 0.04,
                                                  vertical: screenWidth * 0.02,
                                                ),
                                                title: Text(
                                                  entry['name'],
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: screenWidth * 0.04 > 16 ? 16 : screenWidth * 0.04,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    SizedBox(height: screenWidth * 0.01),
                                                    Text(
                                                      entry['date'],
                                                      style: TextStyle(fontSize: screenWidth * 0.035 > 14 ? 14 : screenWidth * 0.035),
                                                    ),
                                                    if (entry['notes'].isNotEmpty)
                                                      Text(
                                                        entry['notes'],
                                                        style: TextStyle(
                                                          fontStyle: FontStyle.italic,
                                                          fontSize: screenWidth * 0.035 > 14 ? 14 : screenWidth * 0.035,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 2,
                                                      ),
                                                  ],
                                                ),
                                                trailing: Text(
                                                  formatIndianRupees(entry['amount']),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: screenWidth * 0.04 > 16 ? 16 : screenWidth * 0.04,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Widget? suffixIcon,
    Widget? prefix,
    required double screenWidth,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon, color: const Color(0xFF002386)),
        suffixIcon: suffixIcon,
        prefix: prefix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
          borderSide: const BorderSide(color: Color(0xFF002386), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenWidth * 0.03 > 16 ? 16 : screenWidth * 0.03, // Cap padding
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }
}