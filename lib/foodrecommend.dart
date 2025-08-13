import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // For randomization

class FoodRecommender extends StatefulWidget {
  final double remainingCalories;
  final double remainingProtein;

  const FoodRecommender({
    super.key,
    required this.remainingCalories,
    required this.remainingProtein,
  });

  @override
  State<FoodRecommender> createState() => _FoodRecommenderState();
}

class _FoodRecommenderState extends State<FoodRecommender> {
  List<Map<String, dynamic>> _recommendedFoods = [];
  bool _isLoading = false;
  final Color primaryColor = const Color(0xFF002386);
  final Random _random = Random(); // For random selection

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('foods')
          .get();

      List<Map<String, dynamic>> foods = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();

      // Define "close" as within 20% of remaining goals
      const double calorieThreshold = 0.8; // 20%
      const double proteinThreshold = 0.8; // 20%
      double minCalories = widget.remainingCalories * (1 - calorieThreshold);
      double maxCalories = widget.remainingCalories * (1 + calorieThreshold);
      double minProtein = widget.remainingProtein * (1 - proteinThreshold);
      double maxProtein = widget.remainingProtein * (1 + proteinThreshold);

      // Filter foods that are close to remaining goals
      List<Map<String, dynamic>> closeFoods = foods.where((food) {
        double calories = (food['nutrition']['calories'] ?? 0).toDouble();
        double protein = (food['nutrition']['protein'] ?? 0).toDouble();

        // Only include foods with positive protein and within threshold
        return protein > 0 &&
            calories >= minCalories &&
            calories <= maxCalories &&
            protein >= minProtein &&
            protein <= maxProtein;
      }).toList();

      // If no foods are close, fall back to all foods with some protein
      if (closeFoods.isEmpty && widget.remainingCalories > 0 && widget.remainingProtein > 0) {
        closeFoods = foods.where((food) {
          double calories = (food['nutrition']['calories'] ?? 0).toDouble();
          double protein = (food['nutrition']['protein'] ?? 0).toDouble();
          return protein > 0 && calories <= widget.remainingCalories;
        }).toList();
      }

      // Randomly select up to 5 foods (or fewer if less available)
      _recommendedFoods = [];
      if (closeFoods.isNotEmpty) {
        closeFoods.shuffle(_random); // Shuffle the list randomly
        _recommendedFoods = closeFoods.take(5).toList(); // Take up to 5 items
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching recommendations: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading recommendations: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('FoodRecommender received:');
    print('Remaining Calories: ${widget.remainingCalories}');
    print('Remaining Protein: ${widget.remainingProtein}');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Food Recommendations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRecommendations, // Refresh will fetch new random recommendations
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGoalsHeader(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _recommendedFoods.isEmpty
                        ? _buildEmptyState()
                        : _buildRecommendationsList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGoalsHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildGoalItem(
              'Calories Left',
              '${widget.remainingCalories.clamp(0, double.infinity).toStringAsFixed(0)} cal',
              Icons.local_fire_department,
            ),
            _buildGoalItem(
              'Protein Left',
              '${widget.remainingProtein.clamp(0, double.infinity).toStringAsFixed(0)} g',
              Icons.fitness_center,
            ),
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.food_bank_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            widget.remainingCalories <= 0 && widget.remainingProtein <= 0
                ? 'Goals met! No close matches found'
                : 'No foods found close to your remaining goals',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsList() {
    return ListView.builder(
      itemCount: _recommendedFoods.length,
      itemBuilder: (context, index) {
        final food = _recommendedFoods[index];
        final nutrition = food['nutrition'] as Map<String, dynamic>;
        final servingSize = food['servingSize'] as Map<String, dynamic>;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            title: Text(
              food['name'] ?? 'Unknown Food',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${servingSize['amount']} ${servingSize['unit']} - '
                  '${nutrition['calories']} cal, '
                  '${nutrition['protein']}g protein',
                ),
                Text(
                  'Carbs: ${nutrition['carbs']}g, Fat: ${nutrition['fat']}g',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.add_circle, color: primaryColor),
              onPressed: () {
                final foodData = {
                  'name': food['name'],
                  'quantity_g': servingSize['amount'].toDouble(),
                  'calories': nutrition['calories'].toDouble(),
                  'protein_g': nutrition['protein'].toDouble(),
                  'carbohydrates_total_g': nutrition['carbs'].toDouble(),
                  'fat_total_g': nutrition['fat'].toDouble(),
                };
                Navigator.pop(context, foodData);
              },
            ),
          ),
        );
      },
    );
  }
}