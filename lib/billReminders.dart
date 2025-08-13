import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BillRemindersPage extends StatefulWidget {
  const BillRemindersPage({super.key});

  @override
  _BillRemindersPageState createState() => _BillRemindersPageState();
}

class _BillRemindersPageState extends State<BillRemindersPage> {
  final TextEditingController _billNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDueDate;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  void _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
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

    if (picked != null && picked != _selectedDueDate) {
      setState(() {
        _selectedDueDate = picked;
        final DateFormat formatter = DateFormat('yyyy-MM-dd');
        _dueDateController.text = formatter.format(picked);
      });
    }
  }

  Future<void> _addBill() async {
    if (_billNameController.text.isNotEmpty &&
        _amountController.text.isNotEmpty &&
        _dueDateController.text.isNotEmpty &&
        userId != null) {
      final bill = {
        'name': _billNameController.text,
        'amount': double.tryParse(_amountController.text) ?? 0,
        'dueDate': _dueDateController.text,
        'notes': _notesController.text,
        'isPaid': false,
        'timestamp': Timestamp.fromDate(_selectedDueDate ?? DateTime.now()),
      };

      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('finance')
            .doc('bill_reminders')
            .collection('bills')
            .add(bill);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill added successfully!'),
            backgroundColor: Color(0xFF002386),
            behavior: SnackBarBehavior.floating,
          ),
        );

        _billNameController.clear();
        _amountController.clear();
        _dueDateController.clear();
        _notesController.clear();
        setState(() {
          _selectedDueDate = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding bill: $e'),
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

  Future<void> _togglePaidStatus(String docId, bool currentStatus) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance')
          .doc('bill_reminders')
          .collection('bills')
          .doc(docId)
          .update({'isPaid': !currentStatus});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating bill status: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final paddingScale = kIsWeb ? 0.02 : 0.04; // Smaller padding for web

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bill Reminders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: screenWidth * 0.05 > 24 ? 24 : screenWidth * 0.05, // Cap font size for web
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF002386),
        elevation: 0,
      ),
      body: LayoutBuilder(
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
                            'Add New Bill',
                            style: TextStyle(
                              fontSize: screenWidth * 0.05 > 20 ? 20 : screenWidth * 0.05,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF002386),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          _buildTextField(
                            controller: _billNameController,
                            label: 'Bill Name',
                            icon: Icons.description_outlined,
                            required: true,
                            screenWidth: screenWidth,
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          _buildTextField(
                            controller: _amountController,
                            label: 'Amount',
                            icon: Icons.currency_rupee,
                            keyboardType: TextInputType.number,
                            required: true,
                            prefix: const Text('₹'),
                            screenWidth: screenWidth,
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          GestureDetector(
                            onTap: _selectDueDate,
                            child: AbsorbPointer(
                              child: _buildTextField(
                                controller: _dueDateController,
                                label: 'Due Date',
                                icon: Icons.event,
                                required: true,
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                                screenWidth: screenWidth,
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          _buildTextField(
                            controller: _notesController,
                            label: 'Notes (optional)',
                            icon: Icons.note_alt_outlined,
                            maxLines: 2,
                            screenWidth: screenWidth,
                          ),
                          SizedBox(height: screenHeight * 0.03),
                          SizedBox(
                            width: double.infinity,
                            height: screenHeight * 0.06 > 60 ? 60 : screenHeight * 0.06, // Cap height
                            child: ElevatedButton(
                              onPressed: _addBill,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF002386),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                'ADD BILL',
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
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    'Upcoming Bills',
                    style: TextStyle(
                      fontSize: screenWidth * 0.05 > 20 ? 20 : screenWidth * 0.05,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF002386),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(userId)
                        .collection('finance')
                        .doc('bill_reminders')
                        .collection('bills')
                        .orderBy('timestamp')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final bills = snapshot.data!.docs;

                      if (bills.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(screenWidth * 0.05),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: screenWidth * 0.15 > 80 ? 80 : screenWidth * 0.15,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Text(
                                  'No bills added yet',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04 > 16 ? 16 : screenWidth * 0.04,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: kIsWeb ? screenHeight * 0.5 : screenHeight * 0.7,
                        ),
                        child: ListView.builder(
                          physics: const ClampingScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: bills.length,
                          itemBuilder: (context, index) {
                            final bill = bills[index].data() as Map<String, dynamic>;
                            final docId = bills[index].id;

                            return Card(
                              elevation: 2,
                              margin: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                side: BorderSide(
                                  color: _getDueDateColor(bill['dueDate']),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                  vertical: screenHeight * 0.01,
                                ),
                                leading: CircleAvatar(
                                  radius: screenWidth * 0.05 > 30 ? 30 : screenWidth * 0.05,
                                  backgroundColor: const Color(0xFF002386).withOpacity(0.1),
                                  child: Icon(
                                    Icons.receipt,
                                    color: const Color(0xFF002386),
                                    size: screenWidth * 0.06 > 24 ? 24 : screenWidth * 0.06,
                                  ),
                                ),
                                title: Text(
                                  bill['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: screenWidth * 0.045 > 18 ? 18 : screenWidth * 0.045,
                                    decoration: bill['isPaid'] ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: screenHeight * 0.005),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: screenWidth * 0.035 > 14 ? 14 : screenWidth * 0.035,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(width: screenWidth * 0.01),
                                        Flexible(
                                          child: Text(
                                            'Due: ${bill['dueDate']}',
                                            style: TextStyle(
                                              color: _getDueDateColor(bill['dueDate']),
                                              fontSize: screenWidth * 0.035 > 14 ? 14 : screenWidth * 0.035,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: screenHeight * 0.005),
                                    if (bill['notes'] != null && bill['notes'].isNotEmpty)
                                      Flexible(
                                        child: Text(
                                          bill['notes'],
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            fontSize: screenWidth * 0.035 > 14 ? 14 : screenWidth * 0.035,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₹${bill['amount'].toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: screenWidth * 0.04 > 16 ? 16 : screenWidth * 0.04,
                                        color: bill['isPaid'] ? Colors.grey : const Color(0xFF002386),
                                      ),
                                    ),
                                    SizedBox(width: screenWidth * 0.02),
                                    IconButton(
                                      icon: Icon(
                                        bill['isPaid']
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: bill['isPaid'] ? Colors.green : Colors.grey,
                                        size: screenWidth * 0.06 > 24 ? 24 : screenWidth * 0.06,
                                      ),
                                      onPressed: () => _togglePaidStatus(docId, bill['isPaid']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
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
          vertical: screenWidth * 0.03 > 16 ? 16 : screenWidth * 0.03,
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Color _getDueDateColor(String dateStr) {
    try {
      final dueDate = DateFormat('yyyy-MM-dd').parse(dateStr);
      final today = DateTime.now();
      final difference = dueDate.difference(today).inDays;

      if (difference < 0) {
        return Colors.red; // Overdue
      } else if (difference <= 3) {
        return Colors.orange; // Due soon
      } else {
        return Colors.green; // Due later
      }
    } catch (e) {
      return Colors.grey; // Invalid date format
    }
  }
}