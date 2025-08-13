import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finfit/foodrecommend.dart'; // Add this import for FoodRecommender

class NutritionHomeScreen extends StatefulWidget {
  const NutritionHomeScreen({Key? key}) : super(key: key);
  @override
  State<NutritionHomeScreen> createState() => _NutritionHomePageState();
}

class _NutritionHomePageState extends State<NutritionHomeScreen> {
  final Map<String, List<Map<String, dynamic>>> _meals = {
    'Breakfast': [],
    'Lunch': [],
    'Dinner': [],
    'Extras': [],
  };

  Map<String, Map<String, double>> _mealTotals = {
    'Breakfast': {'calories': 0, 'protein': 0},
    'Lunch': {'calories': 0, 'protein': 0},
    'Dinner': {'calories': 0, 'protein': 0},
    'Extras': {'calories': 0, 'protein': 0},
  };

  Map<String, double> _persistentNutrients = {
    'Calories': 0,
    'Protein': 0,
    'Carbs': 0,
    'Fat': 0,
  };

  double _tdee = 0;
  double _proteinNeeded = 0;
  bool _isNutritionTargetsLoaded = false;

  final Color primaryColor = const Color(0xFF002386);
  List<Map<String, dynamic>> dailyTotals = [];
  bool _isDataLoaded = false;
  String? _userId;
  
