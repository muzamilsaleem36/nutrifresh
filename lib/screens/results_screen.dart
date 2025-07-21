import 'package:flutter/material.dart';
import 'package:nutrifresh/models/food_info.dart';
import 'package:nutrifresh/utils/app_theme.dart';

class Developer {
  final String name;
  final String role;
  final String rollNo;
  final String imagePath;
  final String detailedInfo; // More detailed info for the popup

  const Developer({
    required this.name,
    required this.role,
    required this.rollNo,
    required this.imagePath,
    required this.detailedInfo,
  });
}

class ResultsScreen extends StatefulWidget {
  final FoodInfo foodInfo;

  const ResultsScreen({
    Key? key,
    required this.foodInfo,
  }) : super(key: key);

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header with food information
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),
            
            // Nutrition Section
            SliverToBoxAdapter(
              child: _buildSectionTitle('Nutrition Values'),
            ),
            SliverToBoxAdapter(
              child: _buildNutritionSections(),
            ),
            
            // Divider
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Divider(color: Colors.grey[300], height: 1),
              ),
            ),
            
            // Storage Recommendations
            SliverToBoxAdapter(
              child: _buildSectionTitle('Storage Recommendations'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildStorageCard(widget.foodInfo.storageRecommendations[index]),
                childCount: widget.foodInfo.storageRecommendations.length,
              ),
            ),
            
            // Divider
            SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Divider(color: Colors.grey[300], height: 1),
              ),
            ),
            
            // Health Risk Indicators
            SliverToBoxAdapter(
              child: _buildSectionTitle('Health Risk Indicators'),
            ),
            SliverToBoxAdapter(
              child: _buildHealthRiskCarousel(),
            ),
            
            // Bottom Padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Determine freshness color
    Color freshnessColor;
    String freshnessLabel;
    
    if (widget.foodInfo.freshness.percentage >= 70) {
      freshnessColor = AppTheme.freshColor;
      freshnessLabel = 'Fresh';
    } else if (widget.foodInfo.freshness.percentage >= 40) {
      freshnessColor = AppTheme.midSpoiledColor;
      freshnessLabel = 'Mid-Fresh';
    } else {
      freshnessColor = AppTheme.rottenColor;
      freshnessLabel = 'Spoiled';
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 3),
            blurRadius: 8,
          )
        ],
      ),
        child: Column(
          children: [
          // Food Name and Category Row
            Row(
              children: [
              // Food icon or emoji
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: widget.foodInfo.iconPath != null
                      ? Image.asset(
                          widget.foodInfo.iconPath!,
                          width: 40,
                          height: 40,
                      errorBuilder: (context, error, stackTrace) {
                            return Text(
                              '🥑',
                              style: TextStyle(fontSize: 32),
                            );
                          },
                        )
                      : Text(
                          '🥑',
                          style: TextStyle(fontSize: 32),
                        ),
                ),
              ),
              
                const SizedBox(width: 16),
                
                // Food name and category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                      widget.foodInfo.foodName,
                        style: const TextStyle(
                        fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                        Text(
                      widget.foodInfo.category,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              
              // Close button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                color: Colors.grey[700],
                ),
              ],
            ),
            
          const SizedBox(height: 24),
            
            // Freshness indicator
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row with Freshness label and value
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Freshness Level',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: freshnessColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      freshnessLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: freshnessColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Progress indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: widget.foodInfo.freshness.percentage / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(freshnessColor),
                    minHeight: 10,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Percentage text
              Text(
                '${widget.foodInfo.freshness.percentage}% Fresh',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                  ),
                ],
              ),
          ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
  
  Widget _buildNutritionSections() {
    // Group nutrients by category
    final macronutrients = <NutritionItem>[];
    final vitamins = <NutritionItem>[];
    final minerals = <NutritionItem>[];
    
    for (final nutrient in widget.foodInfo.nutrition) {
      final name = nutrient.name.toLowerCase();
      if (_isMacronutrient(name)) {
        macronutrients.add(nutrient);
      } else if (_isVitamin(name)) {
        vitamins.add(nutrient);
      } else if (_isMineral(name)) {
        minerals.add(nutrient);
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Macronutrients section
          if (macronutrients.isNotEmpty) ...[
            _buildNutritionSubheading('Macronutrients'),
            const SizedBox(height: 12),
            _buildNutritionGrid(macronutrients),
            const SizedBox(height: 24),
          ],
          
          // Vitamins section
          if (vitamins.isNotEmpty) ...[
            _buildNutritionSubheading('Vitamins'),
            const SizedBox(height: 12),
            _buildNutritionGrid(vitamins),
            const SizedBox(height: 24),
          ],
          
          // Minerals section
          if (minerals.isNotEmpty) ...[
            _buildNutritionSubheading('Minerals'),
            const SizedBox(height: 12),
            _buildNutritionGrid(minerals),
          ],
        ],
      ),
    );
  }
  
  Widget _buildNutritionSubheading(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }
  
  Widget _buildNutritionGrid(List<NutritionItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75, // Adjusted for better text display
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildNutritionCard(item);
      },
    );
  }
  
  bool _isMacronutrient(String name) {
    return name.contains('energy') ||
           name.contains('calorie') ||
           name.contains('carbohydrate') ||
           name.contains('sugar') ||
           name.contains('fiber') ||
           name.contains('protein') ||
           name.contains('fat');
  }
  
  bool _isVitamin(String name) {
    return name.contains('vitamin') ||
           name.contains('folate') ||
           name.contains('niacin') ||
           name.contains('riboflavin') ||
           name.contains('thiamin');
  }
  
  bool _isMineral(String name) {
    return name.contains('potassium') ||
           name.contains('calcium') ||
           name.contains('magnesium') ||
           name.contains('phosphorus') ||
           name.contains('iron') ||
           name.contains('zinc') ||
           name.contains('sodium') ||
           name.contains('copper') ||
           name.contains('manganese') ||
           name.contains('selenium');
  }

  Widget _buildNutritionCard(NutritionItem item) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                item.icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 6),
            // Name
            Expanded(
              flex: 2,
              child: Text(
                item.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            // Value and units
            Expanded(
              flex: 1,
              child: Text(
                item.value,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageCard(StorageMethod item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
          padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Storage method icon
            Container(
                width: 56,
                height: 56,
              decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
                child: Center(
                  child: Text(
                    item.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              
            const SizedBox(width: 16),
            
            // Storage method details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Method name
                    Text(
                      _formatStorageMethod(item.method),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Extension time
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+${item.estimatedExtensionDays} days',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Message
                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  String _formatStorageMethod(String method) {
    final words = method.split('_');
    final capitalized = words.map((word) => 
      word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}'
    ).join(' ');
    
    return capitalized;
  }
  
  Widget _buildHealthRiskCarousel() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: widget.foodInfo.healthRiskFactors.length,
        itemBuilder: (context, index) {
          final item = widget.foodInfo.healthRiskFactors[index];
          return _buildHealthRiskCard(item);
        },
      ),
    );
  }

  Widget _buildHealthRiskCard(HealthRiskFactor factor) {
    // Determine color based on risk score
    Color riskColor;
    if (factor.score <= 33) {
      riskColor = Colors.green;
    } else if (factor.score <= 66) {
      riskColor = Colors.orange;
    } else {
      riskColor = Colors.red;
    }
    
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          // Risk title
          Text(
            factor.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 12),
          
          // Risk circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: riskColor,
                width: 8,
              ),
              boxShadow: [
                BoxShadow(
                  color: riskColor.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  factor.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                Text(
                  '${factor.score}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Risk level text
          Text(
            _getRiskLevelText(factor.score),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: riskColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getRiskLevelText(int score) {
    if (score <= 33) {
      return 'Low Risk';
    } else if (score <= 66) {
      return 'Medium Risk';
    } else {
      return 'High Risk';
    }
  }
} 