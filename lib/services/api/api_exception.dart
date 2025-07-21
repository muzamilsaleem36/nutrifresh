/// Exception types for API errors
enum ApiExceptionType {
  /// HTTP 401: Unauthorized
  unauthorized,
  
  /// HTTP 403: Forbidden
  forbidden,
  
  /// Invalid request format or parameters
  invalidRequest,
  
  /// Invalid input data (e.g., invalid image format)
  invalidInput,
  
  /// Connection timeout
  timeout,
  
  /// No internet connection
  noConnection,
  
  /// HTTP 400, 422, etc: Bad request or response
  badResponse,
  
  /// HTTP 5xx: Server errors
  serverError,
  
  /// Request cancelled
  cancelled,
  
  /// Data parsing error
  parsingError,
  
  /// Authentication token expired
  tokenExpired,
  
  /// Cache error
  cacheError,
  
  /// Generic error type for other errors
  other
}

/// Custom exception class for API errors
class ApiException implements Exception {
  /// Type of exception
  final ApiExceptionType type;
  
  /// Error message
  final String message;
  
  /// HTTP status code, if applicable
  final int? statusCode;
  
  /// Original response data, if available
  final dynamic response;
  
  /// Stacktrace for debugging
  final StackTrace? stackTrace;
  
  /// Error code, if available
  final String? code;
  
  /// Additional data, if available
  final Map<String, dynamic>? data;
  
  /// Whether this error is recoverable and can be retried
  bool get isRecoverable => 
      type == ApiExceptionType.timeout ||
      type == ApiExceptionType.noConnection ||
      type == ApiExceptionType.serverError;
  
  /// Whether this error should trigger a re-authentication flow
  bool get requiresAuthentication =>
      type == ApiExceptionType.unauthorized ||
      type == ApiExceptionType.tokenExpired;
  
  /// Create a new ApiException
  ApiException({
    this.type = ApiExceptionType.other,
    required this.message,
    this.statusCode,
    this.response,
    this.stackTrace,
    this.code,
    this.data,
  });
  
  /// Factory constructor for network connectivity errors
  factory ApiException.noConnection() {
    return ApiException(
      type: ApiExceptionType.noConnection,
      message: 'No internet connection available. Please check your network settings.',
    );
  }
  
  /// Factory constructor for timeout errors
  factory ApiException.timeout() {
    return ApiException(
      type: ApiExceptionType.timeout,
      message: 'Request timed out. Please try again later.',
    );
  }
  
  /// Factory constructor for server errors
  factory ApiException.serverError(int? statusCode, {dynamic response}) {
    return ApiException(
      type: ApiExceptionType.serverError,
      message: 'Server error occurred. Please try again later.',
      statusCode: statusCode,
      response: response,
    );
  }
  
  /// Factory constructor for authentication errors
  factory ApiException.unauthorized({String? message}) {
    return ApiException(
      type: ApiExceptionType.unauthorized,
      message: message ?? 'You need to log in to access this resource.',
    );
  }

  /// Factory constructor for token expired errors
  factory ApiException.tokenExpired({String? message}) {
    return ApiException(
      type: ApiExceptionType.tokenExpired,
      message: message ?? 'Your session has expired. Please log in again.',
    );
  }
  
  /// User-friendly error message
  String get userFriendlyMessage {
    switch (type) {
      case ApiExceptionType.unauthorized:
        return 'Please log in to continue.';
      case ApiExceptionType.forbidden:
        return 'You don\'t have permission to access this resource.';
      case ApiExceptionType.timeout:
        return 'Request timed out. Please try again.';
      case ApiExceptionType.noConnection:
        return 'No internet connection. Please check your network settings.';
      case ApiExceptionType.serverError:
        return 'Our server is having issues. Please try again later.';
      case ApiExceptionType.tokenExpired:
        return 'Your session has expired. Please log in again.';
      case ApiExceptionType.invalidInput:
        return 'Invalid input. Please check your data and try again.';
      case ApiExceptionType.cancelled:
        return 'Request was cancelled.';
      default:
        return message;
    }
  }
  
  @override
  String toString() {
    String result = 'ApiException';
    if (statusCode != null) {
      result += ' [$statusCode]';
    }
    if (code != null && code!.isNotEmpty) {
      result += ' - $code';
    }
    result += ': $message';
    return result;
  }
} 