  DateTime _selectedDate = DateTime.now();
  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      _loadAllData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to track your nutrition')),
      );
    }
  }

  Future<void> _loadAllData() async {
    if (_userId == null) return;
    
    await fetchUserNutritionTargets();
    await fetchMealData();
    await fetchDailyTotals();
    _calculatePersistentNutrients();
    
    setState(() {
      _isDataLoaded = true;
    });
  }

  Future<void> fetchUserNutritionTargets() async {
    if (_userId == null) return;
    
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        if (userData.containsKey('metrics') && userData['metrics'] != null) {
          Map<String, dynamic> metrics = userData['metrics'];
          setState(() {
            _tdee = (metrics['tdee'] ?? 2000).toDouble();
            _proteinNeeded = (metrics['proteinNeeded'] ?? 50).toDouble();
            _isNutritionTargetsLoaded = true;
          });
        } else {
          print("No metrics found, using defaults");
          setState(() {
            _tdee = 2000;
            _proteinNeeded = 50;
            _isNutritionTargetsLoaded = true;
          });
        }
      }
    } catch (e) {
      print("Error fetching targets: $e");
      setState(() {
        _tdee = 2000;
        _proteinNeeded = 50;
        _isNutritionTargetsLoaded = true;
      });
    }
  }

  void _calculatePersistentNutrients() {
    _persistentNutrients = {
      'Calories': 0,
      'Protein': 0,
      'Carbs': 0,
      'Fat': 0,
    };

    _meals.values.expand((list) => list).forEach((item) {
      _persistentNutrients['Calories'] = (_persistentNutrients['Calories'] ?? 0) + (item['calories'] ?? 0).toDouble();
      _persistentNutrients['Protein'] = (_persistentNutrients['Protein'] ?? 0) + (item['protein_g'] ?? 0).toDouble();
      _persistentNutrients['Carbs'] = (_persistentNutrients['Carbs'] ?? 0) + (item['carbohydrates_total_g'] ?? 0).toDouble();
      _persistentNutrients['Fat'] = (_persistentNutrients['Fat'] ?? 0) + (item['fat_total_g'] ?? 0).toDouble();
    });
    print('Calculated persistent nutrients: $_persistentNutrients');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded && _userId != null) {
      _loadAllData();
    }
  }

  void _changeDate(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
      _isDataLoaded = false;
    });
    _loadAllData();
  }

  void _openNutritionDetails(String mealType) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add meal data')),
      );
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NutritionDetailsPage(
          mealType: mealType,
          primaryColor: primaryColor,
        ),
      ),
    );
    
    if (result != null) {
      bool itemExists = false;
      for (var item in _meals[mealType]!) {
        if (item['name'] == result['name'] && item['quantity_g'] == result['quantity_g']) {
          itemExists = true;
          break;
        }
      }
      
      if (!itemExists) {
        setState(() {
          _meals[mealType]?.add(result);
          _updateMealTotals(mealType);
          saveMealData(mealType);
          saveDailyTotals();
          _calculatePersistentNutrients();
        });
      }
    }
  }

  Future<void> saveMealData(String mealType) async {
    if (_userId == null) return;
    
    final DocumentReference mealDocRef = FirebaseFirestore.instance
        .collection('users/$_userId/meals')
        .doc(_formattedDate)
        .collection('meal_types')
        .doc(mealType);

    Map<String, dynamic> mealData = {
      'mealType': mealType,
      'items': _meals[mealType],
      'date': _formattedDate,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await mealDocRef.set(mealData);
  }

  Future<void> saveDailyTotals() async {
    if (_userId == null) return;
    
    final DocumentReference dailyTotalsRef = FirebaseFirestore.instance
        .collection('users/$_userId/daily_nutrition_totals')
        .doc(_formattedDate);

    Map<String, dynamic> dailyData = {
      'date': _formattedDate,
      'totalCalories': (_mealTotals['Breakfast']!['calories'] ?? 0) +
          (_mealTotals['Lunch']!['calories'] ?? 0) +
          (_mealTotals['Dinner']!['calories'] ?? 0) +
          (_mealTotals['Extras']!['calories'] ?? 0),
      'totalProtein': (_mealTotals['Breakfast']!['protein'] ?? 0) +
          (_mealTotals['Lunch']!['protein'] ?? 0) +
          (_mealTotals['Dinner']!['protein'] ?? 0) +
          (_mealTotals['Extras']!['protein'] ?? 0),
      'totalCarbs': _persistentNutrients['Carbs'],
      'totalFat': _persistentNutrients['Fat'],
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await dailyTotalsRef.set(dailyData, SetOptions(merge: true));
  }

  Future<void> fetchDailyTotals() async {
    if (_userId == null) return;
    
    final CollectionReference userDailyTotalsCollection = 
        FirebaseFirestore.instance.collection('users/$_userId/daily_nutrition_totals');

    try {
      QuerySnapshot snapshot = await userDailyTotalsCollection
          .orderBy('date', descending: true)
          .limit(30)
          .get();
          
      dailyTotals.clear();
      for (var doc in snapshot.docs) {
        dailyTotals.add(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print("Error fetching daily totals: $e");
    }
  }

  Future<void> fetchMealData() async {
    if (_userId == null) return;
    
    _meals.forEach((key, value) {
      value.clear();
    });
    
    try {
      DocumentReference dateRef = FirebaseFirestore.instance
          .collection('users/$_userId/meals')
          .doc(_formattedDate);
      
      CollectionReference mealTypesCollection = dateRef.collection('meal_types');
      QuerySnapshot mealTypesSnapshot = await mealTypesCollection.get();
      
      for (var doc in mealTypesSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String mealType = data['mealType'];
        
        if (data['items'] != null) {
          List<dynamic> items = data['items'] as List<dynamic>;
          if (_meals.containsKey(mealType)) {
            _meals[mealType] = items.map((item) => Map<String, dynamic>.from(item)).toList();
          }
        }
      }

      _mealTotals.forEach((key, value) {
        _updateMealTotals(key);
      });
    } catch (e) {
      print("Error fetching meal data: $e");
    }
  }

  void _updateMealTotals(String mealType) {
    double calories = 0;
    double protein = 0;

    for (var item in _meals[mealType]!) {
      calories += (item['calories'] ?? 0);
      protein += (item['protein_g'] ?? 0);
    }

    setState(() {
      _mealTotals[mealType] = {
        'calories': calories,
        'protein': protein,
      };
    });
  }

  void _navigateToProfileSettings() {
    Navigator.pushNamed(context, '/profile').then((_) {
      if (_userId != null) {
        fetchUserNutritionTargets();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Eat well, live well',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null && picked != _selectedDate) {
                _changeDate(picked);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.restaurant_menu, color: Colors.white),
            onPressed: () {
              double remainingCals = _tdee - (_persistentNutrients['Calories'] ?? 0);
              double remainingProt = _proteinNeeded - (_persistentNutrients['Protein'] ?? 0);
              print('Navigating to FoodRecommender:');
              print('TDEE: $_tdee');
              print('Consumed Calories: ${_persistentNutrients['Calories']}');
              print('Remaining Calories: $remainingCals');
              print('Protein Needed: $_proteinNeeded');
              print('Consumed Protein: ${_persistentNutrients['Protein']}');
              print('Remaining Protein: $remainingProt');
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FoodRecommender(
                    remainingCalories: remainingCals,
                    remainingProtein: remainingProt,
                  ),
                ),
              ).then((result) {
                if (result != null) {
                  setState(() {
                    _meals['Extras']?.add(result);
                    _updateMealTotals('Extras');
                    saveMealData('Extras');
                    saveDailyTotals();
                    _calculatePersistentNutrients();
                  });
                }
              });
            },
          ),
        ],
      ),
      body: _userId == null 
          ? _buildLoginPrompt()
          : (_isDataLoaded ? _buildContent() : _buildLoadingIndicator()),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle, size: 80, color: primaryColor),
          const SizedBox(height: 16),
          Text(
            'Please log in to view your nutrition data',
            style: TextStyle(
              color: primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Log In', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 16),
          Text(
            'Loading nutrition data...',
            style: TextStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isNutritionTargetsLoaded && (_tdee > 0 || _proteinNeeded > 0))
              _buildNutritionGoalsCard(),
            ..._meals.keys.map((mealType) => _buildMealCard(mealType, Icons.fastfood)),
            _buildNutritionSummaryCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: primaryColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionGoalsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Nutrition Goals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildGoalItem(
                'Daily Calories',
                '${_tdee.toStringAsFixed(0)} cal',
                Icons.local_fire_department,
              ),
              _buildGoalItem(
                'Daily Protein',
                '${_proteinNeeded.toStringAsFixed(0)} g',
                Icons.fitness_center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(String mealType, IconData icon) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 28, color: primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      mealType,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.add_circle, color: primaryColor, size: 28),
                  onPressed: () => _openNutritionDetails(mealType),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _meals[mealType]!.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No items added',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _meals[mealType]!.length,
                  itemBuilder: (context, index) {
                    final item = _meals[mealType]![index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        item['name'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                        '${item['quantity_g']?.toStringAsFixed(1) ?? item['serving_size_g']?.toStringAsFixed(1) ?? 0}g - ${item['calories']?.toStringAsFixed(1) ?? 0} cal, ${item['protein_g']?.toStringAsFixed(1) ?? 0}g protein',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, size: 22),
                        onPressed: () {
                          setState(() {
                            _meals[mealType]!.removeAt(index);
                            _updateMealTotals(mealType);
                            saveMealData(mealType);
                            _calculatePersistentNutrients();
                            saveDailyTotals();
                          });
                        },
                      ),
                    );
                  },
                ),
          Container(
            color: primaryColor.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${_mealTotals[mealType]!['calories']!.toStringAsFixed(1)} cal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  '${_mealTotals[mealType]!['protein']!.toStringAsFixed(1)}g protein',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummaryCard() {
    double consumedCalories = _persistentNutrients['Calories'] ?? 0;
    double consumedProtein = _persistentNutrients['Protein'] ?? 0;
    double consumedCarbs = _persistentNutrients['Carbs'] ?? 0;
    double consumedFat = _persistentNutrients['Fat'] ?? 0;
    
    double remainingCalories = _tdee - consumedCalories;
    double remainingProtein = _proteinNeeded - consumedProtein;
    
    double caloriesPercentage = _tdee > 0 ? (consumedCalories / _tdee) * 100 : 0;
    double proteinPercentage = _proteinNeeded > 0 ? (consumedProtein / _proteinNeeded) * 100 : 0;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Calories: ${consumedCalories.toStringAsFixed(0)} / ${_tdee.toStringAsFixed(0)} cal (${caloriesPercentage.toStringAsFixed(1)}%)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: caloriesPercentage > 100 ? Colors.red : primaryColor,
            ),
          ),
          Text(
            'Remaining: ${remainingCalories.toStringAsFixed(0)} cal',
            style: TextStyle(
              fontSize: 14,
              color: remainingCalories < 0 ? Colors.red : Colors.green,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Daily Protein: ${consumedProtein.toStringAsFixed(0)} / ${_proteinNeeded.toStringAsFixed(0)}g (${proteinPercentage.toStringAsFixed(1)}%)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: proteinPercentage > 100 ? Colors.red : primaryColor,
            ),
          ),
          Text(
            'Remaining: ${remainingProtein.toStringAsFixed(0)}g',
            style: TextStyle(
              fontSize: 14,
              color: remainingProtein < 0 ? Colors.red : Colors.green,
            ),
          ),
          
          const SizedBox(height: 16),
          Divider(color: Colors.grey[300]),
          
          Text(
            'Other Nutrients',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text('Carbs: ${consumedCarbs.toStringAsFixed(1)}g'),
          Text('Fat: ${consumedFat.toStringAsFixed(1)}g'),
        ],
      ),
    );
  }

  Widget _buildSimpleNutrientInfo(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 5)],
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, Icons.home, "Home", false, '/home'),
          _buildNavItem(context, Icons.bar_chart, "Finance", false, '/finance'),
          _buildNavItem(context, Icons.restaurant, "Nutrition", true, '/nut'),
          _buildNavItem(context, Icons.fitness_center, "Workout", false, '/workout'),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isSelected, String route) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? primaryColor : Colors.grey, size: 28),
          SizedBox(height: 4),
          Text(label, style: TextStyle(color: isSelected ? primaryColor : Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class NutritionDetailsPage extends StatefulWidget {
  final String mealType;
  final Color primaryColor;

  const NutritionDetailsPage({
    Key? key,
    required this.mealType,
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<NutritionDetailsPage> createState() => _NutritionDetailsPageState();
}

class _NutritionDetailsPageState extends State<NutritionDetailsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  bool _isLoading = false;
  String? _imageUrl;
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedFood;
  double _quantity = 100;

  @override
  void initState() {
    super.initState();
    _quantityController.text = _quantity.toString();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _searchFood(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _searchResults = [];
      _selectedFood = null;
      _imageUrl = null;
    });
    
    try {
      final apiUrl = 'https://api.calorieninjas.com/v1/nutrition?query=$query';
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'X-Api-Key': 'kq5i2HIgfJAfjgi2mGvm6Q==U0AUPxf3nbjTqtFe',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('items') && data['items'] is List) {
          final nutritionItems = List<Map<String, dynamic>>.from(data['items']);
          
          if (nutritionItems.isNotEmpty) {
            try {
              final pexelsResponse = await http.get(
                Uri.parse('https://api.pexels.com/v1/search?query=$query&per_page=1'),
                headers: {
                  'Authorization': 'MV2HEe45oV4oQ0O2h6M6b4okNvZS0tcl7cL8uiCSHYAgfEUidvx3rWLx'
                },
              );
              
              if (pexelsResponse.statusCode == 200) {
                final pexelsData = json.decode(pexelsResponse.body);
                if (pexelsData['photos'] != null && pexelsData['photos'].isNotEmpty) {
                  setState(() {
                    _imageUrl = pexelsData['photos'][0]['src']['medium'];
                    _searchResults = nutritionItems;
                    _isLoading = false;
                  });
                  return;
                }
              }
            } catch (pexelsError) {
              print('Pexels API error: $pexelsError');
            }
          }
          
          setState(() {
            _searchResults = nutritionItems;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching for food. Please try again.')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  void _selectFood(Map<String, dynamic> food) {
    setState(() {
      _selectedFood = food;
      _quantity = food['serving_size_g'] ?? 100;
      _quantityController.text = _quantity.toString();
    });
  }

  void _updateQuantity(String value) {
    try {
      final newQuantity = double.parse(value);
      if (newQuantity > 0) {
        setState(() {
          _quantity = newQuantity;
        });
      }
    } catch (e) {
      // Invalid input, keep existing quantity
    }
  }

  Map<String, dynamic> _calculateAdjustedNutrition() {
    if (_selectedFood == null) return {};

    final servingSize = _selectedFood!['serving_size_g'] ?? 100;
    final ratio = _quantity / servingSize;

    return {
      'name': _selectedFood!['name'],
      'quantity_g': _quantity,
      'calories': (_selectedFood!['calories'] ?? 0) * ratio,
      'protein_g': (_selectedFood!['protein_g'] ?? 0) * ratio,
      'fat_total_g': (_selectedFood!['fat_total_g'] ?? 0) * ratio,
      'carbohydrates_total_g': (_selectedFood!['carbohydrates_total_g'] ?? 0) * ratio,
      'serving_size_g': servingSize,
      'image_url': _imageUrl,
    };
  }

  void _addFoodToMeal() {
    if (_selectedFood != null) {
      Navigator.pop(context, _calculateAdjustedNutrition());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add to ${widget.mealType}'),
        backgroundColor: widget.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search for a food',
                hintText: 'e.g., apple, chicken breast, rice',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search, color: widget.primaryColor),
                  onPressed: () => _searchFood(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: widget.primaryColor, width: 2.0),
                ),
              ),
              onSubmitted: _searchFood,
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
                : _selectedFood != null
                  ? _buildSelectedFoodDetails()
                  : _buildSearchResults(),
            ),
            if (_selectedFood != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addFoodToMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                  ),
                  child: Text(
                    'Add to ${widget.mealType}',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'Search for foods to add to your meal',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_imageUrl != null)
          Container(
            height: 200,
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(_imageUrl!),
                fit: BoxFit.cover,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final food = _searchResults[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  title: Text(
                    food['name'] ?? 'Unknown Food',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${food['serving_size_g']?.toStringAsFixed(0) ?? "100"}g - ${food['calories']?.toStringAsFixed(0) ?? "0"} cal, ${food['protein_g']?.toStringAsFixed(1) ?? "0"}g protein',
                  ),
                  trailing: Icon(Icons.add_circle, color: widget.primaryColor),
                  onTap: () => _selectFood(food),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedFoodDetails() {
    if (_selectedFood == null) return Container();
    
    final adjustedNutrition = _calculateAdjustedNutrition();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: widget.primaryColor),
                onPressed: () {
                  setState(() {
                    _selectedFood = null;
                  });
                },
              ),
              Expanded(
                child: Text(
                  _selectedFood!['name'] ?? 'Unknown Food',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          if (_imageUrl != null)
            Container(
              height: 200,
              width: double.infinity,
              margin: EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(_imageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity (g)',
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: widget.primaryColor, width: 2.0),
                    ),
                  ),
                  onChanged: _updateQuantity,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle, color: widget.primaryColor),
                    onPressed: () {
                      setState(() {
                        _quantity += 10;
                        _quantityController.text = _quantity.toString();
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.remove_circle, color: widget.primaryColor),
                    onPressed: () {
                      if (_quantity > 10) {
                        setState(() {
                          _quantity -= 10;
                          _quantityController.text = _quantity.toString();
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nutrition Facts (${_quantity.toStringAsFixed(0)}g)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.primaryColor,
                    ),
                  ),
                  Divider(color: Colors.grey),
                  _buildNutritionRow(
                    'Calories',
                    '${adjustedNutrition['calories']?.toStringAsFixed(0) ?? "0"} cal',
                    Icons.local_fire_department,
                    Colors.orange,
                  ),
                  _buildNutritionRow(
                    'Protein',
                    '${adjustedNutrition['protein_g']?.toStringAsFixed(1) ?? "0"} g',
                    Icons.fitness_center,
                    Colors.red,
                  ),
                  _buildNutritionRow(
                    'Carbohydrates',
                    '${adjustedNutrition['carbohydrates_total_g']?.toStringAsFixed(1) ?? "0"} g',
                    Icons.grain,
                    Colors.amber,
                  ),
                  _buildNutritionRow(
                    'Fat',
                    '${adjustedNutrition['fat_total_g']?.toStringAsFixed(1) ?? "0"} g',
                    Icons.opacity,
                    Colors.yellow[700]!,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 16),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}