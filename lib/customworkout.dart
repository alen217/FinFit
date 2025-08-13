import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Ensure you configure firebase_options.dart in a real app
  runApp(const MaterialApp(home: CustomWorkout()));
}

class CustomWorkout extends StatefulWidget {
  const CustomWorkout({super.key});

  @override
  State<CustomWorkout> createState() => _CustomWorkoutState();
}

class _CustomWorkoutState extends State<CustomWorkout> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  Map<String, List<CustomExercise>> weeklyWorkouts = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Primary app color
  final Color primaryColor = Color(0xFF002386);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _initializeWeeklyWorkouts();
    _fetchWeeklyWorkouts();
  }

  void _initializeWeeklyWorkouts() {
    for (var day in daysOfWeek) {
      weeklyWorkouts[day] = [];
    }
  }

  Future<void> _fetchWeeklyWorkouts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to access workouts')),
      );
      return;
    }

    setState(() => weeklyWorkouts = {for (var day in daysOfWeek) day: []});

    for (var day in daysOfWeek) {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('weekly_workouts')
          .doc(day.toLowerCase())
          .collection('exercises')
          .get();

      setState(() {
        weeklyWorkouts[day] = snapshot.docs.map((doc) {
          final data = doc.data();
          return CustomExercise(
            id: doc.id,
            name: data['name'] ?? '',
            duration: data['duration'] ?? 30,
            category: data['category'] ?? 'Strength',
            notes: data['notes'] ?? '',
            isCompleted: data['isCompleted'] ?? false,
          );
        }).toList();
      });
    }
  }

  void _showAddExerciseDialog(String day) {
    showDialog(
      context: context,
      builder: (context) => AddExerciseDialog(
        day: day,
        onExerciseAdded: () => _fetchWeeklyWorkouts(),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Custom Workouts'),
        backgroundColor: Color(0xFF002386),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: daysOfWeek.map((day) => Tab(text: day)).toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Color(0xFFB3C1E8), // Light shade of the primary color
          indicatorColor: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center),
            onPressed: _showWeeklySummary,
            tooltip: 'Weekly Summary',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: daysOfWeek.map((day) {
          return DayWorkoutView(
            day: day,
            exercises: weeklyWorkouts[day] ?? [],
            onAddExercise: () => _showAddExerciseDialog(day),
            onStartExercise: (exercise) => _startWorkout(exercise, day),
            onDeleteExercise: (exercise) => _deleteExercise(exercise, day),
            primaryColor: primaryColor,
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExerciseDialog(daysOfWeek[_tabController.index]),
        backgroundColor: Color(0xFF002386),
        child: const Icon(Icons.add),
        tooltip: 'Add Exercise to Current Day',
      ),
    );
  }

  void _startWorkout(CustomExercise exercise, String day) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseTimer(
          exercise: exercise,
          primaryColor: primaryColor,
          onComplete: () async {
            await _updateExerciseCompletion(exercise, day, true);
            _fetchWeeklyWorkouts();
          },
        ),
      ),
    );
  }

  Future<void> _deleteExercise(CustomExercise exercise, String day) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('weekly_workouts')
        .doc(day.toLowerCase())
        .collection('exercises')
        .doc(exercise.id)
        .delete();

    _fetchWeeklyWorkouts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${exercise.name} deleted from $day')),
    );
  }

  Future<void> _updateExerciseCompletion(CustomExercise exercise, String day, bool isCompleted) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('weekly_workouts')
        .doc(day.toLowerCase())
        .collection('exercises')
        .doc(exercise.id)
        .update({'isCompleted': isCompleted});
  }

  void _showWeeklySummary() {
    int totalExercises = weeklyWorkouts.values.fold(0, (sum, exercises) => sum + exercises.length);
    int completedExercises = weeklyWorkouts.values.fold(
        0, (sum, exercises) => sum + exercises.where((e) => e.isCompleted).length);
    int totalDuration = weeklyWorkouts.values.fold(
        0, (sum, exercises) => sum + exercises.fold(0, (s, e) => s + e.duration));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weekly Workout Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Exercises: $totalExercises'),
            Text('Completed: $completedExercises'),
            Text('Total Duration: ${totalDuration ~/ 60} min ${totalDuration % 60} sec'),
            const SizedBox(height: 8),
            Text(
              'Weekly Progress: ${(totalExercises > 0 ? completedExercises / totalExercises * 100 : 0).toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Color(0xFF002386))),
          ),
        ],
      ),
    );
  }
}

class AddExerciseDialog extends StatefulWidget {
  final String day;
  final VoidCallback onExerciseAdded;

  const AddExerciseDialog({super.key, required this.day, required this.onExerciseAdded});

