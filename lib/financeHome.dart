import 'package:flutter/material.dart';// Ensure the correct filename

class FinanceHomeScreen extends StatelessWidget {
  final Color primaryColor = Color(0xFF002386);

  FinanceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF002386),
        elevation: 0,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finance Hub',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            Text(
              'Manage finance with ease',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 0.9,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _buildFeatureCard(
                      context,
                      'Expense\nTracker',
                      'Track daily spending habits',
                      Icons.account_balance_wallet,
                      Colors.orange[400]!,
                      '/expense'),
                  _buildFeatureCard(
                      context,
                      'Income\nTracker',
                      'Record and categorize income',
                      Icons.attach_money,
                      Colors.green[400]!,
                      '/income'),
                  _buildFeatureCard(
                      context,
                      'Finance\nAnalysis',
                      'Get insights on your finances',
                      Icons.analytics,
                      Colors.purple[400]!,
                      '/analysis'),
                  _buildFeatureCard(
                      context,
                      'Bill\nReminders',
                      'Never miss a payment',
                      Icons.notifications_active,
                      Colors.red[400]!,
                      '/bill'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title,
      String description, IconData icon, Color iconColor, String route) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 5)],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, Icons.home, "Home", false, '/home'),
          _buildNavItem(context, Icons.bar_chart, "Finance", true, '/finance'),
          _buildNavItem(context, Icons.restaurant, "Nutrition", false, '/nut'),
          _buildNavItem(
              context, Icons.fitness_center, "Workout", false, '/workout'),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label,
      bool isSelected, String route) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isSelected ? Color(0xFF002386) : Colors.grey, size: 24),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                color: isSelected ? Color(0xFF002386) : Colors.grey,
                fontSize: 11),
          ),
        ],
      ),
    );
  }
}
