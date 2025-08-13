import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'loginpage.dart';

class UserScreen extends StatefulWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  int _birthYear = DateTime.now().year - 25;
  int _age = 25;
  String _selectedGender = "Male";
  bool _isProfileComplete = false;
  TextEditingController heightController = TextEditingController();
  TextEditingController weightController = TextEditingController();
  String _selectedActivityLevel = "Sedentary";

  double? _bmi;
  String _bmiCategory = "";
  double? _tdee;
  double? _proteinNeeded;
  double? _waterNeeded;

  final List<int> _birthYears = List.generate(100, (index) => DateTime.now().year - 100 + index);
  final List<String> _genders = ["Male", "Female"];
  final List<String> _activityLevels = [
    "Sedentary",
    "Lightly Active",
    "Moderately Active",
    "Very Active",
    "Super Active"
  ];

  // Firebase Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Define color scheme based on the primary color
  final Color primaryColor = Color(0xFF002386);
  final Color accentColor = Color(0xFF003FCC);
  final Color lightBlue = Color(0xFFE3EAFF);

  @override
  void initState() {
    super.initState();
    heightController.text = "170";
    weightController.text = "70";
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = widget._auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userData = await _firestore.collection('users').doc(user.uid).get();
        
        if (userData.exists) {
          Map<String, dynamic> data = userData.data() as Map<String, dynamic>;
          setState(() {
            _birthYear = data['birthYear'] ?? DateTime.now().year - 25;
            _age = DateTime.now().year - _birthYear;
            _selectedGender = data['gender'] ?? "Male";
            _isProfileComplete = data['profileComplete'] ?? false;
            heightController.text = data['height']?.toString() ?? "170";
            weightController.text = data['weight']?.toString() ?? "70";
            _selectedActivityLevel = data['activityLevel'] ?? "Sedentary";
          });
        }
      } catch (e) {
        print("Error loading user data: $e");
      }
    }
    calculateMetrics();
  }

  Future<void> _saveUserData() async {
    User? user = widget._auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'birthYear': _birthYear,
          'gender': _selectedGender,
          'profileComplete': true,
          'height': double.tryParse(heightController.text) ?? 170,
          'weight': double.tryParse(weightController.text) ?? 70,
          'activityLevel': _selectedActivityLevel,
          'email': user.email,
          'displayName': user.displayName,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print("Error saving user data: $e");
      }
    }
  }

  void calculateMetrics() {
    double height = double.tryParse(heightController.text) ?? 170;
    double weight = double.tryParse(weightController.text) ?? 70;

    double heightInMeters = height / 100;
    double bmi = weight / (heightInMeters * heightInMeters);
    double bmr = _selectedGender == "Male"
        ? 10 * weight + 6.25 * height - 5 * _age + 5
        : 10 * weight + 6.25 * height - 5 * _age - 161;

    double activityMultiplier = {
      "Sedentary": 1.2,
      "Lightly Active": 1.375,
      "Moderately Active": 1.55,
      "Very Active": 1.725,
      "Super Active": 1.9
    }[_selectedActivityLevel] ?? 1.2;

    double proteinMultiplier = {
      "Sedentary": 1.2,
      "Lightly Active": 1.4,
      "Moderately Active": 1.6,
      "Very Active": 1.8,
      "Super Active": 2.2
    }[_selectedActivityLevel] ?? 1.2;
    
    // Water multiplier based on activity level (ml per kg)
    double waterMultiplier = {
      "Sedentary": 30.0,
      "Lightly Active": 35.0,
      "Moderately Active": 40.0,
      "Very Active": 45.0,
      "Super Active": 50.0
    }[_selectedActivityLevel] ?? 30.0;

    setState(() {
      _bmi = bmi;
      _tdee = bmr * activityMultiplier;
      _proteinNeeded = weight * proteinMultiplier;
      _waterNeeded = weight * waterMultiplier; // water in ml
      _bmiCategory = bmi < 18.5 ? "Underweight" :
                    bmi < 24.9 ? "Normal weight" :
                    bmi < 29.9 ? "Overweight" : "Obese";
    });
    
    // Save the calculated metrics to Firestore
    _saveMetrics();
  }
  
  Future<void> _saveMetrics() async {
    User? user = widget._auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'metrics': {
            'bmi': _bmi,
            'bmiCategory': _bmiCategory,
            'tdee': _tdee,
            'proteinNeeded': _proteinNeeded,
            'waterNeeded': _waterNeeded,
            'lastCalculated': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      } catch (e) {
        print("Error saving metrics: $e");
      }
    }
  }

  void _completeProfile() {
    setState(() {
      _isProfileComplete = true;
    });
    _saveUserData();
    calculateMetrics();
  }

  void logout(BuildContext context) async {
    await widget._auth.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    User? user = widget._auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text("User Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        toolbarHeight: 80,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50, 
              backgroundColor: accentColor,
              child: Text(
                (user?.displayName ?? "U")[0].toUpperCase(),
                style: TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            SizedBox(height: 15),
            Text(
              user?.displayName ?? "User Name",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
            ),
            Text(
              user?.email ?? "user@email.com", 
              style: TextStyle(color: Colors.grey, fontSize: 16)
            ),
            Divider(color: lightBlue, thickness: 2, height: 30),

            _isProfileComplete ? _buildProfileInfo() : _buildProfileSetup(),
            SizedBox(height: 15),

            Row(
              children: [
                Expanded(child: _buildTextField("Height (cm)", heightController)),
                SizedBox(width: 10),
                Expanded(child: _buildTextField("Weight (kg)", weightController)),
              ],
            ),
            SizedBox(height: 15),

            _buildDropdown("Activity Level", _selectedActivityLevel, _activityLevels, (String value) {
              setState(() {
                _selectedActivityLevel = value;
                _saveUserData();
                calculateMetrics();
              });
            }),
            SizedBox(height: 25),

            // Metrics Card with larger text
            Container(
              decoration: BoxDecoration(
                color: lightBlue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    "Your Fitness Metrics",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: 15),
                  _buildMetricRow("BMI", _bmi?.toStringAsFixed(2) ?? "-"),
                  _buildMetricRow("Category", _bmiCategory),
                  _buildMetricRow("TDEE", "${_tdee?.toStringAsFixed(2) ?? "-"} kcal/day"),
                  _buildMetricRow("Protein Needed", "${_proteinNeeded?.toStringAsFixed(2) ?? "-"} g/day"),
                  _buildMetricRow("Water Needed", _formatWaterIntake(_waterNeeded)),
                ],
              ),
            ),
            SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: () => logout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.logout, color: Colors.white),
              label: Text("Logout", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWaterIntake(double? waterInMl) {
    if (waterInMl == null) return "-";
    
    // Format water intake in both ml and liters for better readability
    double liters = waterInMl / 1000;
    return "${waterInMl.toStringAsFixed(0)} ml (${liters.toStringAsFixed(2)} L)/day";
  }

  Widget _buildProfileInfo() {
    return Row(
      children: [
        Expanded(
          child: _buildFixedField("Age", _age.toString()),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _buildFixedField("Gender", _selectedGender),
        ),
      ],
    );
  }

  Widget _buildFixedField(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSetup() {
    return Column(
      children: [
        Text(
          "Complete Your Profile",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _buildDropdown("Birth Year", _birthYear, _birthYears, (int value) {
              setState(() {
                _birthYear = value;
                _age = DateTime.now().year - value;
              });
            })),
            SizedBox(width: 10),
            Expanded(child: _buildDropdown("Gender", _selectedGender, _genders, (String value) {
              setState(() {
                _selectedGender = value;
              });
            })),
          ],
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: _completeProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text("Complete Profile", style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
      ),
      onChanged: (value) {
        _saveUserData();
        calculateMetrics();
      },
    );
  }

  Widget _buildDropdown<T>(String label, T selectedValue, List<T> items, ValueChanged<T> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          )
        ),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<T>(
            value: selectedValue,
            isExpanded: true,
            underline: SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: primaryColor),
            items: items.map((T value) {
              return DropdownMenuItem<T>(
                value: value,
                child: Text(value.toString()),
              );
            }).toList(),
            onChanged: (value) => onChanged(value as T),
          ),
        ),
      ],
    );
  }
}