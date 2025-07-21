import 'package:nutrifresh/models/food_info.dart';

/// Base API response wrapper
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final Map<String, dynamic>? meta;
  final List<String>? errors;
  
  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.meta,
    this.errors,
  });
  
  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      meta: json['meta'] != null ? Map<String, dynamic>.from(json['meta']) : null,
      errors: json['errors'] != null 
          ? List<String>.from(json['errors'].map((e) => e.toString()))
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (data != null) 'data': data,
      if (meta != null) 'meta': meta,
      if (errors != null) 'errors': errors,
    };
  }
}

/// Food analysis request model
class FoodAnalysisRequest {
  final String imagePath;
  final Map<String, dynamic>? additionalInfo;
  
  FoodAnalysisRequest({
    required this.imagePath,
    this.additionalInfo,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'image_path': imagePath,
      if (additionalInfo != null) 'additional_info': additionalInfo,
    };
  }
}

/// Food history response model
class FoodHistoryResponse {
  final List<FoodInfo> foods;
  final int total;
  final int page;
  final int limit;
  
  FoodHistoryResponse({
    required this.foods,
    required this.total,
    required this.page,
    required this.limit,
  });
  
  factory FoodHistoryResponse.fromJson(Map<String, dynamic> json) {
    return FoodHistoryResponse(
      foods: (json['foods'] as List<dynamic>?)?.map((e) => FoodInfo.fromJson(e)).toList() ?? [],
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
    );
  }
} 