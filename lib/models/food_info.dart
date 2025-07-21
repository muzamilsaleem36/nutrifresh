class FoodInfo {
  final String foodName;
  final String category;
  final Freshness freshness;
  final List<NutritionItem> nutrition;
  final List<StorageMethod> storageRecommendations;
  final List<HealthRiskFactor> healthRiskFactors;
  final String? sessionId;
  final String? imageUrl;
  final String? iconPath;
  final String? timestamp;
  final String? status;

  FoodInfo({
    required this.foodName,
    required this.category,
    required this.freshness,
    required this.nutrition,
    required this.storageRecommendations,
    required this.healthRiskFactors,
    this.sessionId,
    this.imageUrl,
    this.iconPath,
    this.timestamp,
    this.status,
  });

  factory FoodInfo.fromJson(Map<String, dynamic> json) {
    return FoodInfo(
      foodName: json['food_name'] ?? 'Unknown',
      category: json['category'] ?? 'Unknown',
      freshness: json['freshness'] != null
          ? Freshness.fromJson(json['freshness'])
          : Freshness(level: 'Unknown', percentage: 0),
      nutrition: json['nutrition'] != null
          ? List<NutritionItem>.from(
              json['nutrition'].map((x) => NutritionItem.fromJson(x)))
          : [],
      storageRecommendations: json['storage_recommendations'] != null
          ? List<StorageMethod>.from(
              json['storage_recommendations']
                  .map((x) => StorageMethod.fromJson(x)))
          : [],
      healthRiskFactors: json['health_risk_factors'] != null
          ? List<HealthRiskFactor>.from(
              json['health_risk_factors'].map((x) => HealthRiskFactor.fromJson(x)))
          : [],
      sessionId: json['session_id'],
      imageUrl: json['image_url'],
      iconPath: json['icon_path'],
      timestamp: json['timestamp'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food_name': foodName,
      'category': category,
      'freshness': freshness.toJson(),
      'nutrition': nutrition.map((x) => x.toJson()).toList(),
      'storage_recommendations':
          storageRecommendations.map((x) => x.toJson()).toList(),
      'health_risk_factors': healthRiskFactors.map((x) => x.toJson()).toList(),
      'session_id': sessionId,
      'image_url': imageUrl,
      'icon_path': iconPath,
      'timestamp': timestamp ?? DateTime.now().toIso8601String(),
      'status': status,
    };
  }
}

class Freshness {
  final String level;
  final int percentage;

  Freshness({
    required this.level,
    required this.percentage,
  });

  factory Freshness.fromJson(Map<String, dynamic> json) {
    return Freshness(
      level: json['level'] ?? 'Unknown',
      percentage: json['percentage'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'percentage': percentage,
    };
  }
}

class NutritionItem {
  final String name;
  final String value;
  final String icon;

  NutritionItem({
    required this.name,
    required this.value,
    required this.icon,
  });

  factory NutritionItem.fromJson(Map<String, dynamic> json) {
    return NutritionItem(
      name: json['name'] ?? 'Unknown',
      value: json['value'] ?? '0',
      icon: json['icon'] ?? '📊',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'icon': icon,
    };
  }
}

class StorageMethod {
  final String method;
  final String icon;
  final int estimatedExtensionDays;
  final String message;

  StorageMethod({
    required this.method,
    required this.icon,
    required this.estimatedExtensionDays,
    required this.message,
  });

  factory StorageMethod.fromJson(Map<String, dynamic> json) {
    return StorageMethod(
      method: json['method'] ?? 'storage',
      icon: json['icon'] ?? '📦',
      estimatedExtensionDays: json['estimated_extension_days'] ?? 0,
      message: json['message'] ?? 'This can extend shelf life.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'icon': icon,
      'estimated_extension_days': estimatedExtensionDays,
      'message': message,
    };
  }
}

class HealthRiskFactor {
  final String name;
  final int score;
  final String icon;
  final String message;

  HealthRiskFactor({
    required this.name,
    required this.score,
    required this.icon,
    required this.message,
  });

  factory HealthRiskFactor.fromJson(Map<String, dynamic> json) {
    return HealthRiskFactor(
      name: json['name'] ?? 'Unknown Risk',
      score: json['score'] ?? 0,
      icon: json['icon'] ?? '⚠️',
      message: json['message'] ?? 'No information available.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'score': score,
      'icon': icon,
      'message': message,
    };
  }
} 