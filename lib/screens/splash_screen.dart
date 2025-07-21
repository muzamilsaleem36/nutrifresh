import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:nutrifresh/screens/camera_screen.dart';
import 'package:nutrifresh/utils/app_theme.dart';
import 'package:nutrifresh/config/app_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  // Typewriter effect
  String _displayedAppName = "";
  final String _fullAppName = "NutriFresh";
  int _appNameIndex = 0;
  Timer? _typewriterTimer;
  
  // Navigation timer
  bool _navigating = false;
  Timer? _navigationTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController, 
        curve: Curves.elasticOut,
      ),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController, 
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
    
    // Start animations
    _animationController.forward();
    
    // Start typewriter effect after a short delay
    Timer(const Duration(milliseconds: 800), _startTypewriterEffect);
    
    // Make sure configuration is initialized
    final appConfig = AppConfig();
    if (kDebugMode) {
      print('Initializing app configuration in splash screen');
      print('API Base URL: ${appConfig.apiBaseUrl}');
      print('Platform: ${kIsWeb ? 'Web' : 'Native'}');
    }
    
    // Navigate to camera screen after delay with a safety fallback
    _navigationTimer = Timer(const Duration(seconds: 4), _navigateToCameraScreen);
    
    // Failsafe - ensure navigation happens after at most 8 seconds
    Timer(const Duration(seconds: 8), () {
      if (mounted && !_navigating) {
        if (kDebugMode) {
          print("Failsafe navigation triggered after timeout");
        }
        _navigateToCameraScreen();
      }
    });
  }
  
  void _startTypewriterEffect() {
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted && _appNameIndex < _fullAppName.length) {
        setState(() {
          _displayedAppName = _fullAppName.substring(0, _appNameIndex + 1);
          _appNameIndex++;
        });
      } else {
        _typewriterTimer?.cancel();
      }
    });
  }
  
  void _navigateToCameraScreen() {
    if (mounted && !_navigating) {
      if (kDebugMode) {
        print("Navigating to camera screen...");
      }
      
      setState(() {
        _navigating = true;
      });
      
      // Cancel navigation timer if it's still active
      _navigationTimer?.cancel();
      
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const CameraScreen(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _typewriterTimer?.cancel();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE8F5E9),  // Light green
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Plate
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                        ),
                        // Leaf icon
                        Icon(
                          Icons.eco,
                          size: 80,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // App name with typewriter effect
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _displayedAppName,
                    key: ValueKey<String>(_displayedAppName),
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          offset: const Offset(1, 1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // App tagline with fade animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    "Freshness you can trust",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                
                const SizedBox(height: 80),
                
                // Loading indicator with rotation animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      strokeWidth: 3,
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Developer credits text
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        'Developed by',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mahnoor, Muzamil, Shahab, Ahmed Ali',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 