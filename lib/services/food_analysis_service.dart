import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nutrifresh/models/food_info.dart';
import 'package:nutrifresh/services/api/api_client.dart';
import 'package:nutrifresh/services/api/api_exception.dart';
import 'package:nutrifresh/services/api/endpoints.dart';
import 'package:nutrifresh/config/app_config.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Service interface for food analysis functionality
abstract class IFoodAnalysisService {
  /// Analyzes a food image and returns nutritional information
  Future<FoodInfo> analyzeFoodImage(File image, {String? sessionId});
  
  /// Get food information by ID
  Future<FoodInfo> getFoodById(String foodId);
  
  /// Get user's food history
  Future<List<FoodInfo>> getFoodHistory({int limit, int offset});
}

/// Service for analyzing food images and retrieving food information
class FoodAnalysisService implements IFoodAnalysisService {
  // Logger for the service
  final _logger = Logger('FoodAnalysisService');
  
  // API client
  final ApiClient _apiClient;
  
  /// Constructor with dependency injection
  /// 
  /// [apiClient] - The API client to use for network requests
  FoodAnalysisService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.fromAppConfig();

  /// Analyzes a food image and returns nutritional information
  @override
  Future<FoodInfo> analyzeFoodImage(File image, {String? sessionId}) async {
    try {
      _logger.info('Making API call to analyze food image');
      
      // Handle platform-specific issues
      if (kIsWeb) {
        try {
          // For web, convert file to base64
          final List<int> imageBytes = await image.readAsBytes();
          final String base64Image = base64Encode(imageBytes);
          
          // Use the base64 specific method for web
          return analyzeFoodImageBase64(base64Image, sessionId: sessionId);
        } catch (e) {
          _logger.warning('Error processing web image: $e');
          throw ApiException(
            type: ApiExceptionType.invalidInput,
            message: 'Could not process web image: $e',
          );
        }
      }
      
      // Mobile platform path - try to use real API
      try {
        // Validate image file before sending
        if (!await _validateImage(image)) {
          throw ApiException(
            type: ApiExceptionType.invalidInput,
            message: 'Invalid image file. Please select a valid image under 10MB.',
          );
        }
        
        // Prepare form data with session ID if provided
        Map<String, String>? fields;
        if (sessionId != null) {
          fields = {'session_id': sessionId};
        }
        
        // Upload the image file to the real API
        final response = await _apiClient.uploadFile(
          ApiEndpoints.analyzeFood,
          filePath: image.path,
          fieldName: 'file',
          fileName: 'food_image.jpg',
          fields: fields,
          onSendProgress: (sent, total) {
            final progress = (sent / total) * 100;
            _logger.info('Upload progress: ${progress.toStringAsFixed(2)}%');
          },
        );
        
        // Parse the response and convert to FoodInfo model
        if (response is Map<String, dynamic>) {
          return FoodInfo.fromJson(response);
        } else {
          throw ApiException(
            type: ApiExceptionType.badResponse,
            message: 'Unexpected response format',
          );
        }
      } catch (e) {
        _logger.warning('API request failed: $e');
        rethrow;
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      _logger.severe('Error analyzing image: $e');
      throw ApiException(
        type: ApiExceptionType.other,
        message: 'Unexpected error analyzing image: $e',
      );
    }
  }
  
  /// Analyze a food image using base64 encoding (primarily for web)
  Future<FoodInfo> analyzeFoodImageBase64(String base64Image, {String? sessionId}) async {
    try {
      _logger.info('Making API call to analyze food image using base64');
      
      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'image': base64Image,
        'wait_for_response': true,
      };
      
      // Add session ID if provided
      if (sessionId != null) {
        requestBody['session_id'] = sessionId;
      }
      
      // Send the base64 image to the API
      final response = await _apiClient.post(
        ApiEndpoints.analyzeFoodWeb,
        data: requestBody,
        onSendProgress: (sent, total) {
          final progress = (sent / total) * 100;
          _logger.info('Upload progress: ${progress.toStringAsFixed(2)}%');
        },
      );
      
      // Parse the response and convert to FoodInfo model
      if (response is Map<String, dynamic>) {
        return FoodInfo.fromJson(response);
      } else {
        throw ApiException(
          type: ApiExceptionType.badResponse,
          message: 'Unexpected response format for base64 image analysis',
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      _logger.severe('Error analyzing base64 image: $e');
      throw ApiException(
        type: ApiExceptionType.other,
        message: 'Unexpected error during base64 image analysis: $e',
      );
    }
  }
  
  /// Get food information by ID
  @override
  Future<FoodInfo> getFoodById(String foodId) async {
    try {
      // Get food details from the API
      final response = await _apiClient.get(
        '${ApiEndpoints.getFoodDetails}/$foodId',
      );
      
      // Parse the response and convert to FoodInfo model
      if (response is Map<String, dynamic>) {
        return FoodInfo.fromJson(response);
      } else {
        throw ApiException(
          type: ApiExceptionType.badResponse,
          message: 'Invalid response format for food details',
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      _logger.severe('Error getting food details: $e');
      throw ApiException(
        type: ApiExceptionType.other,
        message: 'Error retrieving food details: $e',
      );
    }
  }
  
  /// Get user's food history
  @override
  Future<List<FoodInfo>> getFoodHistory({int limit = 10, int offset = 0}) async {
    try {
      // Get food history from the API
      final response = await _apiClient.get(
        ApiEndpoints.getFoodHistory,
        queryParameters: {
          'limit': limit.toString(),
          'offset': offset.toString(),
        },
      );
      
      // Parse the response and convert to a list of FoodInfo objects
      if (response is List) {
        return response
            .map((item) => FoodInfo.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (response is Map<String, dynamic> && response.containsKey('results')) {
        final results = response['results'] as List;
        return results
            .map((item) => FoodInfo.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          type: ApiExceptionType.badResponse,
          message: 'Unexpected response format for food history',
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      _logger.severe('Error getting food history: $e');
      throw ApiException(
        type: ApiExceptionType.other,
        message: 'Error retrieving food history: $e',
      );
    }
  }
  
  /// Validate an image file before sending
  Future<bool> _validateImage(File image) async {
    try {
      // Check if file exists
      if (!await image.exists()) {
        _logger.warning('Image file does not exist');
        return false;
      }
      
      // Check file size
      final fileSize = await image.length();
      const maxSize = 10 * 1024 * 1024; // 10MB
      
      if (fileSize > maxSize) {
        _logger.warning('Image file is too large: ${fileSize / 1024 / 1024}MB');
        return false;
      }
      
      // Try to read a small portion of the file to ensure it's readable
      await image.openRead(0, 100).first;
      
      return true;
    } catch (e) {
      _logger.warning('Error validating image: $e');
      return false;
    }
  }
  
  /// Poll for a response for a pending request
  Future<FoodInfo?> pollForResponse(String sessionId) async {
    try {
      _logger.info('Polling for response with session ID: $sessionId');
      
      // Call the get response endpoint to check if a response is available
      final response = await _apiClient.get(
        '${ApiEndpoints.getResponse}/$sessionId',
      );
      
      _logger.info('Received polling response type: ${response.runtimeType}');
      
      // If we got a null response, return null to continue polling
      if (response == null) {
        _logger.info('Null response received for session: $sessionId');
        return null;
      }
      
      // Check if we got a pending status
      if (response is Map<String, dynamic> && 
          response['status'] == 'pending') {
        _logger.info('Response still pending for session: $sessionId');
        return null;
      }
      
      // If we have a real response, convert it to a FoodInfo object
      if (response is Map<String, dynamic>) {
        try {
          // Log the response data for debugging
          _logger.info('Converting response to FoodInfo: ${response.keys.join(', ')}');
          
          if (response.containsKey('session_id')) {
            _logger.info('Response session_id: ${response['session_id']}');
          }
          
          if (response.containsKey('food_name')) {
            _logger.info('Response food_name: ${response['food_name']}');
          }
          
          // Handle different response formats
          // Format nutrition data correctly if needed
          if (response.containsKey('nutrition')) {
            var nutrition = response['nutrition'];
            
            // If nutrition is a map/object, convert it to the list format expected by FoodInfo
            if (nutrition is Map<String, dynamic>) {
              _logger.info('Converting nutrition map to list format');
              List<Map<String, dynamic>> nutritionList = [];
              
              nutrition.forEach((key, value) {
                String unit = '';
                String icon = '';
                
                // Determine appropriate unit and icon based on nutrient type
                switch (key) {
                  // Macronutrients
                  case 'energy':
                  case 'calories':
                    unit = 'kcal';
                    icon = '🔥';
                    break;
                  case 'protein':
                    unit = 'g';
                    icon = '🍗';
                    break;
                  case 'carbohydrates':
                    unit = 'g';
                    icon = '🍞';
                    break;
                  case 'sugars':
                    unit = 'g';
                    icon = '🍭';
                    break;
                  case 'dietary_fiber':
                  case 'fiber':
                    unit = 'g';
                    icon = '🌾';
                    break;
                  case 'total_fat':
                  case 'saturated_fat':
                    unit = 'g';
                    icon = '🧈';
                    break;
                  // Vitamins (water-soluble)
                  case 'vitamin_c':
                    unit = 'mg';
                    icon = '🍊';
                    break;
                  case 'vitamin_b6':
                    unit = 'mg';
                    icon = '💊';
                    break;
                  case 'niacin':
                    unit = 'mg';
                    icon = '⚡';
                    break;
                  case 'riboflavin':
                    unit = 'mg';
                    icon = '🔬';
                    break;
                  case 'thiamin':
                    unit = 'mg';
                    icon = '🧪';
                    break;
                  case 'vitamin_e':
                    unit = 'mg';
                    icon = '🌿';
                    break;
                  // Vitamins (fat-soluble)
                  case 'vitamin_a':
                    unit = 'µg';
                    icon = '👁️';
                    break;
                  case 'vitamin_k':
                    unit = 'µg';
                    icon = '🩸';
                    break;
                  case 'folate':
                    unit = 'µg';
                    icon = '🧬';
                    break;
                  // Minerals (major)
                  case 'sodium':
                    unit = 'mg';
                    icon = '🧂';
                    break;
                  case 'potassium':
                    unit = 'mg';
                    icon = '🔋';
                    break;
                  case 'calcium':
                    unit = 'mg';
                    icon = '🦴';
                    break;
                  case 'magnesium':
                    unit = 'mg';
                    icon = '🧲';
                    break;
                  case 'phosphorus':
                    unit = 'mg';
                    icon = '⚛️';
                    break;
                  case 'iron':
                    unit = 'mg';
                    icon = '⚙️';
                    break;
                  case 'zinc':
                    unit = 'mg';
                    icon = '🔩';
                    break;
                  case 'copper':
                    unit = 'mg';
                    icon = '🟠';
                    break;
                  case 'manganese':
                    unit = 'mg';
                    icon = '🔘';
                    break;
                  // Minerals (trace)
                  case 'selenium':
                    unit = 'µg';
                    icon = '🌟';
                    break;
                  default:
                    unit = '';
                    icon = '📊';
                }
                
                // Format the key for display (convert snake_case to Title Case)
                String formattedKey = key.split('_')
                    .map((word) => word.substring(0, 1).toUpperCase() + word.substring(1))
                    .join(' ');
                
                nutritionList.add({
                  'name': formattedKey,
                  'value': '$value $unit',
                  'icon': icon,
                });
              });
              
              // Replace the nutrition data with our formatted list
              response['nutrition'] = nutritionList;
            }
          }
          
          // Ensure all storage recommendations have required fields
          if (response.containsKey('storage_recommendations') && 
              response['storage_recommendations'] is List) {
            List<dynamic> recommendations = response['storage_recommendations'];
            
            for (int i = 0; i < recommendations.length; i++) {
              if (recommendations[i] is Map<String, dynamic>) {
                var rec = recommendations[i] as Map<String, dynamic>;
                
                // Add icon if missing
                if (!rec.containsKey('icon')) {
                  String method = rec['method'] ?? 'unknown';
                  switch (method) {
                    case 'refrigeration': rec['icon'] = '🧊'; break;
                    case 'freezing': rec['icon'] = '❄️'; break;
                    case 'airtight_container': rec['icon'] = '🫙'; break;
                    case 'paper_bag': rec['icon'] = '📦'; break;
                    case 'ventilated_storage': rec['icon'] = '💨'; break;
                    default: rec['icon'] = '📦';
                  }
                }
                
                // Add estimatedExtensionDays if missing
                if (!rec.containsKey('estimatedExtensionDays')) {
                  rec['estimatedExtensionDays'] = 3;
                }
              }
            }
          }
          
          _logger.info('About to convert to FoodInfo: food_name=${response['food_name']}, category=${response['category']}');
          
          // Convert to FoodInfo
          return FoodInfo.fromJson(response);
        } catch (conversionError) {
          _logger.severe('Error converting response to FoodInfo: $conversionError');
          _logger.severe('Response data: $response');
          rethrow;
        }
      }
      
      return null;
    } on ApiException catch (e) {
      if (e.type == ApiExceptionType.badResponse) {
        // This might mean the response is still pending
        _logger.info('No response available yet for session: $sessionId');
        return null;
      }
      _logger.warning('API exception during polling: ${e.message}');
      return null; // Return null instead of throwing to allow polling to continue
    } catch (e) {
      _logger.warning('Error polling for response: $e');
      return null; // Return null instead of throwing to allow polling to continue
    }
  }
} 