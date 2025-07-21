import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart' show debugPrint;
import 'package:nutrifresh/services/api/api_client.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Environment types for the app
enum AppEnvironment {
  /// Local development environment
  development,
  
  /// Staging environment for QA testing
  staging,
  
  /// Production environment
  production,
}

/// App-wide configuration class
class AppConfig {
  // Logger for config
  final _logger = Logger('AppConfig');
  
  /// Singleton instance
  static final AppConfig _instance = AppConfig._internal();
  
  /// Factory constructor
  factory AppConfig() => _instance;
  
  /// Private constructor
  AppConfig._internal();
  
  /// Current environment
  AppEnvironment _apiEnvironment = AppEnvironment.development;
  
  /// Get current environment
  AppEnvironment get apiEnvironment => _apiEnvironment;
  
  // Custom server settings
  String? _customServerIP;
  String? _customServerPort;
  
  /// Reload API settings from shared preferences
  Future<void> reloadApiSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customServerIP = prefs.getString('server_ip');
      _customServerPort = prefs.getString('server_port');
      
      // Always log these details, even in release mode
      print('NutriFresh reloaded server settings: IP=$_customServerIP, Port=$_customServerPort');
      
      // If custom settings are available, log the full URL that will be used
      if (_customServerIP != null && _customServerPort != null) {
        final protocol = _customServerIP == 'localhost' ? 'http' : 'http';
        final customUrl = '$protocol://${_customServerIP}:${_customServerPort}';
        print('NutriFresh using custom server URL: $customUrl');
      }
      
      _logger.info('Reloaded API settings: IP=$_customServerIP, Port=$_customServerPort');
    } catch (e) {
      print('NutriFresh error loading API settings: $e');
      _logger.warning('Error loading API settings: $e');
      _customServerIP = null;
      _customServerPort = null;
    }
  }
  
  /// Get platform-appropriate local server URL
  String get _localServerUrl {
    // Try to load custom settings if not already loaded
    if (_customServerIP == null || _customServerPort == null) {
      SharedPreferences.getInstance().then((prefs) {
        _customServerIP = prefs.getString('server_ip');
        _customServerPort = prefs.getString('server_port');
      });
    }
    
    // Use custom server settings if available
    if (_customServerIP != null && _customServerPort != null) {
      final protocol = _customServerIP == 'localhost' ? 'http' : 'http';
      return '$protocol://${_customServerIP}:${_customServerPort}';
    }
    
    // Otherwise use default settings
    if (kIsWeb) {
      // For web, use the current hostname
      return 'http://localhost:3001';
    } else if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine
      return 'http://10.0.2.2:3001';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost
      return 'http://localhost:3001';
    } else if (Platform.isWindows) {
      // Windows uses localhost
      return 'http://127.0.0.1:3001';
    } else {
      // Other platforms use localhost
      return 'http://localhost:3001';
    }
  }
  
  /// API base URLs for each environment
  Map<AppEnvironment, String> get _apiBaseUrls {
    return {
      AppEnvironment.development: _localServerUrl,
      AppEnvironment.staging: 'https://staging.nutrifresh-api.example.com/api/v1',
      AppEnvironment.production: 'https://api.nutrifresh.example.com/api/v1',
    };
  }
  
  /// Get the API base URL for current environment
  String get apiBaseUrl {
    // Always prioritize custom server settings if available
    if (_customServerIP != null && _customServerPort != null) {
      final protocol = _customServerIP == 'localhost' ? 'http' : 'http';
      final customUrl = '$protocol://${_customServerIP}:${_customServerPort}';
      _logger.info('Using custom server URL: $customUrl');
      return customUrl;
    }
    
    // Otherwise use environment-based URL
    try {
      return _apiBaseUrls[_apiEnvironment] ?? _localServerUrl;
    } catch (e) {
      _logger.warning('Error getting API base URL: $e');
      // Fallback to local development URL
      return _localServerUrl;
    }
  }
  
  /// Socket timeout in seconds
  int _socketTimeout = 30;
  
  /// Get socket timeout
  int get socketTimeout => _socketTimeout;
  
  /// Initialize app configuration
  void initialize() async {
    _initLogging();
    _initApiEnvironment();
    await reloadApiSettings();
  }
  
  /// Initialize logging
  void _initLogging() {
    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen((record) {
      if (kDebugMode) {
        debugPrint('${record.level.name}: ${record.time}: ${record.message}');
      }
    });
  }
  
  /// Initialize API environment based on build mode
  void _initApiEnvironment() {
    if (kDebugMode) {
      _apiEnvironment = AppEnvironment.development;
      _socketTimeout = 60; // Longer timeout for development
    } else {
      _apiEnvironment = AppEnvironment.production;
      _socketTimeout = 30;
    }
    
    // Always log these details, even in release mode
    print('NutriFresh API Environment: $_apiEnvironment');
    print('NutriFresh API Base URL: $apiBaseUrl');
    print('NutriFresh Device platform: ${kIsWeb ? "Web" : Platform.operatingSystem}');
    
    _logger.info('API Environment: $_apiEnvironment');
    _logger.info('API Base URL: $apiBaseUrl');
    _logger.info('Device platform: ${kIsWeb ? "Web" : Platform.operatingSystem}');
  }
}