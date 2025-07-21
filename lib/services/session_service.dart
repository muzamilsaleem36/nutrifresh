import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:universal_html/html.dart' as html;

/// Service for managing session information throughout the app lifecycle
class SessionService {
  // Secure storage for persisting session ID
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Session ID key in storage
  static const String _sessionIdKey = 'nutrifresh_session_id';
  
  // Singleton instance
  static final SessionService _instance = SessionService._internal();
  
  // Current session ID
  String? _currentSessionId;
  
  // Factory constructor
  factory SessionService() {
    return _instance;
  }
  
  // Private constructor
  SessionService._internal();

  /// Gets the current session ID, generating a new one if necessary
  Future<String> getSessionId() async {
    if (_currentSessionId != null) {
      return _currentSessionId!;
    }
    
    if (kIsWeb) {
      // Special handling for web
      return _getWebSessionId();
    }
    
    try {
      // Try to load from secure storage
      final storedId = await _secureStorage.read(key: _sessionIdKey);
      
      if (storedId != null && storedId.isNotEmpty) {
        _currentSessionId = storedId;
        if (kDebugMode) {
          print('Loaded existing session ID: ${_maskSessionId(storedId)}');
        }
        return storedId;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error reading session ID from secure storage: $e');
      }
    }
    
    // Generate a new session ID if none was found
    return await _generateNewSessionId();
  }
  
  /// Gets or creates session ID for web platform using localStorage
  Future<String> _getWebSessionId() async {
    if (kIsWeb) {
      try {
        // In web, we use localStorage
        final storage = html.window.localStorage;
        final storedId = storage[_sessionIdKey];
        
        if (storedId != null && storedId.isNotEmpty) {
          _currentSessionId = storedId;
          if (kDebugMode) {
            print('Loaded existing web session ID: ${_maskSessionId(storedId)}');
          }
          return storedId;
        }
        
        // Generate new ID for web
        final uuid = const Uuid().v4();
        _currentSessionId = uuid;
        storage[_sessionIdKey] = uuid;
        
        if (kDebugMode) {
          print('Generated and saved new web session ID: ${_maskSessionId(uuid)}');
        }
        return uuid;
      } catch (e) {
        // Fallback if localStorage fails
        if (kDebugMode) {
          print('Error with web session ID: $e, falling back to memory-only session');
        }
        
        // Generate in-memory ID
        final uuid = const Uuid().v4();
        _currentSessionId = uuid;
        return uuid;
      }
    }
    
    // This should never be reached on web
    return await _generateNewSessionId();
  }
  
  /// Generates a new session ID and saves it to secure storage
  Future<String> _generateNewSessionId() async {
    final uuid = const Uuid().v4();
    _currentSessionId = uuid;
    
    if (kIsWeb) {
      try {
        // In web, we use localStorage
        html.window.localStorage[_sessionIdKey] = uuid;
        if (kDebugMode) {
          print('Generated and saved new web session ID: ${_maskSessionId(uuid)}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error saving web session ID: $e');
        }
      }
      return uuid;
    }
    
    try {
      await _secureStorage.write(key: _sessionIdKey, value: uuid);
      if (kDebugMode) {
        print('Generated and saved new session ID: ${_maskSessionId(uuid)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving session ID to secure storage: $e');
      }
    }
    
    return uuid;
  }
  
  /// Forces regeneration of a new session ID
  Future<String> regenerateSessionId() async {
    if (kIsWeb) {
      try {
        // Delete from localStorage on web
        html.window.localStorage.remove(_sessionIdKey);
      } catch (e) {
        if (kDebugMode) {
          print('Error deleting web session ID: $e');
        }
      }
    } else {
      try {
        // Delete existing session ID if any
        await _secureStorage.delete(key: _sessionIdKey);
      } catch (e) {
        if (kDebugMode) {
          print('Error deleting session ID: $e');
        }
      }
    }
    
    return await _generateNewSessionId();
  }
  
  /// Helper method to mask the session ID for logging purposes
  String _maskSessionId(String sessionId) {
    if (sessionId.length <= 8) {
      return '****${sessionId.substring(sessionId.length - 4)}';
    }
    return '${sessionId.substring(0, 4)}****${sessionId.substring(sessionId.length - 4)}';
  }

  /// Saves a provided session ID to secure storage
  Future<void> saveSessionId(String sessionId) async {
    if (sessionId.isEmpty) {
      if (kDebugMode) {
        print('Cannot save empty session ID');
      }
      return;
    }
    
    _currentSessionId = sessionId;
    
    if (kIsWeb) {
      try {
        // Save to localStorage on web
        html.window.localStorage[_sessionIdKey] = sessionId;
        if (kDebugMode) {
          print('Saved web session ID: ${_maskSessionId(sessionId)}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error saving web session ID: $e');
        }
      }
      return;
    }
    
    try {
      await _secureStorage.write(key: _sessionIdKey, value: sessionId);
      if (kDebugMode) {
        print('Saved session ID: ${_maskSessionId(sessionId)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving session ID to secure storage: $e');
      }
    }
  }
} 