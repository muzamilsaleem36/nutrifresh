import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:nutrifresh/services/api/api_exception.dart';
import 'package:nutrifresh/services/api/endpoints.dart';
import 'package:nutrifresh/config/app_config.dart';
import 'dart:async'; // For Completer
import 'dart:io'; // For SocketException/// A centralized API client for handling all HTTP requests
class ApiClient {
  // Logger for API client
  final _logger = Logger('ApiClient');
  
  // Secure storage for API keys or tokens
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Current environment
  final AppEnvironment environment;
  
  // Singleton instances for each environment
  static final Map<AppEnvironment, ApiClient> _instances = {};
  
  // Dio HTTP client
  late final Dio _dio;
  
  // Token refresh in progress flag
  bool _isRefreshingToken = false;

  // Queue of waiting requests during token refresh
  final List<_RetryRequest> _pendingRequests = [];
  
  // Factory constructor that respects the environment
  factory ApiClient({AppEnvironment? environment}) {
    // Default to development in debug mode, production in release mode
    final env = environment ?? (kDebugMode ? AppEnvironment.development : AppEnvironment.production);
    
    if (!_instances.containsKey(env)) {
      _instances[env] = ApiClient._internal(env);
    }
    return _instances[env]!;
  }

  /// Create or get an instance that matches the AppConfig environment
  factory ApiClient.fromAppConfig() {
    final appConfig = AppConfig();
    return ApiClient(environment: appConfig.apiEnvironment);
  }
  
