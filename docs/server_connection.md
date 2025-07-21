# NutriFresh Server Connection Guide

This document explains how to connect the NutriFresh Flutter app to your backend server.

## Overview

The NutriFresh app is designed to work with a compatible backend API that provides food analysis, user authentication, and data storage. The app includes a robust API integration layer that handles:

- Authentication with JWT tokens
- HTTP requests with error handling
- Response parsing and model conversion
- File uploads for food analysis

## Configuration

### Server URLs

The app can connect to different server environments (development and production). Update the base URLs in `lib/services/api/endpoints.dart`:

```dart
static const String developmentBaseUrl = 'https://dev-api.nutrifresh.app';  // Your dev server
static const String productionBaseUrl = 'https://api.nutrifresh.app';       // Your production server
```

In release builds, the app will automatically use the production URL. Debug builds use the development URL.

### Testing the Connection

The app includes a connection test utility that can verify connectivity with your server:

1. Navigate to the connection test screen (you may need to add this to your navigation)
2. Click "Test Basic Connection" to check if the server is reachable
3. Use the login form to test authenticated requests

## API Requirements

Your server must implement the endpoints defined in `lib/services/api/endpoints.dart` and follow the response formats specified in `docs/api_reference.md`.

### Required Endpoints

The most critical endpoints for basic functionality are:

- Authentication: 
  - POST `/auth/login`
  - POST `/auth/register`
  
- Food Analysis:
  - POST `/api/v1/analyze-food`
  - GET `/api/v1/food-history`
  - GET `/api/v1/food-details/{id}`

### Response Format

The app expects API responses in the following format:

```json
{
  "success": true,
  "message": "Success message",
  "data": {
    // Response data object or array
  }
}
```

Error responses:

```json
{
  "success": false,
  "message": "Error message",
  "errors": ["Detailed error 1", "Detailed error 2"]
}
```

## Troubleshooting

### Common Connection Issues

1. **SSL Certificate Problems**:
   - Ensure your server has a valid SSL certificate
   - For development, you may need to add certificate exceptions

2. **CORS Issues**:
   - Your API server must allow cross-origin requests from the app

3. **Network Permissions**:
   - Ensure the app has proper network permissions in AndroidManifest.xml and Info.plist

### Logging

The app uses structured logging to help diagnose API issues:

```dart
// Enable debug logging
Logger.root.level = Level.ALL;
Logger.root.onRecord.listen((record) {
  // Print or store logs
  print('${record.level.name}: ${record.time}: ${record.message}');
});
```

## Security Considerations

- User credentials are never stored directly; only JWT tokens are saved in secure storage
- Use HTTPS for all API communications
- Consider implementing certificate pinning for production 