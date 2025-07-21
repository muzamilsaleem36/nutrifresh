import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:nutrifresh/models/food_info.dart';
import 'package:path/path.dart' as path;
import 'package:nutrifresh/services/api/endpoints.dart';
import 'package:nutrifresh/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling image uploads to the server
class UploadService {
  // AppConfig instance for dynamic server URL
  final AppConfig _appConfig = AppConfig();
  
  // Get server URL from AppConfig
  String get _uploadUrl => '${_appConfig.apiBaseUrl}${ApiEndpoints.analyzeFood}';
  String get _webApiUrl => '${_appConfig.apiBaseUrl}${ApiEndpoints.analyzeFoodWeb}';
  
  // Log environment info
  void _logEnvironmentInfo() {
    if (kDebugMode) {
      print('API Environment: ${_appConfig.apiEnvironment}');
      print('API Base URL: ${_appConfig.apiBaseUrl}');
      print('Upload URL: $_uploadUrl');
      print('Device platform: ${kIsWeb ? 'Web' : 'Mobile'}');
    }
  }
  
  // Image types allowed
  static const List<String> _allowedExtensions = [
    'jpg', 'jpeg', 'png', 'webp', 'gif',
  ];
  
  // Singleton instance
  static final UploadService _instance = UploadService._internal();
  
  // Factory constructor
  factory UploadService() {
    return _instance;
  }
  
  // Private constructor
  UploadService._internal() {
    _logEnvironmentInfo();
  }
  
  // Reload configuration (called when settings change)
  void reloadConfig() {
    _appConfig.reloadApiSettings();
    _logEnvironmentInfo();
  }
  
  /// Upload an image file with session ID to the server
  Future<FoodInfo> uploadImage(File imageFile, String sessionId) async {
    try {
      if (kDebugMode) {
        print('Uploading image: ${imageFile.path} with session ID: $sessionId');
      }
      
      // For web platform, we need to handle differently
      if (kIsWeb) {
        // Convert file to bytes and then to base64
        try {
          final List<int> imageBytes = await imageFile.readAsBytes();
          final String base64Image = base64Encode(imageBytes);
          return uploadBase64Image(base64Image, sessionId);
        } catch (e) {
          if (kDebugMode) {
            print('Error converting file to base64: $e');
          }
          // Return fallback data in case of error
          return _createFallbackFoodInfo(sessionId);
        }
      }
      
      // Mobile platform handling
      // Validate image file
      final bool isValid = await _validateImageFile(imageFile);
      if (!isValid) {
        throw Exception('Invalid image file. Please select a valid image.');
      }
      
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      
      // Get file extension
      final String extension = _getFileExtension(imageFile.path);
      
      // Add session ID to request
      request.fields['session_id'] = sessionId;
      
      // Add file to request
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', extension),
        ),
      );
      
      // Send request and await response
      final responseStream = await request.send();
      final response = await http.Response.fromStream(responseStream);
      
      if (kDebugMode) {
        print('Upload response status: ${response.statusCode}');
        print('Upload response body: ${response.body}');
      }
      