  @override
  _AddExerciseDialogState createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<AddExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();
  String _category = 'Strength';

  final List<String> categories = ['Strength', 'Cardio', 'Flexibility', 'Core', 'Other'];

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveExercise() async {
    if (_formKey.currentState!.validate()) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save exercises')),
        );
        return;
      }

      final exerciseData = {
        'name': _titleController.text,
        'duration': int.parse(_durationController.text),
        'category': _category,
        'notes': _notesController.text,
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('weekly_workouts')
          .doc(widget.day.toLowerCase())
          .collection('exercises')
          .add(exerciseData);

      Navigator.pop(context);
      widget.onExerciseAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exercise added to ${widget.day}!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Exercise for ${widget.day}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Exercise Name'),
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              ),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(labelText: 'Duration (seconds)'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty || int.tryParse(value) == null || int.parse(value) <= 0
                    ? 'Please enter a valid duration'
                    : null,
              ),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                    .toList(),
                onChanged: (value) => setState(() => _category = value!),
              ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: Text('Cancel', style: TextStyle(color: Colors.grey[700]))
        ),
        TextButton(
          onPressed: _saveExercise, 
          child: Text('Add', style: TextStyle(color: Color(0xFF002386)))
        ),
      ],
    );
  }
}

class DayWorkoutView extends StatelessWidget {
  final String day;
  final List<CustomExercise> exercises;
  final VoidCallback onAddExercise;
  final Function(CustomExercise) onStartExercise;
  final Function(CustomExercise) onDeleteExercise;
  final Color primaryColor;

  const DayWorkoutView({
    super.key,
    required this.day,
    required this.exercises,
    required this.onAddExercise,
    required this.onStartExercise,
    required this.onDeleteExercise,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$day Workouts',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: primaryColor),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: exercises.isEmpty
                ? Center(child: Text('No exercises for $day yet. Add one!'))
                : ListView.builder(
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      return CustomExerciseCard(
                        exercise: exercise,
                        onStart: () => onStartExercise(exercise),
                        onDelete: () => onDeleteExercise(exercise),
                        primaryColor: primaryColor,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CustomExercise {
  final String? id; // Firestore document ID
  final String name;
  final int duration;
  final String category;
  final String notes;
  bool isCompleted;

  CustomExercise({
    this.id,
    required this.name,
    required this.duration,
    required this.category,
    this.notes = '',
    this.isCompleted = false,
  });
}

class CustomExerciseCard extends StatelessWidget {
  final CustomExercise exercise;
  final VoidCallback onStart;
  final VoidCallback onDelete;
  final Color primaryColor;

  const CustomExerciseCard({
    super.key,
    required this.exercise,
    required this.onStart,
    required this.onDelete,
    required this.primaryColor,
  });

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Strength': return Color(0xFFCCD4F0); // Light blue shade
      case 'Cardio': return Color(0xFFFFD4D4); // Light red shade
      case 'Flexibility': return Color(0xFFD4FFD4); // Light green shade
      case 'Core': return Color(0xFFFFE8CC); // Light orange shade
      case 'Other': return Color(0xFFE8D4FF); // Light purple shade
      default: return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        exercise.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (exercise.isCompleted)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.check_circle, color: Colors.green),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Chip(label: Text(exercise.category), backgroundColor: _getCategoryColor(exercise.category)),
                  const SizedBox(height: 4),
                  Text('Duration: ${exercise.duration ~/ 60} min ${exercise.duration % 60} sec'),
                  if (exercise.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Notes: ${exercise.notes}', style: TextStyle(color: Colors.grey[600])),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: exercise.isCompleted ? null : onStart,
                  icon: const Icon(Icons.play_arrow),
                  color: exercise.isCompleted ? Colors.grey : primaryColor,
                  tooltip: 'Start Exercise',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  tooltip: 'Delete Exercise',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseTimer extends StatefulWidget {
  final CustomExercise exercise;
  final VoidCallback onComplete;
  final Color primaryColor;

  const ExerciseTimer({
    super.key, 
    required this.exercise, 
    required this.onComplete, 
    required this.primaryColor
  });

  @override
  State<ExerciseTimer> createState() => _ExerciseTimerState();
}

class _ExerciseTimerState extends State<ExerciseTimer> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.exercise.duration;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _timer?.cancel();
            widget.onComplete();
            Navigator.pop(context);
          }
        });
      }
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name), backgroundColor: widget.primaryColor),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Time Remaining', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(
              _formatTime(_remainingSeconds),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: widget.primaryColor, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _togglePause,
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(_isPaused ? 'Resume' : 'Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor, 
                    foregroundColor: Colors.white
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _timer?.cancel();
                    widget.onComplete();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}