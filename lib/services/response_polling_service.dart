import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:nutrifresh/models/food_info.dart';
import 'package:nutrifresh/services/food_analysis_service.dart';
import 'package:nutrifresh/config/app_config.dart';

/// Service for polling the server for responses to pending requests
class ResponsePollingService {
  // Logger for the service
  final _logger = Logger('ResponsePollingService');
  
  // Food analysis service for making API calls
  FoodAnalysisService _foodAnalysisService;
  
  // Map of active polling timers by session ID
  final Map<String, Timer> _pollingTimers = {};
  
  // Map of response callbacks by session ID
  final Map<String, void Function(FoodInfo)> _responseCallbacks = {};
  
  // Polling interval in milliseconds
  int _pollingInterval;
  
  // Maximum number of polling attempts
  int _maxAttempts;
  
  // Record of when each polling session started
  final Map<String, DateTime> _pollStartTimes = {};
  
  // Track consecutive errors for exponential backoff
  final Map<String, int> _consecutiveErrors = {};
  
  // Maximum backoff in milliseconds (30 seconds)
  static const int _maxBackoff = 30000;
  
  // Initial backoff in milliseconds (2 seconds)
  static const int _initialBackoff = 2000;

  // Singleton instance
  static final ResponsePollingService _instance = ResponsePollingService._internal();
  
  // Factory constructor
  factory ResponsePollingService({
    FoodAnalysisService? foodAnalysisService,
    int pollingInterval = 2000,
    int maxAttempts = 30,
  }) {
    _instance._foodAnalysisService = foodAnalysisService ?? FoodAnalysisService();
    _instance._pollingInterval = pollingInterval;
    _instance._maxAttempts = maxAttempts;
    return _instance;
  }
  
  // Private constructor
  ResponsePollingService._internal() 
      : _foodAnalysisService = FoodAnalysisService(),
        _pollingInterval = 2000,
        _maxAttempts = 30;
  
  /// Start polling for a response for the given session ID
  /// 
  /// [sessionId] - The session ID to poll for
  /// [onResponse] - Callback function to call when a response is received
  /// [onTimeout] - Callback function to call when polling times out
  void startPolling(
    String sessionId, {
    required void Function(FoodInfo) onResponse,
    void Function()? onTimeout,
    bool useExponentialBackoff = true,
  }) {
    if (_pollingTimers.containsKey(sessionId)) {
      _logger.warning('Already polling for session: $sessionId');
      return;
    }
    
    _logger.info('Starting polling for session: $sessionId');
    _logger.info('Server URL from AppConfig: ${AppConfig().apiBaseUrl}');
    
    // Store the callback
    _responseCallbacks[sessionId] = onResponse;
    
    // Record the start time
    _pollStartTimes[sessionId] = DateTime.now();
    
    // Reset consecutive errors
    _consecutiveErrors[sessionId] = 0;
    
    // Counter for polling attempts
    int attempts = 0;
    
    // Create and start a periodic timer
    _pollingTimers[sessionId] = Timer.periodic(
      Duration(milliseconds: _pollingInterval),
      (timer) async {
        attempts++;
        
        // Log the polling attempt
        final elapsed = DateTime.now().difference(_pollStartTimes[sessionId]!);
        _logger.info('Polling attempt $attempts for session: $sessionId (elapsed: ${elapsed.inSeconds}s)');
        
        // Check if we've reached the maximum number of attempts
        if (attempts >= _maxAttempts) {
          _logger.warning('Polling timed out for session: $sessionId after $attempts attempts');
          stopPolling(sessionId);
          
          // Call the timeout callback if provided
          if (onTimeout != null) {
            onTimeout();
          }
          return;
        }
        
        try {
          // Poll for a response
          final response = await _foodAnalysisService.pollForResponse(sessionId);
          
          // If we got a response, call the callback and stop polling
          if (response != null) {
            _logger.info('Received response for session: $sessionId');
            _logger.info('Response food name: ${response.foodName}, category: ${response.category}');
            
            stopPolling(sessionId);
            
            // Call the callback
            if (_responseCallbacks.containsKey(sessionId)) {
              _responseCallbacks[sessionId]!(response);
            }
          } else {
            // Log elapsed time for debugging
            _logger.info('No response yet for session: $sessionId (elapsed: ${elapsed.inSeconds}s, attempt: $attempts/${_maxAttempts})');
            
            // Reset consecutive errors on successful poll
            _consecutiveErrors[sessionId] = 0;
          }
        } catch (e) {
          // Increment consecutive errors
          _consecutiveErrors[sessionId] = (_consecutiveErrors[sessionId] ?? 0) + 1;
          
          _logger.warning('Error polling for response: $e');
          _logger.warning('Consecutive errors for session $sessionId: ${_consecutiveErrors[sessionId]}');
          
          // Apply exponential backoff if enabled and errors are consecutive
          if (useExponentialBackoff && _consecutiveErrors[sessionId]! > 1) {
            // Calculate backoff time with exponential increase
            final backoff = _calculateBackoff(_consecutiveErrors[sessionId]!);
            
            _logger.info('Applying exponential backoff of ${backoff}ms for session: $sessionId');
            
            // Cancel the current timer
            timer.cancel();
            
            // Create a new timer with the backoff delay
            Future.delayed(Duration(milliseconds: backoff), () {
              // Only restart if not manually stopped
              if (_responseCallbacks.containsKey(sessionId)) {
                _pollingTimers[sessionId] = Timer.periodic(
                  Duration(milliseconds: _pollingInterval),
                  (timer) => _pollForResponse(timer, sessionId, attempts, onTimeout),
                );
              }
            });
            
            return;
          }
        }
      },
    );
  }
  
