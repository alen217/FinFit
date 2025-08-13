import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'dart:convert';

// Global map to store exercise GIF mappings (title -> URL), case-insensitive
Map<String, String> exerciseGifs = {};

class WorkoutHomePage extends StatefulWidget {
  final Map<String, double>? nutrients;

  const WorkoutHomePage({super.key, this.nutrients});

  @override
  State<WorkoutHomePage> createState() => _WorkoutHomePageState();
}

class _WorkoutHomePageState extends State<WorkoutHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Workout> recommendedWorkouts = [];
  List<Map<String, dynamic>> completedWorkouts = [];
  bool isLoading = true;
  Map<String, double> nutrients = {};
  String workoutType = 'Regular Fitness';
  String fitnessLevel = 'Beginner';
  double userWeight = 0.0;
  int? workoutDuration;
  int totalDailyWorkoutTime = 0;

  Map<String, double> get defaultNutrients => {
        'calories': 0.0,
        'protein': 0.0,
        'fat': 0.0,
        'carbs': 0.0,
      };

  final List<String> workoutTypes = [
    'Weight Gain',
    'Endurance',
    'Regular Fitness',
    'Weight Loss',
    'Strength Building',
  ];

  final List<String> fitnessLevels = [
    'Beginner',
    'Intermediate',
  ];

  List<int> get durationOptions => List.generate(25, (index) => index * 5);

  @override
  void initState() {
    super.initState();
    _loadGifData();
    _setupAuthListener();
    _fetchNutrientsAndWorkouts();
    _fetchCompletedWorkouts();
    _fetchDailyWorkoutTime();
  }

  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _fetchNutrientsAndWorkouts();
        _fetchDailyWorkoutTime();
      } else {
        setState(() {
          userWeight = 0.0;
          totalDailyWorkoutTime = 0;
          isLoading = false;
        });
      }
    });
  }

  Future<void> _fetchGifFromAPI(String exerciseName) async {
    if (exerciseGifs.containsKey(exerciseName.toLowerCase())) return;

    try {
      String normalizedName = Uri.encodeComponent(exerciseName.toLowerCase().trim());
      final client = http.Client();
      final response = await client.get(
        Uri.parse('https://exercisedb.p.rapidapi.com/exercises/name/$normalizedName'),
        headers: {
          'x-rapidapi-host': 'exercisedb.p.rapidapi.com',
          'x-rapidapi-key': 'c9f30f8f96msh4dc8875124dec05p136d97jsn00f4fddc5b15',
        },
      );

      if (response.statusCode == 200) {
        final exercises = jsonDecode(response.body);
        if (exercises is List && exercises.isNotEmpty && exercises[0]['gifUrl'] != null) {
          final gifUrl = exercises[0]['gifUrl'] as String;
          final urlCheck = await client.head(Uri.parse(gifUrl));
          if (urlCheck.statusCode == 200) {
            setState(() {
              exerciseGifs[exerciseName.toLowerCase()] = gifUrl;
              for (var workout in recommendedWorkouts) {
                if (workout.title.toLowerCase() == exerciseName.toLowerCase()) {
                  workout.gifUrl = gifUrl;
                }
              }
            });
          } else {
            setState(() {
              exerciseGifs[exerciseName.toLowerCase()] = '';
            });
          }
        } else {
          setState(() {
            exerciseGifs[exerciseName.toLowerCase()] = '';
          });
        }
      } else {
        setState(() {
          exerciseGifs[exerciseName.toLowerCase()] = '';
        });
      }
      client.close();
    } catch (e) {
      setState(() {
        exerciseGifs[exerciseName.toLowerCase()] = '';
      });
    }
  }

  Future<void> _loadGifData() async {
    try {
      final String csvString = await rootBundle.loadString('assets/gifs.csv');
      final List<String> lines = csvString.split('\n');
      exerciseGifs.clear();
      for (String line in lines.skip(1)) {
        if (line.trim().isEmpty) continue;
        final List<String> parts = line.split(',');
        if (parts.length >= 3) {
          final String exerciseName = parts[1].trim();
          final String gifUrl = parts[2].trim();
          exerciseGifs[exerciseName.toLowerCase()] = gifUrl;
        }
      }
    } catch (e) {
      print('Error loading GIF data: $e');
    }
  }

  String _suggestWorkoutType(Map<String, double> nutrients, double userWeight) {
    double calories = nutrients['calories'] ?? defaultNutrients['calories']!;
    double protein = nutrients['protein'] ?? defaultNutrients['protein']!;
    double carbs = nutrients['carbs'] ?? defaultNutrients['carbs']!;
    double fat = nutrients['fat'] ?? defaultNutrients['fat']!;

    if (userWeight == 0) return 'Regular Fitness';

    double proteinPerKg = protein / userWeight;
    double totalMacros = protein + carbs + fat;
    double proteinRatio = totalMacros > 0 ? protein / totalMacros : 0;
    double carbRatio = totalMacros > 0 ? carbs / totalMacros : 0;

    if (calories > 2500 && proteinPerKg > 1.6) {
      return 'Weight Gain';
    } else if (carbRatio >= 0.5 && calories > 2000) {
      return 'Endurance';
    } else if (proteinPerKg >= 1.8 && proteinRatio >= 0.3) {
      return 'Strength Building';
    } else if (calories < 1800) {
      return 'Weight Loss';
    }
    return 'Regular Fitness';
  }

  Future<void> _fetchNutrientsAndWorkouts() async {
    setState(() => isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      String currentDate = DateTime.now().toIso8601String().split('T')[0];
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      setState(() {
        userWeight = (userData?['weight'] as num?)?.toDouble() ?? 0.0;
      });

      final nutritionDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_nutrition_totals')
          .doc(currentDate)
          .get(GetOptions(source: Source.server));
      if (nutritionDoc.exists) {
        final data = nutritionDoc.data()!;
        nutrients = {
          'calories': (data['totalCalories'] as num?)?.toDouble() ?? defaultNutrients['calories']!,
          'protein': (data['totalProtein'] as num?)?.toDouble() ?? defaultNutrients['protein']!,
          'fat': (data['totalFat'] as num?)?.toDouble() ?? defaultNutrients['fat']!,
          'carbs': (data['totalCarbs'] as num?)?.toDouble() ?? defaultNutrients['carbs']!,
        };
        if (workoutType == 'Regular Fitness') {
          workoutType = _suggestWorkoutType(nutrients, userWeight);
        }
      } else {
        nutrients = defaultNutrients;
      }

      if (workoutDuration != null && workoutDuration! > 0) {
        QuerySnapshot snapshot = await _firestore
            .collection('workouts')
            .where('Level', isEqualTo: fitnessLevel)
            .where('Type', isEqualTo: workoutType)
            .get();
        if (snapshot.docs.isEmpty) {
          snapshot = await _firestore.collection('workouts').where('Level', isEqualTo: fitnessLevel).get();
        }

        List<Workout> allWorkouts = snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String title = data['Title'] ?? '';
          data['gifUrl'] = exerciseGifs[title.toLowerCase()] ?? '';
          data['duration'] = data['duration'] ?? 5;
          return Workout.fromJson(data);
        }).toList();

        await _fetchMissingGifs(allWorkouts);
        List<Workout> filteredWorkouts = [];
        int totalDuration = 0;
        for (var workout in allWorkouts..shuffle(Random())) {
          if (totalDuration + workout.duration <= workoutDuration!) {
            filteredWorkouts.add(workout);
            totalDuration += workout.duration;
          }
        }

        setState(() {
          recommendedWorkouts = filteredWorkouts;
        });
      } else {
        setState(() {
          recommendedWorkouts = [];
        });
      }

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  Future<void> _fetchCompletedWorkouts() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      String currentDate = DateTime.now().toIso8601String().split('T')[0];
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('completed_workouts')
          .doc(currentDate)
          .collection('workouts')
          .orderBy('completedAt', descending: true)
          .limit(10)
          .get();

      setState(() {
        completedWorkouts = snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading workout history: $e')),
      );
    }
  }

  Future<void> _fetchDailyWorkoutTime() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      String currentDate = DateTime.now().toIso8601String().split('T')[0];
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_workout_time')
          .doc(currentDate)
          .get();

      setState(() {
        totalDailyWorkoutTime = doc.exists ? (doc.data()!['totalDuration'] as int? ?? 0) : 0;
      });
    } catch (e) {
      print('Error fetching daily workout time: $e');
    }
  }

  Future<void> _saveDailyWorkoutTime(int additionalDuration) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      String currentDate = DateTime.now().toIso8601String().split('T')[0];
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_workout_time')
          .doc(currentDate);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        int currentTotal = doc.exists ? (doc.data()!['totalDuration'] as int? ?? 0) : 0;
        int newTotal = currentTotal + additionalDuration;

        transaction.set(docRef, {
          'date': currentDate,
          'totalDuration': newTotal,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      setState(() {
        totalDailyWorkoutTime += additionalDuration;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving workout time: $e')),
      );
    }
  }

  Future<void> _recordCompletedWorkout(Workout workout) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      String currentDate = DateTime.now().toIso8601String().split('T')[0];
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('completed_workouts')
          .doc(currentDate)
          .collection('workouts')
          .add({
        'title': workout.title,
        'bodyPart': workout.bodyPart,
        'level': workout.level,
        'type': workout.type,
        'duration': workout.duration,
        'completedAt': FieldValue.serverTimestamp(),
      });

      await _saveDailyWorkoutTime(workout.duration);
      await _fetchCompletedWorkouts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording workout: $e')),
      );
    }
  }

  Future<void> _fetchMissingGifs(List<Workout> workouts) async {
    final fetchOperations = workouts
        .where((workout) => workout.gifUrl.isEmpty)
        .map((workout) => _fetchGifFromAPI(workout.title))
        .toList();
    await Future.wait(fetchOperations);
  }

  bool _isWorkoutCompleted(Workout workout) {
    return completedWorkouts.any((completed) => completed['title'] == workout.title);
  }

  void _showHistoryDialog(double screenHeight, double screenWidth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout History (Today)'),
        content: SizedBox(
          width: min(screenWidth * 0.8, 600),
          height: min(screenHeight * 0.4, 400),
          child: completedWorkouts.isEmpty
              ? const Center(child: Text('No workout history yet today'))
              : ListView.builder(
                  itemCount: completedWorkouts.length,
                  itemBuilder: (context, index) {
                    final workout = completedWorkouts[index];
                    final timestamp = workout['completedAt'] as Timestamp?;
                    final date = timestamp?.toDate() ?? DateTime.now();

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                      child: ListTile(
                        title: Text(
                          workout['title'] ?? 'Unknown Workout',
                          style: TextStyle(fontSize: min(screenWidth * 0.04, 16)),
                        ),
                        subtitle: Text(
                          '${workout['bodyPart'] ?? 'Unknown'} • ${workout['level'] ?? 'Unknown'}\n'
                          'Completed at ${date.hour}:${date.minute.toString().padLeft(2, '0')} • ${workout['duration']} min',
                          style: TextStyle(fontSize: min(screenWidth * 0.035, 14)),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.fitness_center, color: Colors.blue),
                          radius: min(screenWidth * 0.05, 20),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildBottomNavigationBar(BuildContext context, double screenWidth, double screenHeight) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 5)],
      ),
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.015),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, Icons.home, "Home", false, '/home', screenWidth),
          _buildNavItem(context, Icons.bar_chart, "Finance", false, '/finance', screenWidth),
          _buildNavItem(context, Icons.restaurant, "Nutrition", false, '/nut', screenWidth),
          _buildNavItem(context, Icons.fitness_center, "Workout", true, '/workout', screenWidth),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isSelected, String route, double screenWidth) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF002386) : Colors.grey,
            size: min(screenWidth * 0.07, 30),
          ),
          SizedBox(height: screenWidth * 0.01),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF002386) : Colors.grey,
              fontSize: min(screenWidth * 0.03, 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final displayNutrients = widget.nutrients ?? (nutrients.isEmpty ? defaultNutrients : nutrients);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF002386),
        elevation: 0,
        toolbarHeight: min(screenHeight * 0.1, 80),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Center',
              style: TextStyle(
                fontSize: min(screenWidth * 0.06, 24),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Stronger every day',
              style: TextStyle(
                fontSize: min(screenWidth * 0.035, 16),
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.white, size: min(screenWidth * 0.07, 30)),
            onPressed: () => _showHistoryDialog(screenHeight, screenWidth),
            tooltip: 'View Workout History',
          ),
          IconButton(
            icon: Icon(Icons.fitness_center, color: Colors.white, size: min(screenWidth * 0.07, 30)),
            onPressed: () {
              Navigator.pushNamed(context, '/custom');
            },
            tooltip: 'Create Custom Workout',
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NutrientsSummaryCard(
                      nutrients: displayNutrients,
                      userWeight: userWeight,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Row(
                      children: [
                        Text(
                          'Workout Goal:',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: min(screenWidth * 0.045, 18)),
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        DropdownButton<String>(
                          value: workoutType,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                workoutType = newValue;
                                _fetchNutrientsAndWorkouts();
                              });
                            }
                          },
                          items: workoutTypes.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: TextStyle(fontSize: min(screenWidth * 0.04, 16)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Row(
                      children: [
                        Text(
                          'Fitness Level:',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: min(screenWidth * 0.045, 18)),
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        DropdownButton<String>(
                          value: fitnessLevel,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                fitnessLevel = newValue;
                                _fetchNutrientsAndWorkouts();
                              });
                            }
                          },
                          items: fitnessLevels.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: TextStyle(fontSize: min(screenWidth * 0.04, 16)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Row(
                      children: [
                        Text(
                          'Workout Duration:',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: min(screenWidth * 0.045, 18)),
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        DropdownButton<int>(
                          value: workoutDuration,
                          hint: Text(
                            'Select duration (min)',
                            style: TextStyle(fontSize: min(screenWidth * 0.04, 16)),
                          ),
                          onChanged: (int? newValue) {
                            setState(() {
                              workoutDuration = newValue;
                              _fetchNutrientsAndWorkouts();
                            });
                          },
                          items: durationOptions.map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                value == 0 ? 'No duration' : '$value min',
                                style: TextStyle(fontSize: min(screenWidth * 0.04, 16)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    if (workoutDuration == null || workoutDuration == 0)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                        child: Center(
                          child: Text(
                            'Please set a workout duration to see exercises',
                            style: TextStyle(fontSize: min(screenWidth * 0.045, 18)),
                          ),
                        ),
                      )
                    else if (recommendedWorkouts.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                        child: Center(
                          child: Text(
                            'No workouts found for your profile',
                            style: TextStyle(fontSize: min(screenWidth * 0.045, 18)),
                          ),
                        ),
                      )
                    else
                      ...recommendedWorkouts.map((workout) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                          child: WorkoutCard(
                            workout: workout,
                            onComplete: () => _recordCompletedWorkout(workout),
                            isCompleted: _isWorkoutCompleted(workout),
                            fetchGifFromAPI: _fetchGifFromAPI,
                            isActive: RecommendationsTabState._currentWorkoutIndex ==
                                recommendedWorkouts.indexOf(workout),
                            onStart: () {
                              RecommendationsTabState._currentWorkoutIndex =
                                  recommendedWorkouts.indexOf(workout);
                              setState(() {});
                            },
                            onNextWorkoutStart: () => RecommendationsTabState._startNextWorkout(
                                recommendedWorkouts.indexOf(workout), recommendedWorkouts, setState),
                            screenWidth: screenWidth,
                            screenHeight: screenHeight,
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _fetchNutrientsAndWorkouts();
          _fetchDailyWorkoutTime();
        },
        child: Icon(Icons.refresh, size: min(screenWidth * 0.07, 30)),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, screenWidth, screenHeight),
    );
  }
}

class RecommendationsTabState {
  static int _currentWorkoutIndex = -1;

  static void _startNextWorkout(int currentIndex, List<Workout> workouts, void Function(void Function()) setState) {
    if (workouts.isEmpty) return;
    setState(() {
      if (currentIndex + 1 < workouts.length) {
        _currentWorkoutIndex = currentIndex + 1;
      } else {
        _currentWorkoutIndex = -1;
      }
    });
  }
}

class NutrientsSummaryCard extends StatelessWidget {
  final Map<String, double> nutrients;
  final double userWeight;
  final double screenWidth;
  final double screenHeight;

  const NutrientsSummaryCard({
    super.key,
    required this.nutrients,
    required this.userWeight,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Nutrition Summary',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: min(screenWidth * 0.045, 18)),
            ),
            SizedBox(height: screenHeight * 0.01),
            Wrap(
              spacing: screenWidth * 0.02,
              runSpacing: screenHeight * 0.01,
              children: [
                _NutrientItem(
                  label: 'Calories',
                  value: '${nutrients['calories']!.toInt()} kcal',
                  icon: Icons.local_fire_department,
                  color: Colors.red,
                  screenWidth: screenWidth,
                ),
                _NutrientItem(
                  label: 'Protein',
                  value: '${nutrients['protein']!.toInt()}g',
                  icon: Icons.egg_alt,
                  color: Colors.purple,
                  screenWidth: screenWidth,
                ),
                _NutrientItem(
                  label: 'Carbs',
                  value: '${nutrients['carbs']!.toInt()}g',
                  icon: Icons.grain,
                  color: Colors.amber,
                  screenWidth: screenWidth,
                ),
                _NutrientItem(
                  label: 'Fat',
                  value: '${nutrients['fat']!.toInt()}g',
                  icon: Icons.opacity,
                  color: Colors.blue,
                  screenWidth: screenWidth,
                ),
                _NutrientItem(
                  label: 'Weight',
                  value: userWeight == 0.0 ? 'N/A' : '${userWeight.toInt()} kg',
                  icon: Icons.fitness_center,
                  color: Colors.teal,
                  screenWidth: screenWidth,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double screenWidth;

  const _NutrientItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: min(screenWidth * 0.06, 24),
        ),
        SizedBox(height: screenWidth * 0.01),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontSize: min(screenWidth * 0.04, 16)),
        ),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontSize: min(screenWidth * 0.03, 14)),
        ),
      ],
    );
  }
}