  // Private constructor
  ApiClient._internal(this.environment) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),  // Increased timeout
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (status) {
        return status != null && status < 500;  // Accept all status codes less than 500
      },
    ));
    _configureInterceptors();
    
    // Debug print to show which base URL is being used
    _logger.info('NutriFresh API client initialized for ${environment.name} environment');
    _logger.info('Using API base URL: $baseUrl');
  }
  
  /// Get the appropriate API base URL based on environment
  String get baseUrl {
    // Always use AppConfig's baseUrl to respect custom server settings
    final appConfigUrl = AppConfig().apiBaseUrl;
    if (appConfigUrl.isNotEmpty) {
      // Log the URL being used for debugging
      _logger.info('Using AppConfig URL: $appConfigUrl');
      return appConfigUrl;
    }
    
    // Fallback to environment-based URLs if AppConfig URL is empty
    switch (environment) {
      case AppEnvironment.production:
        return ApiEndpoints.productionBaseUrl;
      case AppEnvironment.staging:
        return ApiEndpoints.developmentBaseUrl;
      case AppEnvironment.development:
        return ApiEndpoints.localBaseUrl;
    }
  }
  
  /// Configure Dio interceptors for request/response handling
  void _configureInterceptors() {
    _dio.interceptors.clear();
    
    // Add retry interceptor
    _addRetryInterceptor();
    
    // Add request/response/error interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add base URL if not already present
          if (!options.path.startsWith('http')) {
            options.baseUrl = baseUrl;
          }
          
          // Add auth token if available
          final authToken = await _getAuthToken();
          if (authToken != null && authToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $authToken';
          }
          
          // Add common headers
          options.headers['Accept'] = 'application/json';
          options.headers['User-Agent'] = 'NutriFresh App';
          
          _logger.fine('API Request: ${options.method} ${options.uri}');
          _logger.fine('Request Headers: ${options.headers}');
          if (options.data != null) {
            _logger.fine('Request Data: ${options.data}');
          }
          
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.fine('API Response: ${response.statusCode}');
          _logger.fine('Response Headers: ${response.headers}');
          _logger.fine('Response Data: ${response.data}');
          return handler.next(response);
        },
        onError: (error, handler) async {
          _logger.warning('API Error: ${error.message}');
          _logger.warning('Error Type: ${error.type}');
          if (error.response != null) {
            _logger.warning('Error Response: ${error.response?.data}');
          }
          
          // Handle token refresh if 401 error and not already refreshing
          if (error.response?.statusCode == 401 && !_isRefreshingToken) {
            final refreshedRequest = await _refreshTokenAndRetry(error.requestOptions);
            if (refreshedRequest != null) {
              return handler.resolve(refreshedRequest);
            }
          }
          
          // Convert DioExceptions to our custom ApiException
          final apiException = _handleDioError(error);
          return handler.reject(apiException);
        },
      ),
    );
    
    // Add logging interceptor in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (log) => _logger.fine(log.toString()),
      ));
    }
  }

  /// Add retry interceptor for network failures
  void _addRetryInterceptor() {
    final appConfig = AppConfig();
    final maxRetryAttempts = 3; // Default value since AppConfig no longer has this
    final retryDelayMs = 1000; // Default value since AppConfig no longer has this
    
    // Skip in web platform - retry is mainly for mobile
    if (kIsWeb) return;
    
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onError: (error, handler) async {
          // Get retry attempt count from extra
          final retryCount = error.requestOptions.extra['retryCount'] as int? ?? 0;
          
          // Only retry for network errors, not server or auth errors
          if (_isNetworkError(error) && retryCount < maxRetryAttempts) {
            _logger.info('Retrying network request (attempt ${retryCount + 1}/${maxRetryAttempts})');
            
            // Wait before retry with exponential backoff
            final delay = retryDelayMs * (retryCount + 1);
            await Future.delayed(Duration(milliseconds: delay));
            
            // Clone the request with incremented retry count
            final options = Options(
              method: error.requestOptions.method,
              headers: error.requestOptions.headers,
            );
            
            final newExtra = Map<String, dynamic>.from(error.requestOptions.extra);
            newExtra['retryCount'] = retryCount + 1;
            
            try {
              final response = await _dio.request(
                error.requestOptions.path,
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
                options: options..extra = newExtra,
              );
              return handler.resolve(response);
            } catch (e) {
              // If retry also fails, continue with error handling
              return handler.next(error);
            }
          }
          
          // Pass through to next interceptor if we can't retry
          return handler.next(error);
        },
      ),
    );
  }
  
  /// Check if an error is related to network connectivity
  bool _isNetworkError(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        (!kIsWeb && error.error is SocketException); // Skip SocketException check on web
  }
  
  /// Get the authentication token from secure storage
  Future<String?> _getAuthToken() async {
    try {
      return await _secureStorage.read(key: 'auth_token');
    } catch (e) {
      _logger.warning('Error reading auth token: $e');
      return null;
    }
  }

  /// Get refresh token from secure storage
  Future<String?> _getRefreshToken() async {
    try {
      return await _secureStorage.read(key: 'refresh_token');
    } catch (e) {
      _logger.warning('Error reading refresh token: $e');
      return null;
    }
  }
  
  /// Get authentication token from secure storage - public method for AuthService
  Future<String?> getAuthToken() async {
    return _getAuthToken();
  }
  
  /// Save authentication token to secure storage
  Future<void> saveAuthToken(String token) async {
    try {
      await _secureStorage.write(key: 'auth_token', value: token);
    } catch (e) {
      _logger.warning('Error saving auth token: $e');
      throw ApiException(message: 'Failed to save authentication token');
    }
  }

  /// Save refresh token to secure storage
  Future<void> saveRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: 'refresh_token', value: token);
    } catch (e) {
      _logger.warning('Error saving refresh token: $e');
      throw ApiException(message: 'Failed to save refresh token');
    }
  }
  
  /// Delete authentication token from secure storage
  Future<void> deleteAuthToken() async {
    try {
      await _secureStorage.delete(key: 'auth_token');
    } catch (e) {
      _logger.warning('Error deleting auth token: $e');
      throw ApiException(message: 'Failed to delete authentication token');
    }
  }

  /// Delete refresh token from secure storage
  Future<void> deleteRefreshToken() async {
    try {
      await _secureStorage.delete(key: 'refresh_token');
    } catch (e) {
      _logger.warning('Error deleting refresh token: $e');
      throw ApiException(message: 'Failed to delete refresh token');
    }
  }

  /// Handle token refresh and retry original request
  Future<Response?> _refreshTokenAndRetry(RequestOptions requestOptions) async {
    _isRefreshingToken = true;
    _logger.info('Token expired, attempting to refresh...');

    // Create a completer to handle the retry
    final completer = Completer<Response?>();
    
    // Add the current request to pending queue
    _pendingRequests.add(_RetryRequest(
      requestOptions: requestOptions,
      completer: completer,
    ));

    try {
      // Get refresh token
      final refreshToken = await _getRefreshToken();
      if (refreshToken == null) {
        throw ApiException.tokenExpired(message: 'Refresh token not available');
      }

      // Call refresh token endpoint
      final response = await _dio.post(
        baseUrl + '/api/refresh-token',
        data: {
          'refresh_token': refreshToken,
        },
        options: Options(
          headers: {
            'Authorization': null, // Don't send expired token
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        // Extract new tokens
        final data = response.data;
        final newToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newToken != null) {
          // Save the new tokens
          await saveAuthToken(newToken);
          if (newRefreshToken != null) {
            await saveRefreshToken(newRefreshToken);
          }

          // Retry all pending requests
          for (final request in _pendingRequests) {
            // Add the new token to the request
            request.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            
            try {
              final retryResponse = await _dio.fetch(request.requestOptions);
              request.completer.complete(retryResponse);
            } catch (e) {
              request.completer.completeError(e);
            }
          }
        } else {
          throw ApiException(
            type: ApiExceptionType.parsingError,
            message: 'Failed to extract new token from response',
          );
        }
      } else {
        throw ApiException(
          type: ApiExceptionType.unauthorized,
          message: 'Failed to refresh token',
        );
      }
    } catch (e) {
      _logger.severe('Token refresh failed: $e');
      
      // Complete all pending requests with error
      for (final request in _pendingRequests) {
        request.completer.completeError(e);
      }
    } finally {
      _pendingRequests.clear();
      _isRefreshingToken = false;
    }

    return completer.future;
  }
  
  /// Handle DioExceptions and convert to ApiException
  DioException _handleDioError(DioException error) {
    ApiExceptionType type;
    String message;
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        type = ApiExceptionType.timeout;
        message = 'Connection timeout. Please check your internet connection.';
        break;
        
      case DioExceptionType.badResponse:
        // Handle different HTTP status codes
        final statusCode = error.response?.statusCode ?? 0;
        if (statusCode == 401) {
          type = ApiExceptionType.unauthorized;
          message = 'Unauthorized access. Please log in again.';
        } else if (statusCode == 403) {
          type = ApiExceptionType.forbidden;
          message = 'You don\'t have permission to access this resource.';
        } else if (statusCode >= 500) {
          type = ApiExceptionType.serverError;
          message = 'Server error. Please try again later.';
        } else {
          type = ApiExceptionType.badResponse;
          message = 'Bad response from server: $statusCode';
        }
        break;
        
      case DioExceptionType.cancel:
        type = ApiExceptionType.cancelled;
        message = 'Request was cancelled';
        break;
        
      default:
        type = ApiExceptionType.other;
        message = 'Network error: ${error.message}';
        break;
    }
    
    return DioException(
      requestOptions: error.requestOptions,
      error: ApiException(
        type: type,
        message: message,
        statusCode: error.response?.statusCode,
        response: error.response?.data,
      ),
    );
  }
  
  /// Standard response parsing and validation
  dynamic _parseResponse(Response response) {
    // Check for empty response
    if (response.data == null) {
      throw ApiException(
        type: ApiExceptionType.badResponse,
        message: 'Empty response from server',
        statusCode: response.statusCode,
      );
    }
    
    // If response is a success wrapper with data field
    if (response.data is Map<String, dynamic> && 
        response.data.containsKey('success') && 
        response.data.containsKey('data')) {
      
      final success = response.data['success'] as bool;
      if (!success) {
        throw ApiException(
          type: ApiExceptionType.badResponse,
          message: response.data['message'] ?? 'Unknown API error',
          statusCode: response.statusCode,
          response: response.data,
        );
      }
      
      return response.data['data'];
    }
    
    // Just return the data as-is if it doesn't match our standard format
    return response.data;
  }
  
  /// Perform a GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool parseResponse = true,
  }) async {
    try {
      final response = await _dio.get(
        baseUrl + endpoint,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      
      return parseResponse ? _parseResponse(response) : response.data;
    } on DioException catch (e) {
      throw e.error ?? ApiException(message: 'GET request failed: ${e.message}');
    } catch (e) {
      _logger.severe('Unexpected error during GET request: $e');
      throw ApiException(message: 'Unexpected error: $e');
    }
  }
  
  /// Perform a POST request
  Future<dynamic> post(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool parseResponse = true,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post(
        baseUrl + endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      
      return parseResponse ? _parseResponse(response) : response.data;
    } on DioException catch (e) {
      throw e.error ?? ApiException(message: 'POST request failed: ${e.message}');
    } catch (e) {
      _logger.severe('Unexpected error during POST request: $e');
      throw ApiException(message: 'Unexpected error: $e');
    }
  }
  
  /// Perform a PUT request
  Future<dynamic> put(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool parseResponse = true,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.put(
        baseUrl + endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      
      return parseResponse ? _parseResponse(response) : response.data;
    } on DioException catch (e) {
      throw e.error ?? ApiException(message: 'PUT request failed: ${e.message}');
    } catch (e) {
      _logger.severe('Unexpected error during PUT request: $e');
      throw ApiException(message: 'Unexpected error: $e');
    }
  }
  
  /// Perform a DELETE request
  Future<dynamic> delete(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool parseResponse = true,
  }) async {
    try {
      final response = await _dio.delete(
        baseUrl + endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      
      return parseResponse ? _parseResponse(response) : response.data;
    } on DioException catch (e) {
      throw e.error ?? ApiException(message: 'DELETE request failed: ${e.message}');
    } catch (e) {
      _logger.severe('Unexpected error during DELETE request: $e');
      throw ApiException(message: 'Unexpected error: $e');
    }
  }
  
  /// Upload a file with multipart request
  Future<dynamic> uploadFile(
    String endpoint, {
    required String filePath,
    required String fieldName,
    String? fileName,
    Map<String, dynamic>? data,
    Map<String, String>? fields,
    Options? options,
    CancelToken? cancelToken,
    bool parseResponse = true,
    ProgressCallback? onSendProgress,
  }) async {
    // Create a local cancel token to avoid memory leaks
    final localCancelToken = cancelToken ?? CancelToken();
    
    try {
      // Create form data map with file
      final Map<String, dynamic> formMap = {
        fieldName: await MultipartFile.fromFile(
          filePath,
          filename: fileName ?? filePath.split('/').last,
        ),
      };
      
      // Add any additional form fields
      if (fields != null) {
        formMap.addAll(fields);
      }
      
      // Add any other data fields
      if (data != null) {
        formMap.addAll(data);
      }
      
      final formData = FormData.fromMap(formMap);
      
      // Debug logging
      if (kDebugMode) {
        _logger.info('====== NutriFresh FILE UPLOAD ======');
        _logger.info('Upload file to: ${baseUrl + endpoint}');
        _logger.info('File path: $filePath');
        _logger.info('Field name: $fieldName');
        _logger.info('File name: ${fileName ?? filePath.split('/').last}');
        if (fields != null) {
          _logger.info('Form fields: $fields');
        }
      }
      
      // Set content type to multipart/form-data
      final requestOptions = options ?? Options();
      requestOptions.contentType = 'multipart/form-data';
      
      final response = await _dio.post(
        baseUrl + endpoint,
        data: formData,
        options: requestOptions,
        cancelToken: localCancelToken,
        onSendProgress: onSendProgress,
      );
      
      // Debug logging
      if (kDebugMode) {
        _logger.info('Response received with status: ${response.statusCode}');
        _logger.info('====== END FILE UPLOAD ======');
      }
      
      return parseResponse ? _parseResponse(response) : response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        _logger.severe('File upload error: ${e.message}, status: ${e.response?.statusCode}');
      }
      throw e.error ?? ApiException(message: 'File upload failed: ${e.message}');
    } catch (e) {
      _logger.severe('Unexpected error during file upload: $e');
      throw ApiException(message: 'Unexpected error during file upload: $e');
    }
  }
}

/// Helper class for retrying requests after token refresh
class _RetryRequest {
  final RequestOptions requestOptions;
  final Completer<Response?> completer;

  _RetryRequest({required this.requestOptions, required this.completer});
}