import 'package:flutter/material.dart';
import 'package:nutrifresh/config/app_config.dart';
import 'package:nutrifresh/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define a class for Developer information
class Developer {
  final String name;
  final String role;
  final String rollNo;
  final String imagePath;
  final String detailedInfo; // More detailed info for the popup

  const Developer({
    required this.name,
    required this.role,
    required this.rollNo,
    required this.imagePath,
    required this.detailedInfo,
  });
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverIPController = TextEditingController();
  final _serverPortController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  
  // List of developers
  final List<Developer> _developers = [
    Developer(
      name: 'Mahnoor',
      role: 'Flutter App Developer',
      rollNo: 'BSSE-SP22-M-23',
      imagePath: 'assets/images/developers/mahnoor.png',
      detailedInfo: 'Mahnoor is the primary Flutter app developer, responsible for the overall UI/UX and client-side logic of NutriFresh.',
    ),
    Developer(
      name: 'Muzamil Saleem',
      role: 'ML Engineer / Backend Dev',
      rollNo: 'BSSE-SP22-M-27',
      imagePath: 'assets/images/developers/muzamil.png',
      detailedInfo: 'Muzamil focuses on the machine learning models and backend development, ensuring accurate food analysis.',
    ),
    Developer(
      name: 'Shahab Ali',
      role: 'Backend / API Integration & Testing',
      rollNo: 'BSSE-SP22-M-07',
      imagePath: 'assets/images/developers/shahab.png',
      detailedInfo: 'Shahab is responsible for robust API integration and thorough testing of backend services.',
    ),
    Developer(
      name: 'Ahmed Ali',
      role: 'Backend / Database Engineer',
      rollNo: 'BSSE-SP22-M-29',
      imagePath: 'assets/images/developers/ahmed.png',
      detailedInfo: 'Ahmed manages the database infrastructure and ensures efficient data storage and retrieval for the application.',
    ),
  ];
  
  @override
  void initState() {
    super.initState();
    _loadServerSettings();
  }
  
  Future<void> _loadServerSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverIP = prefs.getString('server_ip') ?? 'localhost';
      final serverPort = prefs.getString('server_port') ?? '3001';
      
      setState(() {
        _serverIPController.text = serverIP;
        _serverPortController.text = serverPort;
        _isLoading = false;
      });
    } catch (e) {
      // Set default values if unable to load
      setState(() {
        _serverIPController.text = 'localhost';
        _serverPortController.text = '3001';
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
    }
  }
  
  Future<void> _saveServerSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverIP = _serverIPController.text.trim();
      final serverPort = _serverPortController.text.trim();
      
      await prefs.setString('server_ip', serverIP);
      await prefs.setString('server_port', serverPort);
      
      // Force app config to reload settings
      await AppConfig().reloadApiSettings();
      
      // Get the new base URL for display
      final newBaseUrl = AppConfig().apiBaseUrl;
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server settings updated to $serverIP:$serverPort\nAPI URL: $newBaseUrl'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }
  
  String? _validateIP(String? value) {
    if (value == null || value.isEmpty) {
      return 'Server IP cannot be empty';
    }
    
    // Simple IP validation - allow localhost and IP addresses
    if (value != 'localhost' && !value.contains('10.0.2.2') && !RegExp(r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$').hasMatch(value)) {
      return 'Enter a valid IP address or "localhost"';
    }
    
    return null;
  }
  
  String? _validatePort(String? value) {
    if (value == null || value.isEmpty) {
      return 'Server port cannot be empty';
    }
    
    // Port validation
    final port = int.tryParse(value);
    if (port == null || port < 1 || port > 65535) {
      return 'Enter a valid port number (1-65535)';
    }
    
    return null;
  }
  
  @override
  void dispose() {
    _serverIPController.dispose();
    _serverPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Server Settings Section
                    const Text(
                      'Server Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Configure the connection to the NutriFresh analysis server',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Server IP Field
                    TextFormField(
                      controller: _serverIPController,
                      decoration: InputDecoration(
                        labelText: 'Server IP Address',
                        hintText: 'e.g., 192.168.1.100 or localhost',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.dns),
                      ),
                      validator: _validateIP,
                    ),
                    const SizedBox(height: 16),
                    
                    // Server Port Field
                    TextFormField(
                      controller: _serverPortController,
                      decoration: InputDecoration(
                        labelText: 'Server Port',
                        hintText: 'e.g., 3001',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      validator: _validatePort,
                    ),
                    const SizedBox(height: 24),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveServerSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // About Section
                    const Text(
                      'About NutriFresh',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'NutriFresh analyzes food freshness and nutritional value using advanced AI techniques.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // App Version
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('App Version'),
                      subtitle: Text('1.0.0'),
                    ),
                    
                    // Development Team Section
                    const SizedBox(height: 32),
                    _buildDevelopmentTeamSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDevelopmentTeamSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.people, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text(
                'Development Team',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Meet the dedicated team behind the NutriFresh app.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _developers.length,
          itemBuilder: (context, index) {
            final developer = _developers[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 4,
                shadowColor: AppTheme.primaryColor.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () => _showDeveloperDetailsDialog(context, developer),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'developer_${developer.name}',
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: FutureBuilder(
                                future: precacheImage(AssetImage(developer.imagePath), context),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Container(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    );
                                  }
                                  return Image.asset(
                                    developer.imagePath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print('Error loading image: ${developer.imagePath}');
                                      print('Error details: $error');
                                      return Container(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        child: Icon(
                                          Icons.person,
                                          size: 40,
                                          color: AppTheme.primaryColor,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                developer.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                developer.role,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  developer.rollNo,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showDeveloperDetailsDialog(BuildContext context, Developer developer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'developer_${developer.name}',
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: FutureBuilder(
                        future: precacheImage(AssetImage(developer.imagePath), context),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            );
                          }
                          return Image.asset(
                            developer.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading image in dialog: ${developer.imagePath}');
                              print('Error details: $error');
                              return Container(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppTheme.primaryColor,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  developer.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    developer.role,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  developer.rollNo,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey[200]!,
                    ),
                  ),
                  child: Text(
                    developer.detailedInfo,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}