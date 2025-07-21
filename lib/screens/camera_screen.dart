import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:nutrifresh/models/food_info.dart';
import 'package:nutrifresh/screens/results_screen.dart';
import 'package:nutrifresh/screens/settings_screen.dart';
import 'package:nutrifresh/services/health_risk_calculator.dart';
import 'package:nutrifresh/services/history_service.dart';
import 'package:nutrifresh/services/session_service.dart';
import 'package:nutrifresh/services/api/upload_service.dart';
import 'package:nutrifresh/services/response_polling_service.dart';
import 'package:nutrifresh/utils/app_theme.dart';
import 'dart:ui';
import 'dart:convert';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  String _cameraErrorMessage = '';
  bool _isFlashOn = false; // Flash state
  
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  bool _hasHistory = false;
  
  // Camera controller
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  
  // Services
  final SessionService _sessionService = SessionService();
  final UploadService _uploadService = UploadService();
  final HistoryService _historyService = HistoryService();
  final HealthRiskCalculator _healthRiskCalculator = HealthRiskCalculator();
  
  // Current session ID
  String? _sessionId;
  
  // Camera retry mechanism
  int _cameraInitRetries = 0;
  static const int maxCameraRetries = 3;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.repeat(reverse: true);
    
    // Initialize session and check history with proper error handling
    _initializeSession().then((_) {
      if (kDebugMode) {
        print('Session initialized with ID: $_sessionId');
      }
      _checkHistory();
    }).catchError((e) {
      if (kDebugMode) {
        print('Error initializing session: $e');
      }
      // Use a fallback session ID if there was an error
      _sessionId = 'fallback-${DateTime.now().millisecondsSinceEpoch}';
      _checkHistory();
    });
    
    // Initialize camera if not on web platform
    if (!kIsWeb) {
      _initializeCamera();
    } else {
      setState(() {
        _cameraErrorMessage = 'Camera is not supported on web platform';
      });
    }
  }
  
  Future<void> _initializeCamera() async {
    try {
      if (kDebugMode) {
        print('Initializing camera (attempt ${_cameraInitRetries + 1}/$maxCameraRetries)');
      }
      
      // Get available cameras
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _isCameraInitialized = false;
          _cameraErrorMessage = 'No cameras available on this device';
        });
        return;
      }
      
      // Use the first (back) camera
      final firstCamera = _cameras!.first;
      
      // Dispose of existing controller if it exists
      await _cameraController?.dispose();
      
      // Initialize the controller
      _cameraController = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      // Initialize camera with timeout and error handling
      try {
        await _cameraController!.initialize().timeout(
          const Duration(seconds: 15), // Increased timeout
          onTimeout: () {
            throw TimeoutException('Camera initialization timed out after 15 seconds');
          },
        );
        
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _cameraErrorMessage = '';
            _cameraInitRetries = 0; // Reset retry counter on success
          });
          
          if (kDebugMode) {
            print('Camera initialized successfully');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Camera initialization error: $e');
        }
        
        // Retry logic
        if (_cameraInitRetries < maxCameraRetries) {
          _cameraInitRetries++;
          if (kDebugMode) {
            print('Retrying camera initialization in 2 seconds...');
          }
          
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            _initializeCamera();
          }
          return;
        }
        
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
            _cameraErrorMessage = 'Failed to initialize camera after $maxCameraRetries attempts: ${e.toString()}';
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Camera access error: $e');
      }
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _cameraErrorMessage = 'Error accessing camera: ${e.toString()}';
        });
      }
    }
  }
  
  // Toggle flashlight
  Future<void> _toggleFlash() async {
    if (!_isCameraInitialized || _cameraController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not available')),
      );
      return;
    }
    
    try {
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newFlashMode);
      
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      
      if (kDebugMode) {
        print('Flash toggled: ${_isFlashOn ? 'ON' : 'OFF'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling flash: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling flashlight: $e')),
      );
    }
  }
  
  Future<void> _takePicture() async {
    if (_isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing previous image...')),
      );
      return;
    }
    
    if (!_isCameraInitialized || _cameraController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not initialized yet')),
      );
      return;
    }
    
    // Check if camera is still valid
    if (!_cameraController!.value.isInitialized) {
      if (kDebugMode) {
        print('Camera controller is not initialized, attempting to reinitialize...');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera connection lost, reinitializing...')),
      );
      
      _initializeCamera();
      return;
    }
    
    _animateButtonPress();
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Show processing bottom sheet
      _showProcessingBottomSheet();
      
      // Take the picture with retry mechanism
      XFile? photo;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          if (kDebugMode) {
            print('Taking picture (attempt ${retryCount + 1}/$maxRetries)');
          }
          
          // Set flash mode to auto for taking picture if flash is on
          if (_isFlashOn) {
            await _cameraController!.setFlashMode(FlashMode.auto);
          }
          
          photo = await _cameraController!.takePicture().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Camera takePicture timed out');
            },
          );
          
          // Restore torch mode if it was on
          if (_isFlashOn) {
            await _cameraController!.setFlashMode(FlashMode.torch);
          }
          
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          if (kDebugMode) {
            print('Take picture attempt $retryCount failed: $e');
          }
          
          if (retryCount >= maxRetries) {
            rethrow; // Re-throw after max retries
          }
          
          // Brief delay before retry
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Check if camera is still valid before retry
          if (!_cameraController!.value.isInitialized) {
            throw Exception('Camera connection lost during capture');
          }
        }
      }
      
      if (photo == null) {
        throw Exception('Failed to capture image after $maxRetries attempts');
      }
      
      // Process the file
      final imageFile = File(photo.path);
      await _processRealImage(imageFile);
    } catch (e) {
      if (kDebugMode) {
        print('Error taking picture: $e');
      }
      
      // Close the bottom sheet
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
      
      // Show error with recovery options
      if (mounted) {
        String errorMessage = 'Error taking picture: $e';
        
        // Provide specific error messages for common issues
        if (e.toString().contains('channel-error') || e.toString().contains('connection')) {
          errorMessage = 'Camera connection lost. Try again or restart the app.';
          
          // Attempt to reinitialize camera
          _initializeCamera();
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Camera operation timed out. Please try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                if (_isCameraInitialized) {
                  _takePicture();
                } else {
                  _initializeCamera();
                }
              },
            ),
          ),
        );
        
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    
    // Turn off flash before disposing
    if (_isFlashOn && _cameraController != null) {
      _cameraController!.setFlashMode(FlashMode.off).catchError((e) {
        if (kDebugMode) {
          print('Error turning off flash during dispose: $e');
        }
      });
    }
    
    _cameraController?.dispose();
    super.dispose();
  }

  void _pickFromGallery() async {
    if (_isProcessing) return;

    _animateButtonPress();

    setState(() {
      _isProcessing = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
      
      if (photo != null) {
        // Show processing bottom sheet
        _showProcessingBottomSheet();
        
        // For web, we need to handle file operations differently to avoid namespace issues
        if (kIsWeb) {
          try {
            // Read the bytes from XFile directly and process them
            final bytes = await photo.readAsBytes();
            final String base64Image = base64Encode(bytes);
            
            // Process the base64 image directly
            final result = await _uploadService.uploadBase64Image(base64Image, _sessionId ?? 'new-session');
            
            // Calculate health risk factors
            final healthRisks = _healthRiskCalculator.calculateHealthRisks(result.nutrition);
            
            // Create a new FoodInfo object with calculated health risks
            final updatedResult = FoodInfo(
              foodName: result.foodName,
              category: result.category,
              freshness: result.freshness,
              nutrition: result.nutrition,
              storageRecommendations: result.storageRecommendations,
              healthRiskFactors: healthRisks,
              sessionId: _sessionId,
              imageUrl: result.imageUrl,
              iconPath: result.iconPath,
              timestamp: DateTime.now().toIso8601String(),
            );
            
            // Save to history and navigate to results
            await _handleResultsAndNavigation(updatedResult);
          } catch (webError) {
            if (kDebugMode) {
              print('Web-specific error handling the image: $webError');
            }
            
            // Close the bottom sheet
            if (mounted) Navigator.pop(context);
            
            // Show the error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error processing image: $webError')),
            );
            
            setState(() {
              _isProcessing = false;
            });
          }
        } else {
          // For mobile, process the image with File
          _processRealImage(File(photo.path));
        }
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking from gallery: $e')),
      );
      setState(() {
        _isProcessing = false;
      });
      }
    }
  }
  
  void _animateButtonPress() {
    ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.9).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
        ),
      )
    );
  }

  void _showProcessingBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      isScrollControlled: true,
      builder: (context) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          height: 250,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(40),
              topRight: Radius.circular(40),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Custom leaf loader with improved animation
              SizedBox(
                width: 80,
                height: 80,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glowing circle
                        Container(
                          width: 80 * (0.8 + _animationController.value * 0.2),
                          height: 80 * (0.8 + _animationController.value * 0.2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 10 * _animationController.value,
                                spreadRadius: 2 * _animationController.value,
                              )
                            ]
                          ),
                        ),
                        
                        // Inner circle
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                        ),
                        
                        // Rotating leaf
                        Transform.rotate(
                          angle: _animationController.value * 2 * 3.14159,
                          child: Icon(
                            Icons.eco,
                            size: 40,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Processing text with gradient
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    Color(0xFF4B9460),
                  ],
                ).createShader(bounds),
                child: const Text(
                  'Analyzing your image... hang tight 🍃',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Progress indicator with custom animation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Progress bar background
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    
                    // Animated progress
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return FractionallySizedBox(
                          widthFactor: _animationController.value,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor.withOpacity(0.7),
                                  AppTheme.primaryColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.4),
                                  blurRadius: 6,
                                  spreadRadius: -1,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processRealImage(File imageFile) async {
    try {
      // Ensure we have a session ID
      if (_sessionId == null) {
        _sessionId = await _sessionService.getSessionId();
      }
      
      // Upload the image to the server
      FoodInfo result;
      
      if (kIsWeb) {
        try {
          // For web, convert the image to base64
          final List<int> imageBytes = await imageFile.readAsBytes();
          final String base64Image = base64Encode(imageBytes);
          
          // Upload the base64 image
          result = await _uploadService.uploadBase64Image(base64Image, _sessionId!);
          
          // If the response has a "status" field with value "pending", start polling
          if (result.sessionId != null && 
              result.status != null && 
              result.status!.toLowerCase() == "pending") {
            
            // Create polling service
            final pollingService = ResponsePollingService();
            
            // Start polling for the response
            pollingService.startPolling(
              result.sessionId!,
              onResponse: (FoodInfo polledResult) {
                // Calculate health risk factors
                final healthRisks = _healthRiskCalculator.calculateHealthRisks(polledResult.nutrition);
                
                // Create a new FoodInfo object with calculated health risks
                final updatedResult = FoodInfo(
                  foodName: polledResult.foodName,
                  category: polledResult.category,
                  freshness: polledResult.freshness,
                  nutrition: polledResult.nutrition,
                  storageRecommendations: polledResult.storageRecommendations,
                  healthRiskFactors: healthRisks,
                  sessionId: polledResult.sessionId,
                  imageUrl: polledResult.imageUrl,
                  iconPath: polledResult.iconPath,
                  timestamp: DateTime.now().toIso8601String(),
                );
                
                // Handle results and navigation
                _handleResultsAndNavigation(updatedResult);
              },
              onTimeout: () {
                // If polling times out, use fallback data
                final fallbackResult = _createFallbackFoodInfo(_sessionId);
                _handleResultsAndNavigation(fallbackResult);
              },
            );
            
            // Return early - the polling service will handle the rest
            return;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error reading web file: $e');
          }
          // Use fallback data if there's an error with the file
          result = _createFallbackFoodInfo(_sessionId);
        }
      } else {
        // For mobile/desktop, upload the file directly
        result = await _uploadService.uploadImage(imageFile, _sessionId!);
        
        // If the response has a "status" field with value "pending", start polling
        if (result.sessionId != null && 
            result.status != null && 
            result.status!.toLowerCase() == "pending") {
          
          // Create polling service
          final pollingService = ResponsePollingService();
          
          // Start polling for the response
          pollingService.startPolling(
            result.sessionId!,
            onResponse: (FoodInfo polledResult) {
              // Calculate health risk factors
              final healthRisks = _healthRiskCalculator.calculateHealthRisks(polledResult.nutrition);
              
              // Create a new FoodInfo object with calculated health risks
              final updatedResult = FoodInfo(
                foodName: polledResult.foodName,
                category: polledResult.category,
                freshness: polledResult.freshness,
                nutrition: polledResult.nutrition,
                storageRecommendations: polledResult.storageRecommendations,
                healthRiskFactors: healthRisks,
                sessionId: polledResult.sessionId,
                imageUrl: polledResult.imageUrl,
                iconPath: polledResult.iconPath,
                timestamp: DateTime.now().toIso8601String(),
              );
              
              // Handle results and navigation
              _handleResultsAndNavigation(updatedResult);
            },
            onTimeout: () {
              // If polling times out, use fallback data
              final fallbackResult = _createFallbackFoodInfo(result.sessionId);
              _handleResultsAndNavigation(fallbackResult);
            },
          );
          
          // Return early - the polling service will handle the rest
          return;
        }
      }
      
      // Calculate health risk factors
      final healthRisks = _healthRiskCalculator.calculateHealthRisks(result.nutrition);
      
      // Create a new FoodInfo object with calculated health risks
      final updatedResult = FoodInfo(
        foodName: result.foodName,
        category: result.category,
        freshness: result.freshness,
        nutrition: result.nutrition,
        storageRecommendations: result.storageRecommendations,
        healthRiskFactors: healthRisks,
        sessionId: _sessionId,
        imageUrl: result.imageUrl,
        iconPath: result.iconPath,
        timestamp: DateTime.now().toIso8601String(),
      );
      
      // Use the helper method to handle history saving and navigation
      await _handleResultsAndNavigation(updatedResult);
    } catch (e) {
      if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
        
        // Reset processing state
        setState(() {
          _isProcessing = false;
        });
        
        // Close processing bottom sheet if open
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  // Create fallback food info for when server response is unavailable
  FoodInfo _createFallbackFoodInfo([String? sessionId]) {
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
      sessionId: sessionId ?? 'fallback-${DateTime.now().millisecondsSinceEpoch}',
      imageUrl: null,
      iconPath: null,
      timestamp: DateTime.now().toIso8601String(),
    );
  }

  void _showHistory() async {
    if (_isProcessing) return;
    
    try {
      final historyItems = await _historyService.getSearchHistory();
      
      if (historyItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No history available yet. Analyze some food first!')),
        );
        return;
      }
      
      // Show history bottom sheet with options to view or clear
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Recent Searches',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                Divider(),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: historyItems.length,
                    itemBuilder: (context, index) {
                      final item = historyItems[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              item.iconPath != null ? '🍎' : '🍎',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        title: Text(item.foodName),
                        subtitle: Text(
                          'Freshness: ${item.freshness.percentage}% - ${_formatDateTime(item.timestamp)}',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context); // Close sheet
                          // Navigate to results screen for this item
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ResultsScreen(foodInfo: item),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Divider(),
                // Button to clear history
                TextButton(
                  onPressed: () async {
                    await _historyService.clearSearchHistory();
                    Navigator.pop(context);
                    setState(() {
                      _hasHistory = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('History cleared')),
                    );
                  },
                  child: Text('Clear History'),
                ),
                SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e')),
      );
    }
  }
  
  String _formatDateTime(String? timestamp) {
    if (timestamp == null) return 'Unknown date';
    
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      
      // Same day
      if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
        return 'Today ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
      
      // Yesterday
      final yesterday = now.subtract(const Duration(days: 1));
      if (dateTime.year == yesterday.year && dateTime.month == yesterday.month && dateTime.day == yesterday.day) {
        return 'Yesterday ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
      
      // Within 7 days
      if (now.difference(dateTime).inDays < 7) {
        const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        return '${days[dateTime.weekday - 1]} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
      
      // Older
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<void> _initializeSession() async {
    try {
      if (kDebugMode) {
        print('Initializing session...');
      }
      
      // Get session ID with timeout
      _sessionId = await _sessionService.getSessionId().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) {
            print('Session initialization timed out, using fallback');
          }
          return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
        },
      );
      
      if (kDebugMode) {
        print('Session initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during session initialization: $e');
      }
      rethrow; // Let the error be caught by the .catchError() in initState
    }
  }
  
  Future<void> _checkHistory() async {
    final history = await _historyService.getSearchHistory(limit: 1);
    if (mounted) {
      setState(() {
        _hasHistory = history.isNotEmpty;
      });
    }
  }

  // Handle results and navigate to results screen
  Future<void> _handleResultsAndNavigation(FoodInfo foodInfo) async {
    // Always log the result for debugging
    if (kDebugMode) {
      print('Analysis result: ${foodInfo.foodName}, freshness: ${foodInfo.freshness.level} (${foodInfo.freshness.percentage}%)');
    }
    
    // Save session ID for future use if available
    if (foodInfo.sessionId != null && foodInfo.sessionId!.isNotEmpty) {
      _sessionId = foodInfo.sessionId;
      await _sessionService.saveSessionId(foodInfo.sessionId!);
    }
    
    // Save result to search history
    try {
      await _historyService.saveFoodInfoToHistory(foodInfo);
      if (kDebugMode) {
        print('Saved result to history');
      }
      
      // Update the history flag
      setState(() {
        _hasHistory = true;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error saving to history: $e');
      }
    }
    
    // Navigate to results screen
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      
      // Close processing bottom sheet if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Navigate to results screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(foodInfo: foodInfo),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview or Placeholder
          Positioned.fill(
            child: kIsWeb
              ? _buildCameraPlaceholder('Camera is not available on web')
              : !_isCameraInitialized || _cameraController == null
                ? _buildCameraPlaceholder(_cameraErrorMessage.isEmpty 
                    ? 'Camera not initialized' 
                    : _cameraErrorMessage)
                : _buildCameraPreview(),
          ),

          // Top frosted glass header with app name
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.black.withOpacity(0.2),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        // App logo
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.eco,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // App name
                        Text(
                          'NutriFresh',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.95),
                            letterSpacing: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Flashlight toggle button
                        if (!kIsWeb && _isCameraInitialized)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                                  key: ValueKey(_isFlashOn),
                                  color: _isFlashOn 
                                    ? Colors.yellow.shade400 
                                    : Colors.white.withOpacity(0.9),
                                  size: 24,
                                ),
                              ),
                              tooltip: _isFlashOn ? 'Turn off flashlight' : 'Turn on flashlight',
                              onPressed: _toggleFlash,
                            ),
                          ),
                        // Settings button
                        IconButton(
                          icon: Icon(
                            Icons.settings,
                            color: Colors.white.withOpacity(0.9),
                            size: 24,
                          ),
                          onPressed: () async {
                            // Navigate to settings and wait for result
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                            
                            // When returning from settings, reload upload service config
                            if (mounted) {
                              _uploadService.reloadConfig();
                              
                              // Show a toast message about server configuration
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Server configuration updated'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Controls with frosted glass effect
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.only(top: 20, bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Gallery Button with hover animation
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 1.0, end: _isProcessing ? 1.0 : 1.05),
                          duration: const Duration(milliseconds: 200),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: _isProcessing ? 1.0 : value,
                              child: Container(
                                height: 56,
                                width: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.15),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isProcessing ? null : _pickFromGallery,
                                    borderRadius: BorderRadius.circular(28),
                                    splashColor: AppTheme.primaryColor.withOpacity(0.2),
                                    child: Center(
                                      child: Icon(
                                        Icons.photo_library,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        // Capture Button with ripple animation
                        GestureDetector(
                          onTapDown: (_) => _animationController.stop(),
                          onTapUp: (_) => _animationController.repeat(reverse: true),
                          onTapCancel: () => _animationController.repeat(reverse: true),
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _isProcessing ? 1.0 : _pulseAnimation.value,
                                child: Container(
                                  height: 70,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        Colors.white.withOpacity(0.9),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.3),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 3),
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.7),
                                        blurRadius: 12,
                                        spreadRadius: -3,
                                        offset: const Offset(-3, -3),
                                      ),
                                    ],
                                  ),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: _isProcessing ? 0.6 : 1.0,
                                    child: FloatingActionButton(
                                      heroTag: 'captureBtn',
                                      onPressed: _isProcessing ? null : _isCameraInitialized ? _takePicture : _pickFromGallery,
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      highlightElevation: 0,
                                      splashColor: AppTheme.primaryColor.withOpacity(0.3),
                                      foregroundColor: AppTheme.primaryColor,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Outer ring that pulses
                                          AnimatedBuilder(
                                            animation: _animationController,
                                            builder: (context, child) {
                                              return Container(
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: AppTheme.primaryColor.withOpacity(
                                                      0.2 + (0.3 * _animationController.value),
                                                    ),
                                                    width: 2,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          // Inner circle with icon
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppTheme.primaryColor.withOpacity(0.1),
                                            ),
                                            child: Icon(
                                              Icons.search,
                                              color: AppTheme.primaryColor,
                                              size: 32,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                          ),
                        ),
                        
                        // History Button with glow on available history
                        Stack(
                          children: [
                            Container(
                              height: 56,
                              width: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isProcessing ? null : _showHistory,
                                  borderRadius: BorderRadius.circular(28),
                                  splashColor: AppTheme.primaryColor.withOpacity(0.2),
                                  child: Center(
                                    child: const Icon(
                                      Icons.history,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_hasHistory)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withOpacity(
                                              0.3 + (0.3 * _animationController.value),
                                            ),
                                            blurRadius: 4 + (4 * _animationController.value),
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return _buildCameraPlaceholder('Camera initializing...');
    }
    
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: AspectRatio(
            aspectRatio: 1 / _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCameraPlaceholder(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please use the gallery button below',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
} 
