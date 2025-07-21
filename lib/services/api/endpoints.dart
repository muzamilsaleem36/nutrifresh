import 'package:nutrifresh/config/app_config.dart';
import 'package:flutter/foundation.dart';

/// API endpoint definitions for NutriFresh app
class ApiEndpoints {
  // Base URLs
  static const String localBaseUrl = 'http://localhost:3001';
  static const String developmentBaseUrl = 'https://dev-api.nutrifresh.app';
  static const String productionBaseUrl = 'https://api.nutrifresh.app';
  
  // Get base URL based on environment
  static String get baseUrl {
    // Always use AppConfig's apiBaseUrl to respect custom server settings
    final appConfigUrl = AppConfig().apiBaseUrl;
    if (appConfigUrl.isNotEmpty) {
      // Print the URL being used for debugging
      print('ApiEndpoints using URL: $appConfigUrl');
      return appConfigUrl;
    }
    
    // Fallback to environment-based selection if AppConfig URL is empty
    final appEnv = AppConfig().apiEnvironment;
    
    switch (appEnv) {
      case AppEnvironment.development:
        return localBaseUrl; // Using local demo server for development
      case AppEnvironment.staging:
        return developmentBaseUrl;
      case AppEnvironment.production:
        return productionBaseUrl;
    }
  }
  
  // API version
  static const String apiVersion = 'v1';
  
  // Food analysis endpoints
  static const String analyzeFood = '/api/analyze-food';
  static const String analyzeFoodWeb = '/api/analyze-base64';
  static const String getFoodHistory = '/api/v1/food-history';
  static const String getFoodDetails = '/api/session';
  static const String getResponse = '/api/session';
  
  // Session management
  static const String getSession = '/api/session';
  
  // Nutrition endpoints
  static const String getNutritionInfo = '/api/session';
  
  // Health endpoints
  static const String getHealthRisks = '/api/session';
  
  // Storage endpoints
  static const String getStorageMethods = '/api/session';
}