class Workout {
  final String bodyPart;
  final String desc;
  final String equipment;
  final String level;
  final int rating;
  final String ratingDesc;
  final String title;
  final String type;
  final int unnamed;
  String gifUrl;
  final int duration;

  Workout({
    required this.bodyPart,
    required this.desc,
    required this.equipment,
    required this.level,
    required this.rating,
    required this.ratingDesc,
    required this.title,
    required this.type,
    required this.unnamed,
    required this.gifUrl,
    required this.duration,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      bodyPart: json['BodyPart'] as String? ?? '',
      desc: json['Desc'] as String? ?? '',
      equipment: json['Equipment'] as String? ?? '',
      level: json['Level'] as String? ?? '',
      rating: (json['Rating'] is int)
          ? json['Rating'] as int
          : (json['Rating'] as double? ?? 0.0).toInt(),
      ratingDesc: json['RatingDesc'] as String? ?? '',
      title: json['Title'] as String? ?? '',
      type: json['Type'] as String? ?? '',
      unnamed: (json['Unnamed: 0'] is int)
          ? json['Unnamed: 0'] as int
          : (json['Unnamed: 0'] as double? ?? 0.0).toInt(),
      gifUrl: json['gifUrl'] as String? ?? '',
      duration: json['duration'] as int? ?? 5,
    );
  }
}