  /// Helper method to poll for response (used for restarts after backoff)
  Future<void> _pollForResponse(
    Timer timer,
    String sessionId,
    int attempts,
    void Function()? onTimeout,
  ) async {
    attempts++;
    
    // Check if we've reached the maximum number of attempts
    if (attempts >= _maxAttempts) {
      _logger.warning('Polling timed out for session: $sessionId after $attempts attempts');
      stopPolling(sessionId);
      
      // Call the timeout callback if provided
      if (onTimeout != null) {
        onTimeout();
      }
      return;
    }
    
    try {
      // Poll for a response
      final response = await _foodAnalysisService.pollForResponse(sessionId);
      
      // If we got a response, call the callback and stop polling
      if (response != null) {
        _logger.info('Received response for session: $sessionId');
        stopPolling(sessionId);
        
        // Call the callback
        if (_responseCallbacks.containsKey(sessionId)) {
          _responseCallbacks[sessionId]!(response);
        }
      } else {
        // Log elapsed time for debugging
        final elapsed = DateTime.now().difference(_pollStartTimes[sessionId]!);
        _logger.info('No response yet for session: $sessionId (elapsed: ${elapsed.inSeconds}s, attempt: $attempts/${_maxAttempts})');
      }
    } catch (e) {
      _logger.warning('Error polling for response: $e');
    }
  }
  
  /// Calculate backoff time with exponential increase
  int _calculateBackoff(int consecutiveErrors) {
    // Min value of 1 to avoid 0
    final errorFactor = consecutiveErrors.clamp(1, 10);
    
    // Exponential backoff: initial * 2^(errors-1)
    int backoff = _initialBackoff * (1 << (errorFactor - 1));
    
    // Limit to max backoff
    return backoff.clamp(0, _maxBackoff);
  }
  
  /// Stop polling for a response for the given session ID
  void stopPolling(String sessionId) {
    if (_pollingTimers.containsKey(sessionId)) {
      _logger.info('Stopping polling for session: $sessionId');
      _pollingTimers[sessionId]!.cancel();
      _pollingTimers.remove(sessionId);
      _responseCallbacks.remove(sessionId);
      _pollStartTimes.remove(sessionId);
      _consecutiveErrors.remove(sessionId);
    }
  }
  
  /// Stop all active polling timers
  void stopAllPolling() {
    _logger.info('Stopping all polling');
    for (final timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();
    _responseCallbacks.clear();
    _pollStartTimes.clear();
    _consecutiveErrors.clear();
  }
  
  /// Dispose the service
  void dispose() {
    stopAllPolling();
  }
} 