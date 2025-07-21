import 'package:flutter/material.dart';
import 'package:nutrifresh/models/food_info.dart';

class FoodIcons {
  static const String _iconsPath = 'assets/icons/';
  
  // Map of food names to their respective icon files - improved with more variations
  static final Map<String, String> _foodIconMap = {
    // Fruits - common names and variants
    'apple': '${_iconsPath}apple.png',
    'red apple': '${_iconsPath}apple.png',
    'green apple': '${_iconsPath}apple.png',
    'banana': '${_iconsPath}banana.png',
    'ripe banana': '${_iconsPath}banana.png',
    'orange': '${_iconsPath}orange.png',
    'strawberry': '${_iconsPath}strawberry.png',
    'blueberry': '${_iconsPath}blueberry.png',
    'blueberries': '${_iconsPath}blueberry.png',
    'grape': '${_iconsPath}grape.png',
    'grapes': '${_iconsPath}grape.png',
    'watermelon': '${_iconsPath}watermelon.png',
    'pineapple': '${_iconsPath}pineapple.png',
    'mango': '${_iconsPath}mango.png',
    'kiwi': '${_iconsPath}kiwi.png',
    'kiwifruit': '${_iconsPath}kiwi.png',
    
    // Vegetables - common names and variants
    'tomato': '${_iconsPath}tomato.png',
    'red tomato': '${_iconsPath}tomato.png',
    'cherry tomato': '${_iconsPath}tomato.png',
    'cucumber': '${_iconsPath}cucumber.png',
    'carrot': '${_iconsPath}carrot.png',
    'carrots': '${_iconsPath}carrot.png',
    'broccoli': '${_iconsPath}broccoli.png',
    'spinach': '${_iconsPath}spinach.png',
    'lettuce': '${_iconsPath}lettuce.png',
    'iceberg lettuce': '${_iconsPath}lettuce.png',
    'romaine lettuce': '${_iconsPath}lettuce.png',
    'potato': '${_iconsPath}potato.png',
    'potatoes': '${_iconsPath}potato.png',
    'onion': '${_iconsPath}onion.png',
    'red onion': '${_iconsPath}onion.png',
    'white onion': '${_iconsPath}onion.png',
    'bell pepper': '${_iconsPath}bell_pepper.png',
    'pepper': '${_iconsPath}bell_pepper.png',
    'capsicum': '${_iconsPath}bell_pepper.png',
    'eggplant': '${_iconsPath}eggplant.png',
    'aubergine': '${_iconsPath}eggplant.png',
    'corn': '${_iconsPath}corn.png',
    'sweet corn': '${_iconsPath}corn.png',
    'mushroom': '${_iconsPath}mushroom.png',
    'mushrooms': '${_iconsPath}mushroom.png',
  };
  
  // Default icons for categories
  static final Map<String, String> _categoryIconMap = {
    'fruit': '${_iconsPath}fruit.png',
    'fruits': '${_iconsPath}fruit.png',
    'vegetable': '${_iconsPath}vegetable.png',
    'vegetables': '${_iconsPath}vegetable.png',
  };

  // Emoji icons to use as fallbacks - more complete collection
  static final Map<String, String> _foodEmojiMap = {
    // Fruits
    'apple': '🍎',
    'red apple': '🍎',
    'green apple': '🍏',
    'banana': '🍌',
    'orange': '🍊',
    'tangerine': '🍊',
    'lemon': '🍋',
    'strawberry': '🍓',
    'blueberry': '🫐',
    'blueberries': '🫐',
    'grape': '🍇',
    'grapes': '🍇',
    'watermelon': '🍉',
    'pineapple': '🍍',
    'mango': '🥭',
    'kiwi': '🥝',
    'kiwifruit': '🥝',
    'cherry': '🍒',
    'cherries': '🍒',
    'peach': '🍑',
    'pear': '🍐',
    'coconut': '🥥',
    
    // Vegetables
    'tomato': '🍅',
    'cucumber': '🥒',
    'carrot': '🥕',
    'broccoli': '🥦',
    'spinach': '🥬',
    'leafy green': '🥬',
    'lettuce': '🥬',
    'potato': '🥔',
    'onion': '🧅',
    'garlic': '🧄',
    'bell pepper': '🫑',
    'pepper': '🫑',
    'capsicum': '🫑',
    'eggplant': '🍆',
    'aubergine': '🍆',
    'corn': '🌽',
    'sweet corn': '🌽',
    'mushroom': '🍄',
    'mushrooms': '🍄',
    'avocado': '🥑',
    'olive': '🫒',
  };
  