      // Check if response is successful
      if (response.statusCode == 200) {
        // Parse response
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        
        // Add session ID if not included in response
        if (jsonResponse['session_id'] == null) {
          jsonResponse['session_id'] = sessionId;
        }
        
        // Convert response format if needed
        return _convertResponseToFoodInfo(jsonResponse, sessionId);
      } else {
        // Handle error response
        final errorMessage = response.body.isNotEmpty
            ? 'Server error: ${response.body}'
            : 'Server error: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image: $e');
      }
      
      // Return fallback data in case of error
      return _createFallbackFoodInfo(sessionId);
    }
  }
  
  /// Upload an image in base64 format (useful for web)
  Future<FoodInfo> uploadBase64Image(String base64Image, String sessionId) async {
    try {
      if (kDebugMode) {
        print('Uploading base64 image with session ID: $sessionId');
      }
      
      // Create request body
      final Map<String, dynamic> requestBody = {
        'image': base64Image,
        'session_id': sessionId,
      };
      
      // Send POST request
      final response = await http.post(
        Uri.parse(_webApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      if (kDebugMode) {
        print('Upload response status: ${response.statusCode}');
      }
      
      // Check if response is successful
      if (response.statusCode == 200) {
        // Parse response
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        
        // Add session ID if not included in response
        if (jsonResponse['session_id'] == null) {
          jsonResponse['session_id'] = sessionId;
        }
        
        // Convert response format if needed
        return _convertResponseToFoodInfo(jsonResponse, sessionId);
      } else {
        // Handle error response
        final errorMessage = response.body.isNotEmpty
            ? 'Server error: ${response.body}'
            : 'Server error: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading base64 image: $e');
      }
      
      // Return fallback data in case of error
      return _createFallbackFoodInfo(sessionId);
    }
  }
  
  /// Convert server response to FoodInfo model
  FoodInfo _convertResponseToFoodInfo(Map<String, dynamic> jsonResponse, String sessionId) {
    try {
      // Check if response has flat nutrition values or nested objects
      if (jsonResponse.containsKey('nutrition') && jsonResponse['nutrition'] is Map) {
        // Convert flat nutrition map to nutrition items list
        final nutritionMap = jsonResponse['nutrition'] as Map<String, dynamic>;
        final List<Map<String, dynamic>> nutritionItems = [];
        
        nutritionMap.forEach((key, value) {
          String icon = '📊'; // Default icon
          
          // Map common nutrition keys to appropriate icons
          switch (key) {
            // Macronutrients
            case 'energy': case 'calories': icon = '🔥'; break;
            case 'carbohydrates': icon = '🍞'; break;
            case 'sugars': icon = '🍭'; break;
            case 'dietary_fiber': case 'fiber': icon = '🌾'; break;
            case 'protein': icon = '🍗'; break;
            case 'total_fat': case 'saturated_fat': icon = '🧈'; break;
            // Vitamins
            case 'vitamin_c': icon = '🍊'; break;
            case 'vitamin_a': icon = '👁️'; break;
            case 'vitamin_k': icon = '🩸'; break;
            case 'folate': icon = '🧬'; break;
            case 'vitamin_b6': icon = '💊'; break;
            case 'niacin': icon = '⚡'; break;
            case 'riboflavin': icon = '🔬'; break;
            case 'thiamin': icon = '🧪'; break;
            case 'vitamin_e': icon = '🌿'; break;
            // Minerals
            case 'potassium': icon = '🔋'; break;
            case 'calcium': icon = '🦴'; break;
            case 'magnesium': icon = '🧲'; break;
            case 'phosphorus': icon = '⚛️'; break;
            case 'iron': icon = '⚙️'; break;
            case 'zinc': icon = '🔩'; break;
            case 'sodium': icon = '🧂'; break;
            case 'copper': icon = '🟠'; break;
            case 'manganese': icon = '🔘'; break;
            case 'selenium': icon = '🌟'; break;
          }
          
          nutritionItems.add({
            'name': key.split('_').map((word) => 
              word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}'
            ).join(' '),
            'value': '$value ${_getNutritionUnit(key)}',
            'icon': icon,
          });
        });
        
        // Replace nutrition object with list
        jsonResponse['nutrition'] = nutritionItems;
      }
      
      // Check if storage recommendations need formatting
      if (jsonResponse.containsKey('storage_recommendations') && 
          jsonResponse['storage_recommendations'] is List) {
        final storageList = jsonResponse['storage_recommendations'] as List;
        
        // Check if recommendations already have all required fields
        final needsFormatting = storageList.isNotEmpty && 
            (storageList.first is Map && !storageList.first.containsKey('icon'));
        
        if (needsFormatting) {
          final List<Map<String, dynamic>> formattedStorage = [];
          
          for (final item in storageList) {
            if (item is Map) {
              final Map<String, dynamic> storageItem = Map<String, dynamic>.from(item);
              
              // Add icon based on method
              if (storageItem.containsKey('method')) {
                final method = storageItem['method'];
                storageItem['icon'] = _getStorageIcon(method);
              }
              
              // Add estimated days if not present
              if (!storageItem.containsKey('estimated_extension_days')) {
                storageItem['estimated_extension_days'] = _getDefaultExtensionDays(
                  storageItem['method']
                );
              }
              
              formattedStorage.add(storageItem);
            }
          }
          
          jsonResponse['storage_recommendations'] = formattedStorage;
        }
      }
      
      // Add freshness object if not present
      if (!jsonResponse.containsKey('freshness')) {
        jsonResponse['freshness'] = {
          'level': 'Fresh',
          'percentage': 85,
        };
      } else if (jsonResponse['freshness'] is Map && 
                jsonResponse['freshness'].containsKey('class') && 
                !jsonResponse['freshness'].containsKey('level')) {
        // Map 'class' to 'level' if needed
        jsonResponse['freshness']['level'] = jsonResponse['freshness']['class'];
      }
      
      return FoodInfo.fromJson(jsonResponse);
    } catch (e) {
      if (kDebugMode) {
        print('Error converting server response to FoodInfo: $e');
      }
      return _createFallbackFoodInfo(sessionId);
    }
  }
  
  /// Get appropriate unit for nutrition value
  String _getNutritionUnit(String key) {
    switch (key.toLowerCase()) {
      // Macronutrients
      case 'energy':
      case 'calories': return 'kcal';
      case 'protein': 
      case 'carbohydrates': 
      case 'sugars': 
      case 'dietary_fiber':
      case 'fiber': 
      case 'total_fat': 
      case 'saturated_fat': return 'g';
      // Vitamins (water-soluble - mg)
      case 'vitamin_c':
      case 'vitamin_b6':
      case 'niacin':
      case 'riboflavin':
      case 'thiamin':
      case 'vitamin_e': return 'mg';
      // Vitamins (fat-soluble - µg)
      case 'vitamin_a':
      case 'vitamin_k':
      case 'folate': return 'µg';
      // Minerals (major - mg)
      case 'sodium': 
      case 'potassium': 
      case 'calcium':
      case 'magnesium':
      case 'phosphorus':
      case 'iron':
      case 'zinc':
      case 'copper':
      case 'manganese': return 'mg';
      // Minerals (trace - µg)
      case 'selenium': return 'µg';
      default: return '';
    }
  }
  
  /// Get storage method icon
  String _getStorageIcon(String method) {
    switch (method.toLowerCase()) {
      case 'refrigeration': return '🧊';
      case 'freezing': return '❄️';
      case 'room_temperature': return '🏠';
      case 'airtight_container': return '🫙';
      case 'paper_bag': return '📦';
      case 'ventilated_storage': return '🌬️';
      case 'hydrocooling': return '💧';
      default: return '📦';
    }
  }
  
  /// Get default extension days for storage method
  int _getDefaultExtensionDays(String method) {
    switch (method.toLowerCase()) {
      case 'refrigeration': return 7;
      case 'freezing': return 30;
      case 'room_temperature': return 3;
      case 'airtight_container': return 4;
      case 'paper_bag': return 3;
      case 'ventilated_storage': return 7;
      case 'hydrocooling': return 2;
      default: return 5;
    }
  }
  
  /// Create fallback food info for error handling
  FoodInfo _createFallbackFoodInfo(String sessionId) {
    // Create a basic fallback object with generic data
    return FoodInfo(
      foodName: "Unknown Food",
      category: "Other",
      freshness: Freshness(
        level: "Unknown",
        percentage: 50,
      ),
      nutrition: [
        NutritionItem(
          name: "Calories",
          value: "0 kcal",
          icon: "🔥",
        ),
        NutritionItem(
          name: "Protein",
          value: "0 g",
          icon: "🍗",
        ),
        NutritionItem(
          name: "Carbohydrates",
          value: "0 g",
          icon: "🍞",
        ),
      ],
      storageRecommendations: [
        StorageMethod(
          method: "refrigeration",
          icon: "🧊",
          estimatedExtensionDays: 3,
          message: "Store in refrigerator for best results",
        ),
      ],
      healthRiskFactors: [],
      sessionId: sessionId,
      imageUrl: null,
      iconPath: null,
      timestamp: DateTime.now().toIso8601String(),
    );
  }
  
  /// Validate that the file is a valid image
  Future<bool> _validateImageFile(File file) async {
    try {
      // Safety check for web platform
      if (kIsWeb) {
        // Basic validation on web - just check if file has content
        final bytes = await file.readAsBytes();
        return bytes.isNotEmpty;
      }
      
      // Check if file exists
      if (!await file.exists()) {
        return false;
      }
      
      // Check file extension
      final String extension = _getFileExtension(file.path);
      if (!_allowedExtensions.contains(extension)) {
        return false;
      }
      
      // Check file size (max 10MB)
      final int fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        return false;
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error validating image file: $e');
      }
      return false;
    }
  }
  
  /// Helper method to get file extension
  String _getFileExtension(String filePath) {
    try {
      final String extension = path.extension(filePath).toLowerCase();
      return extension.isNotEmpty ? extension.substring(1) : '';
    } catch (e) {
      // Return default extension if error occurs
      return 'jpg';
    }
  }
} 