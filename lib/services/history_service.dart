import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nutrifresh/models/food_info.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Service for managing search history information using SQLite
class HistoryService {
  // Database name and version
  static const String _dbName = 'nutrifresh.db';
  static const int _dbVersion = 1;
  
  // Table name and columns
  static const String _tableName = 'search_history';
  static const String colId = 'id';
  static const String colData = 'data';
  static const String colTimestamp = 'timestamp';
  static const String colFoodName = 'food_name';
  static const String colCategory = 'category';
  static const String colFreshness = 'freshness';
  static const String colSessionId = 'session_id';
  
  // Maximum number of history items to store
  static const int _maxHistoryItems = 50;
  
  // Singleton instance
  static final HistoryService _instance = HistoryService._internal();
  
  // Database instance
  Database? _database;
  
  // Factory constructor
  factory HistoryService() {
    return _instance;
  }
  
  // Private constructor
  HistoryService._internal();
  
  /// Initialize the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _initDatabase();
    return _database!;
  }
  
  /// Initialize the database
  Future<Database> _initDatabase() async {
    try {
      // Get the database path
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _dbName);
      
      if (kDebugMode) {
        print('Initializing database at $path');
      }
      
      // Open the database
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing database: $e');
      }
      rethrow;
    }
  }
  
  /// Create the database tables
  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE $_tableName (
          $colId INTEGER PRIMARY KEY AUTOINCREMENT,
          $colData TEXT NOT NULL,
          $colTimestamp TEXT NOT NULL,
          $colFoodName TEXT NOT NULL,
          $colCategory TEXT NOT NULL,
          $colFreshness INTEGER NOT NULL,
          $colSessionId TEXT
        )
      ''');
      
      if (kDebugMode) {
        print('Created search history table');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating database tables: $e');
      }
    }
  }
  
  /// Save a food analysis result to history
  Future<bool> saveFoodInfoToHistory(FoodInfo foodInfo) async {
    try {
      final db = await database;
      
      // Add timestamp if not present
      final foodInfoWithTimestamp = foodInfo.timestamp == null
          ? FoodInfo(
              foodName: foodInfo.foodName,
              category: foodInfo.category,
              freshness: foodInfo.freshness,
              nutrition: foodInfo.nutrition,
              storageRecommendations: foodInfo.storageRecommendations,
              healthRiskFactors: foodInfo.healthRiskFactors,
              sessionId: foodInfo.sessionId,
              imageUrl: foodInfo.imageUrl,
              iconPath: foodInfo.iconPath,
              timestamp: DateTime.now().toIso8601String(),
            )
          : foodInfo;
      
      // Convert to JSON
      final jsonData = jsonEncode(foodInfoWithTimestamp.toJson());
      
      // Insert into database
      await db.insert(
        _tableName,
        {
          colData: jsonData,
          colTimestamp: foodInfoWithTimestamp.timestamp ?? DateTime.now().toIso8601String(),
          colFoodName: foodInfoWithTimestamp.foodName,
          colCategory: foodInfoWithTimestamp.category,
          colFreshness: foodInfoWithTimestamp.freshness.percentage,
          colSessionId: foodInfoWithTimestamp.sessionId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Clean up old entries if there are too many
      await _cleanupOldEntries();
      
      if (kDebugMode) {
        print('Saved food info to history with ID: ${foodInfoWithTimestamp.sessionId}');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving food info to history: $e');
      }
      return false;
    }
  }
  
  /// Clean up old entries if there are more than the maximum allowed
  Future<void> _cleanupOldEntries() async {
    try {
      final db = await database;
      
      // Get count of entries
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      
      if (count > _maxHistoryItems) {
        // Delete oldest entries
        final deleteCount = count - _maxHistoryItems;
        
        await db.rawDelete('''
          DELETE FROM $_tableName
          WHERE $colId IN (
            SELECT $colId FROM $_tableName
            ORDER BY $colTimestamp ASC
            LIMIT $deleteCount
          )
        ''');
        
        if (kDebugMode) {
          print('Deleted $deleteCount old history entries');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up old entries: $e');
      }
    }
  }
  
  /// Get the search history
  Future<List<FoodInfo>> getSearchHistory({int limit = 10, int offset = 0}) async {
    try {
      final db = await database;
      
      // Query the database
      final List<Map<String, dynamic>> results = await db.query(
        _tableName,
        columns: [colData],
        orderBy: '$colTimestamp DESC',
        limit: limit,
        offset: offset,
      );
      
      if (results.isEmpty) {
        return [];
      }
      
      // Convert to FoodInfo objects
      return results.map((row) {
        final jsonData = row[colData] as String;
        return FoodInfo.fromJson(jsonDecode(jsonData));
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting search history: $e');
      }
      return [];
    }
  }
  
  /// Clear all search history
  Future<bool> clearSearchHistory() async {
    try {
      final db = await database;
      
      // Delete all records
      await db.delete(_tableName);
      
      if (kDebugMode) {
        print('Cleared search history');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing search history: $e');
      }
      return false;
    }
  }
  
  /// Delete a specific item from history by its index
  Future<bool> deleteHistoryItem(int index) async {
    try {
      final db = await database;
      
      // Get the items
      final List<Map<String, dynamic>> results = await db.query(
        _tableName,
        columns: [colId],
        orderBy: '$colTimestamp DESC',
      );
      
      if (index < 0 || index >= results.length) {
        return false;
      }
      
      // Get the ID of the item to delete
      final itemId = results[index][colId] as int;
      
      // Delete the item
      await db.delete(
        _tableName,
        where: '$colId = ?',
        whereArgs: [itemId],
      );
      
      if (kDebugMode) {
        print('Deleted history item at index $index (ID: $itemId)');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting history item: $e');
      }
      return false;
    }
  }
  
  /// Search history by food name
  Future<List<FoodInfo>> searchHistory(String query) async {
    try {
      final db = await database;
      
      // Query the database
      final List<Map<String, dynamic>> results = await db.query(
        _tableName,
        columns: [colData],
        where: '$colFoodName LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: '$colTimestamp DESC',
      );
      
      if (results.isEmpty) {
        return [];
      }
      
      // Convert to FoodInfo objects
      return results.map((row) {
        final jsonData = row[colData] as String;
        return FoodInfo.fromJson(jsonDecode(jsonData));
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching history: $e');
      }
      return [];
    }
  }
} 