class WorkoutCard extends StatefulWidget {
  final Workout workout;
  final VoidCallback? onComplete;
  final bool isCompleted;
  final Future<void> Function(String) fetchGifFromAPI;
  final bool isActive;
  final VoidCallback onStart;
  final VoidCallback onNextWorkoutStart;
  final double screenWidth;
  final double screenHeight;

  const WorkoutCard({
    super.key,
    required this.workout,
    this.onComplete,
    required this.isCompleted,
    required this.fetchGifFromAPI,
    required this.isActive,
    required this.onStart,
    required this.onNextWorkoutStart,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<WorkoutCard> {
  bool _isExerciseActive = false;
  bool _isResting = false;
  int _restSeconds = 60;
  Timer? _timer;
  bool _hasStarted = false;

  @override
  void didUpdateWidget(WorkoutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive && !_isExerciseActive && !_isResting && !_hasStarted) {
      _startExercise();
      _hasStarted = true;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startExercise() {
    setState(() {
      _isExerciseActive = true;
      _isResting = false;
    });
  }

  void _completeExercise() {
    setState(() {
      _isExerciseActive = false;
      _isResting = true;
      _restSeconds = 60;
      _startRestTimer();
    });
    widget.onComplete?.call();
  }

  void _startRestTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_restSeconds > 0) {
          _restSeconds--;
        } else {
          _isResting = false;
          _hasStarted = false;
          timer.cancel();
          widget.onNextWorkoutStart();
        }
      });
    });
  }

  void _skipRest() {
    setState(() {
      _isResting = false;
      _hasStarted = false;
      _timer?.cancel();
    });
    widget.onNextWorkoutStart();
  }

  void _adjustRestTime(int seconds) {
    if (_isResting && _restSeconds + seconds > 0) {
      setState(() {
        _restSeconds += seconds;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: widget.screenHeight * 0.01),
      child: Padding(
        padding: EdgeInsets.all(widget.screenWidth * 0.03),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.workout.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: min(widget.screenWidth * 0.045, 18),
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isCompleted)
                        Padding(
                          padding: EdgeInsets.only(left: widget.screenWidth * 0.02),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: min(widget.screenWidth * 0.06, 24),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!widget.isCompleted && !_isExerciseActive && !_isResting)
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onStart();
                      _startExercise();
                      _hasStarted = true;
                    },
                    icon: Icon(Icons.play_arrow, size: min(widget.screenWidth * 0.05, 20)),
                    label: Text(
                      'Start',
                      style: TextStyle(fontSize: min(widget.screenWidth * 0.04, 16)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002386),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: widget.screenWidth * 0.03),
                    ),
                  ),
              ],
            ),
            SizedBox(height: widget.screenHeight * 0.005),
            Text(
              'Body Part: ${widget.workout.bodyPart}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: min(widget.screenWidth * 0.035, 14)),
            ),
            Text(
              'Level: ${widget.workout.level}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: min(widget.screenWidth * 0.035, 14)),
            ),
            Text(
              'Duration: ${widget.workout.duration} min',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: min(widget.screenWidth * 0.035, 14)),
            ),
            SizedBox(height: widget.screenHeight * 0.01),
            Text(
              widget.workout.desc,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: min(widget.screenWidth * 0.04, 16)),
            ),
            SizedBox(height: widget.screenHeight * 0.005),
            Text(
              'Equipment: ${widget.workout.equipment}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: min(widget.screenWidth * 0.035, 14)),
            ),
            if (_isExerciseActive)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: min(widget.screenHeight * 0.25, 200),
                  maxWidth: min(widget.screenWidth * 0.9, 400),
                ),
                child: Container(
                  margin: EdgeInsets.only(top: widget.screenHeight * 0.01),
                  padding: EdgeInsets.all(widget.screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Exercise in Progress',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: Colors.blue.shade800,
                              fontSize: min(widget.screenWidth * 0.045, 18),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: widget.screenHeight * 0.01),
                      Expanded(
                        child: widget.workout.gifUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.workout.gifUrl,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => Center(
                                  child: Text(
                                    'No GIF found',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: min(widget.screenWidth * 0.04, 16),
                                    ),
                                  ),
                                ),
                                fit: BoxFit.contain,
                              )
                            : Center(
                                child: Text(
                                  'No GIF found',
                                  style: TextStyle(fontSize: min(widget.screenWidth * 0.04, 16)),
                                ),
                              ),
                      ),
                      SizedBox(height: widget.screenHeight * 0.01),
                      ElevatedButton.icon(
                        onPressed: _completeExercise,
                        icon: Icon(Icons.check_circle, size: min(widget.screenWidth * 0.05, 20)),
                        label: Text(
                          'Complete',
                          style: TextStyle(fontSize: min(widget.screenWidth * 0.04, 16)),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, min(widget.screenHeight * 0.05, 40)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isResting)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: min(widget.screenHeight * 0.20, 160), // Reduced max height
                  maxWidth: min(widget.screenWidth * 0.9, 400),
                ),
                child: Container(
                  margin: EdgeInsets.only(top: widget.screenHeight * 0.01),
                  padding: EdgeInsets.all(widget.screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Rest Time',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: Colors.orange.shade800,
                                fontSize: min(widget.screenWidth * 0.04, 16), // Reduced font size
                              ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: widget.screenHeight * 0.005), // Reduced spacing
                        Text(
                          '${_restSeconds ~/ 60}:${(_restSeconds % 60).toString().padLeft(2, '0')}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                                fontSize: min(widget.screenWidth * 0.07, 28), // Reduced font size
                              ),
                        ),
                        SizedBox(height: widget.screenHeight * 0.005), // Reduced spacing
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _adjustRestTime(-10),
                              icon: Icon(
                                Icons.remove_circle,
                                size: min(widget.screenWidth * 0.05, 20), // Reduced icon size
                              ),
                              padding: EdgeInsets.zero, // Tightened padding
                              color: Colors.orange,
                            ),
                            IconButton(
                              onPressed: () => _adjustRestTime(10),
                              icon: Icon(
                                Icons.add_circle,
                                size: min(widget.screenWidth * 0.05, 20), // Reduced icon size
                              ),
                              padding: EdgeInsets.zero, // Tightened padding
                              color: Colors.orange,
                            ),
                          ],
                        ),
                        SizedBox(height: widget.screenHeight * 0.005), // Reduced spacing
                        ElevatedButton(
                          onPressed: _skipRest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, min(widget.screenHeight * 0.04, 36)), // Reduced button size
                            padding: EdgeInsets.symmetric(vertical: widget.screenHeight * 0.005), // Reduced padding
                          ),
                          child: Text(
                            'Skip Rest',
                            style: TextStyle(fontSize: min(widget.screenWidth * 0.035, 14)), // Reduced font size
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}