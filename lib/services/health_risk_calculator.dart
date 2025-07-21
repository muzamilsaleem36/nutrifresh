import 'package:flutter/foundation.dart';
import 'package:nutrifresh/models/food_info.dart';

/// Service for calculating health risk factors based on nutrition values
class HealthRiskCalculator {
  // Singleton instance
  static final HealthRiskCalculator _instance = HealthRiskCalculator._internal();
  
  // Factory constructor
  factory HealthRiskCalculator() {
    return _instance;
  }
  
  // Private constructor
  HealthRiskCalculator._internal();
  
  /// Calculate health risk factors from nutrition values
  List<HealthRiskFactor> calculateHealthRisks(List<NutritionItem> nutrition) {
    try {
      // Extract numeric values from nutrition items
      final Map<String, double> values = _extractNutritionValues(nutrition);
      
      // Calculate risk factors
      final List<HealthRiskFactor> risks = [];
      
      // 1. Diabetes Risk
      risks.add(_calculateDiabetesRisk(values));
      
      // 2. Cholesterol Risk
      risks.add(_calculateCholesterolRisk(values));
      
      // 3. High Blood Pressure Risk
      risks.add(_calculateBloodPressureRisk(values));
      
      // 4. Obesity Risk
      risks.add(_calculateObesityRisk(values));
      
      // 5. Heart Disease Risk
      risks.add(_calculateHeartDiseaseRisk(values));
      
      // 6. Iron Deficiency Risk
      risks.add(_calculateIronDeficiencyRisk(values));
      
      // 7. Vitamin Deficiency Risk
      risks.add(_calculateVitaminDeficiencyRisk(values));
      
      // 8. Digestive Health Risk
      risks.add(_calculateDigestiveHealthRisk(values));
      
      // 9. Bone Health Risk
      risks.add(_calculateBoneHealthRisk(values));
      
      // 10. Muscle Loss Risk
      risks.add(_calculateMuscleLossRisk(values));
      
      return risks;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating health risks: $e');
      }
      return _createDefaultRisks();
    }
  }
  
  /// Extract numeric values from nutrition items
  Map<String, double> _extractNutritionValues(List<NutritionItem> nutrition) {
    final Map<String, double> values = {};
    
    for (final item in nutrition) {
      // Extract numeric value from string (e.g., "52 kcal" -> 52.0)
      final String valueStr = item.value.replaceAll(RegExp(r'[^\d.]'), '');
      
      try {
        final double value = double.parse(valueStr);
        
        // Normalize the name to lowercase and remove spaces
        final String normalizedName = item.name
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '_')
            .replaceAll(RegExp(r'[^\w_]'), '');
        
        values[normalizedName] = value;
      } catch (e) {
        // Skip if value can't be parsed
        if (kDebugMode) {
          print('Could not parse value "${item.value}" for ${item.name}');
        }
      }
    }
    
    return values;
  }
  
  /// 1. Calculate Diabetes Risk based on sugars and carbohydrates
  HealthRiskFactor _calculateDiabetesRisk(Map<String, double> values) {
    // Get values (defaulting to 0 if not found)
    final double sugars = values['sugars'] ?? 0.0;
    final double carbs = values['carbohydrates'] ?? 0.0;
    
    // Formula: risk_score = (sugars/20)*0.6 + (carbohydrates/50)*0.4
    double riskScore = (sugars / 20) * 0.6 + (carbs / 50) * 0.4;
    
    // Clamp between 0 and 1
    riskScore = riskScore.clamp(0.0, 1.0);
    
    // Calculate score on 0-100 scale
    int score = (riskScore * 100).round();
    
    // Determine risk level message
    String message;
    if (riskScore <= 0.3) {
      message = "Normal risk for diabetes. Balanced sugar and carbohydrate content.";
    } else if (riskScore <= 0.6) {
      message = "Moderate diabetes risk. Consider portion control for this food.";
    } else {
      message = "High diabetes risk due to elevated sugar/carbohydrate content. Consume in moderation.";
    }
    
    return HealthRiskFactor(
      name: "Diabetes Risk",
      score: score,
      icon: "🩸",
      message: message,
    );
  }
  
  /// 2. Calculate Cholesterol Risk based on total fat and saturated fat
  HealthRiskFactor _calculateCholesterolRisk(Map<String, double> values) {
    // Get values (defaulting to 0 if not found)
    final double totalFat = values['total_fat'] ?? 0.0;
    final double saturatedFat = values['saturated_fat'] ?? 0.0;
    
    // Formula: risk_score = (total_fat/20)*0.5 + (saturated_fat/6)*0.5
    // If saturated fat not available, use total_fat only
    double riskScore;
    if (values.containsKey('saturated_fat')) {
      riskScore = (totalFat / 20) * 0.5 + (saturatedFat / 6) * 0.5;
    } else {
      riskScore = totalFat / 20;
    }
    
    // Clamp between 0 and 1
    riskScore = riskScore.clamp(0.0, 1.0);
    
    // Calculate score on 0-100 scale
    int score = (riskScore * 100).round();
    
    // Determine risk level message
    String message;
    if (riskScore <= 0.3) {
      message = "Low cholesterol risk due to balanced fat profile.";
    } else if (riskScore <= 0.6) {
      message = "Moderate cholesterol impact. Balance with other low-fat foods.";
    } else {
      message = "High cholesterol risk. May increase cholesterol levels. Consume in limited quantities.";
    }
    
    return HealthRiskFactor(
      name: "Cholesterol Risk",
      score: score,
      icon: "🫀",
      message: message,
    );
  }
  
  /// 3. Calculate High Blood Pressure (BP) Risk based on sodium and potassium
  HealthRiskFactor _calculateBloodPressureRisk(Map<String, double> values) {
    // Get values (defaulting to 0 if not found)
    final double sodium = values['sodium'] ?? 0.0;
    final double potassium = values['potassium'] ?? 0.0;
    final double totalFat = values['total_fat'] ?? 0.0;
    
    // Formula: risk_score = (sodium / 300) * 0.7 + ((300 - potassium) / 300) * 0.3
    // If sodium unavailable, use total_fat/20 instead
    double riskScore;
    if (values.containsKey('sodium')) {
      // Potassium is beneficial, so invert its effect (higher potassium = lower risk)
      double potassiumScore = (300 - potassium) / 300;
      potassiumScore = potassiumScore.clamp(0.0, 1.0); // Ensure between 0-1
      
      riskScore = (sodium / 300) * 0.7 + potassiumScore * 0.3;
    } else {
      riskScore = totalFat / 20;
    }
    
    // Clamp between 0 and 1
    riskScore = riskScore.clamp(0.0, 1.0);
    
    // Calculate score on 0-100 scale
    int score = (riskScore * 100).round();
    
    // Determine risk level message
    String message;
    if (riskScore <= 0.3) {
      message = "Low blood pressure risk. Good sodium-potassium balance.";
    } else if (riskScore <= 0.6) {
      message = "Moderate blood pressure impact. Consider overall daily sodium intake.";
    } else {
      message = "High blood pressure risk. High sodium relative to potassium. Limit consumption if you have BP concerns.";
    }
    
    return HealthRiskFactor(
      name: "BP Risk",
      score: score,
      icon: "🩺",
      message: message,
    );
  }
  
  /// 4. Calculate Obesity Risk based on calories and sugars
  HealthRiskFactor _calculateObesityRisk(Map<String, double> values) {
    // Get values (defaulting to 0 if not found)
    final double calories = values['calories'] ?? values['energy'] ?? 0.0;
    final double sugars = values['sugars'] ?? 0.0;
    
    // Formula: risk_score = (calories / 200) * 0.6 + (sugars / 20) * 0.4
    double riskScore = (calories / 200) * 0.6 + (sugars / 20) * 0.4;
    
    // Clamp between 0 and 1
    riskScore = riskScore.clamp(0.0, 1.0);
    
    // Calculate score on 0-100 scale
    int score = (riskScore * 100).round();
    
    // Determine risk level message
    String message;
    if (riskScore <= 0.3) {
      message = "Low obesity risk. Good calorie and sugar balance.";
    } else if (riskScore <= 0.6) {
      message = "Moderate obesity risk. Watch portion sizes for this food.";
    } else {
      message = "High obesity risk due to high calories and sugar content. Consume in moderation.";
    }
    
    return HealthRiskFactor(
      name: "Obesity Risk",
      score: score,
      icon: "⚖️",
      message: message,
    );
  }
  
  /// 5. Calculate Heart Disease Risk based on total fat, fiber, and sugars
  HealthRiskFactor _calculateHeartDiseaseRisk(Map<String, double> values) {
    // Get values (defaulting to 0 if not found)
    final double totalFat = values['total_fat'] ?? 0.0;
    final double fiber = values['fiber'] ?? 0.0;
    final double sugars = values['sugars'] ?? 0.0;
    
    // Formula: risk_score = (total_fat / 20) * 0.4 + ((3 - fiber) / 3) * 0.3 + (sugars / 20) * 0.3
    // For fiber, higher values are better, so we invert the calculation
    double fiberScore = (3 - fiber) / 3;
    fiberScore = fiberScore.clamp(0.0, 1.0); // Ensure between 0-1
    
    double riskScore = (totalFat / 20) * 0.4 + fiberScore * 0.3 + (sugars / 20) * 0.3;
    
    // Clamp between 0 and 1
    riskScore = riskScore.clamp(0.0, 1.0);
    
    // Calculate score on 0-100 scale
    int score = (riskScore * 100).round();
    
    // Determine risk level message
    String message;
    if (riskScore <= 0.3) {
      message = "Low heart disease risk with a good balance of fat, fiber, and sugars.";
    } else if (riskScore <= 0.6) {
      message = "Moderate heart disease risk. Consider your overall diet pattern.";
    } else {
      message = "High heart disease risk due to fat and sugar content. Consume in moderation.";
    }
    
    return HealthRiskFactor(
      name: "Heart Disease Risk",
      score: score,
      icon: "💓",
      message: message,
    );
  }
  
  /// 6. Calculate Iron Deficiency Risk based on iron content
  HealthRiskFactor _calculateIronDeficiencyRisk(Map<String, double> values) {
    // Get values (defaulting to 0 if not found)
    final double iron = values['iron'] ?? 0.0;
    
    // Formula: risk_score = (2.5 - iron) / 2.5
    double riskScore = (2.5 - iron) / 2.5;
    
    // Clamp between 0 and 1
    riskScore = riskScore.clamp(0.0, 1.0);
    
    // Calculate score on 0-100 scale
    int score = (riskScore * 100).round();
    
    // Determine risk level message
    String message;
    if (iron >= 2.5) {
      message = "Excellent source of iron. Helps prevent iron deficiency.";
    } else if (iron >= 1.2) {
      message = "Moderate iron content. Include other iron-rich foods in your diet.";
    } else {
      message = "Low in iron. Consider complementary foods rich in iron if concerned about deficiency.";
    }
    
    return HealthRiskFactor(
      name: "Iron Deficiency Risk",
      score: score,
      icon: "🩸",
      message: message,
    );
  }
  
  /// 7. Calculate Vitamin Deficiency Risk based on vitamins A, C, and K
  HealthRiskFactor _calculateVitaminDeficiencyRisk(Map<String, double> values) {
    // Get values (defaulting to 0 if not found)
    final double vitaminA = values['vitamin_a'] ?? 0.0;
    final double vitaminC = values['vitamin_c'] ?? 0.0;
    final double vitaminK = values['vitamin_k'] ?? 0.0;
    final double vitaminE = values['vitamin_e'] ?? 0.0;
    final double vitaminB6 = values['vitamin_b6'] ?? 0.0;
    final double folate = values['folate'] ?? 0.0;
    final double niacin = values['niacin'] ?? 0.0;
    final double riboflavin = values['riboflavin'] ?? 0.0;
    final double thiamin = values['thiamin'] ?? 0.0;
    
    // Formula for individual vitamins (higher vitamin = lower risk)
    double vitAScore = (250 - vitaminA) / 250;
    double vitCScore = (30 - vitaminC) / 30;
    double vitKScore = (40 - vitaminK) / 40;
    double vitEScore = (5 - vitaminE) / 5;
    double vitB6Score = (0.5 - vitaminB6) / 0.5;
    double folateScore = (100 - folate) / 100;
    double niacinScore = (5 - niacin) / 5;
    double riboflavinScore = (0.5 - riboflavin) / 0.5;
    double thiaminScore = (0.5 - thiamin) / 0.5;
    
    // Clamp each between 0 and 1
    vitAScore = vitAScore.clamp(0.0, 1.0);
    vitCScore = vitCScore.clamp(0.0, 1.0);
    vitKScore = vitKScore.clamp(0.0, 1.0);
    vitEScore = vitEScore.clamp(0.0, 1.0);
    vitB6Score = vitB6Score.clamp(0.0, 1.0);
    folateScore = folateScore.clamp(0.0, 1.0);
    niacinScore = niacinScore.clamp(0.0, 1.0);
    riboflavinScore = riboflavinScore.clamp(0.0, 1.0);
    thiaminScore = thiaminScore.clamp(0.0, 1.0);
    
    // Calculate average risk
    double riskScore = (vitAScore + vitCScore + vitKScore + vitEScore + vitB6Score + 
                       folateScore + niacinScore + riboflavinScore + thiaminScore) / 9;
    
    // Calculate score on 0-100 scale
    int score = (riskScore * 100).round();
    
    // Determine risk level message
    String message;
    if (riskScore <= 0.3) {
      message = "Good vitamin content. Supports overall health and immunity.";
    } else if (riskScore <= 0.6) {
      message = "Moderate vitamin content. Consider a varied diet for complete nutrition.";
    } else {
      message = "Limited vitamin content. Include other vitamin-rich foods in your diet.";
    }
    
    return HealthRiskFactor(
      name: "Vitamin Deficiency Risk",
      score: score,
      icon: "💊",
      message: message,
    );
  }
  
  /// 8. Calculate Digestive Health Risk based on fiber content
  HealthRiskFactor _calculateDigestiveHealthRisk(Map<String, double> values) {
    // Get values (defaulting to 0 if not found)
    final double fiber = values['fiber'] ?? 0.0;
    
    // Formula: risk_score = (3 - fiber) / 3
    double riskScore = (3 - fiber) / 3;
    
    // Clamp between 0 and 1
    riskScore = riskScore.clamp(0.0, 1.0);
    
    // Calculate score on 0-100 scale
    int score = (riskScore * 100).round();
    
    // Determine risk level message
    String message;
    if (fiber >= 3.0) {
      message = "Good source of fiber. Promotes digestive health.";
    } else if (fiber >= 1.5) {
      message = "Moderate fiber content. Include other fiber-rich foods throughout the day.";
    } else {
      message = "Low in fiber. Consider adding high-fiber foods to your diet for digestive health.";
    }
    
    return HealthRiskFactor(
      name: "Digestive Health Risk",
      score: score,
      icon: "🦠",
      message: message,
    );
  }
  
  /// 9. Calculate Bone Health Risk based on calcium, vitamin K, magnesium, and phosphorus
  HealthRiskFactor _calculateBoneHealthRisk(Map<String, double> values) {
    // Get values (defaulting to 0 if not found)
    final double calcium = values['calcium'] ?? 0.0;
    final double vitaminK = values['vitamin_k'] ?? 0.0;
    final double magnesium = values['magnesium'] ?? 0.0;
    final double phosphorus = values['phosphorus'] ?? 0.0;
    
    // Formula: Calculate individual risk scores (higher value = lower risk)
    double calciumRisk = (200 - calcium) / 200;
    double vitKRisk = (40 - vitaminK) / 40;
    double magnesiumRisk = (100 - magnesium) / 100;
    double phosphorusRisk = (200 - phosphorus) / 200;
    
    // Clamp each between 0 and 1
    calciumRisk = calciumRisk.clamp(0.0, 1.0);
    vitKRisk = vitKRisk.clamp(0.0, 1.0);
    magnesiumRisk = magnesiumRisk.clamp(0.0, 1.0);
    phosphorusRisk = phosphorusRisk.clamp(0.0, 1.0);
    
    // Calculate average risk
    double riskScore = (calciumRisk + vitKRisk + magnesiumRisk + phosphorusRisk) / 4;
    
    // Calculate score on 0-100 scale
    int score = (riskScore * 100).round();
    
    // Determine risk level message
    String message;
    if (riskScore <= 0.3) {
      message = "Good bone-supporting nutrients (calcium, vitamin K, magnesium, phosphorus) for optimal bone health.";
    } else if (riskScore <= 0.6) {
      message = "Moderate bone health support. Include calcium-rich and mineral-dense foods in your diet.";
    } else {
      message = "Limited bone health nutrients. Consider dairy, leafy greens, and nuts for better bone support.";
    }
    
    return HealthRiskFactor(
      name: "Bone Health Risk",
      score: score,
      icon: "🦴",
      message: message,
    );
  }
  
  /// 10. Calculate Muscle Loss Risk based on protein content
  HealthRiskFactor _calculateMuscleLossRisk(Map<String, double> values) {
    // Get values (defaulting to 0 if not found)
    final double protein = values['protein'] ?? 0.0;
    
    // Formula: risk_score = (4 - protein) / 4
    double riskScore = (4 - protein) / 4;
    
    // Clamp between 0 and 1
    riskScore = riskScore.clamp(0.0, 1.0);
    
    // Calculate score on 0-100 scale
    int score = (riskScore * 100).round();
    
    // Determine risk level message
    String message;
    if (protein >= 4.0) {
      message = "Good protein source. Supports muscle maintenance.";
    } else if (protein >= 2.0) {
      message = "Moderate protein content. Include other protein sources throughout the day.";
    } else {
      message = "Low in protein. Consider adding protein-rich foods to your diet.";
    }
    
    return HealthRiskFactor(
      name: "Muscle Loss Risk",
      score: score,
      icon: "💪",
      message: message,
    );
  }
  
  /// Create default risk factors in case of calculation errors
  List<HealthRiskFactor> _createDefaultRisks() {
    return [
      HealthRiskFactor(
        name: "Diabetes Risk",
        score: 50,
        icon: "🩸",
        message: "Moderate risk for blood sugar levels.",
      ),
      HealthRiskFactor(
        name: "Cholesterol Risk",
        score: 50,
        icon: "🫀",
        message: "Moderate impact on cholesterol levels.",
      ),
      HealthRiskFactor(
        name: "BP Risk",
        score: 50,
        icon: "🩺",
        message: "Moderate impact on blood pressure.",
      ),
      HealthRiskFactor(
        name: "Obesity Risk",
        score: 50,
        icon: "⚖️",
        message: "Moderate risk of contributing to weight gain.",
      ),
      HealthRiskFactor(
        name: "Heart Disease Risk",
        score: 50,
        icon: "💓",
        message: "Moderate risk for heart health.",
      ),
      HealthRiskFactor(
        name: "Iron Deficiency Risk",
        score: 50,
        icon: "🩸",
        message: "Moderate iron content for preventing deficiency.",
      ),
      HealthRiskFactor(
        name: "Vitamin Deficiency Risk",
        score: 50,
        icon: "💊",
        message: "Moderate vitamin content for overall health.",
      ),
      HealthRiskFactor(
        name: "Digestive Health Risk",
        score: 50,
        icon: "🦠",
        message: "Moderate fiber content for digestive health.",
      ),
      HealthRiskFactor(
        name: "Bone Health Risk",
        score: 50,
        icon: "🦴",
        message: "Moderate nutritional value for bone health.",
      ),
      HealthRiskFactor(
        name: "Muscle Loss Risk",
        score: 50,
        icon: "💪",
        message: "Moderate protein content for muscle maintenance.",
      ),
    ];
  }
} 