  // Get icon path for a specific food
  static String getIconPath(String foodName, {String? category, String? customIconPath}) {
    // If custom icon path is provided, use it
    if (customIconPath != null && customIconPath.isNotEmpty) {
      return customIconPath;
    }
    
    // Convert food name to lowercase and remove spaces for matching
    final normalizedName = foodName.toLowerCase().trim();
    
    // Try to find specific food icon - first exact match
    if (_foodIconMap.containsKey(normalizedName)) {
      return _foodIconMap[normalizedName]!;
    }
    
    // Next try to find partial matches
    for (final entry in _foodIconMap.entries) {
      if (normalizedName.contains(entry.key) || 
          entry.key.contains(normalizedName)) {
        return entry.value;
      }
    }
    
    // Fall back to category icon if available
    if (category != null) {
      final normalizedCategory = category.toLowerCase().trim();
      if (_categoryIconMap.containsKey(normalizedCategory)) {
        return _categoryIconMap[normalizedCategory]!;
      }
      
      // Check for partial category matches
      for (final entry in _categoryIconMap.entries) {
        if (normalizedCategory.contains(entry.key) || 
            entry.key.contains(normalizedCategory)) {
          return entry.value;
        }
      }
    }
    
    // Default icon if no match
    return '${_iconsPath}food_default.png';
  }
  
  // Widget to display food icon with fallback
  static Widget getFoodIconWidget({
    required String foodName,
    String? category,
    String? customIconPath,
    double size = 40,
    BoxFit fit = BoxFit.contain,
  }) {
    return Image.asset(
      getIconPath(foodName, category: category, customIconPath: customIconPath),
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to emoji if image fails to load
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(size / 4),
          ),
          child: Text(
            _getFoodEmoji(foodName, category),
            style: TextStyle(fontSize: size * 0.7),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
  
  // Get icon widget from FoodInfo object
  static Widget getIconFromFoodInfo(
    FoodInfo foodInfo, {
    double size = 40,
    BoxFit fit = BoxFit.contain,
  }) {
    return getFoodIconWidget(
      foodName: foodInfo.foodName,
      category: foodInfo.category,
      customIconPath: foodInfo.iconPath,
      size: size,
      fit: fit,
    );
  }
  
  // Get the appropriate emoji for a food
  static String _getFoodEmoji(String foodName, String? category) {
    // Convert food name to lowercase and remove spaces for matching
    final normalizedName = foodName.toLowerCase().trim();
    
    // Try to find specific food emoji - exact match
    if (_foodEmojiMap.containsKey(normalizedName)) {
      return _foodEmojiMap[normalizedName]!;
    }
    
    // Try to find partial match
    for (final entry in _foodEmojiMap.entries) {
      if (normalizedName.contains(entry.key) || 
          entry.key.contains(normalizedName)) {
        return entry.value;
      }
    }
    
    // Fall back to category emoji
    if (category?.toLowerCase() == 'fruit' || category?.toLowerCase() == 'fruits') {
      return '🍎';
    } else if (category?.toLowerCase() == 'vegetable' || category?.toLowerCase() == 'vegetables') {
      return '🥦';
    } else {
      return '🍽️';
    }
  }
} 