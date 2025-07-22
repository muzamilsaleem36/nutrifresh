# NutriFresh

A Flutter application for analyzing food freshness, nutritional content, and storage recommendations.

## Overview

NutriFresh is an app that helps users assess the freshness of fruits and vegetables through image analysis. The app provides:

- Food detection (name and category)
- Freshness analysis with percentage score
- Comprehensive nutritional information
- Health risk indicators calculation based on nutrition data
- Storage recommendations to extend shelf life
- Local history tracking of previous analyses

## Technology Stack

- **Frontend**: Flutter/Dart
- **Backend Communication**: RESTful API
- **Local Storage**: SQLite
- **Local Server**: FastAPI (Python)

## Setup and Installation

### Flutter App

1. Clone the repository
2. Install Flutter dependencies:
```
flutter pub get
```
3. Run the app:
```
flutter run
```

### Local Server (for development/testing)

The app can communicate with a local server for testing and development. To set up:

1. Navigate to `local_server` directory
2. Install Python dependencies:
```
pip install -r requirements.txt
```
3. Start the server:
```
python main.py
```

This will start a FastAPI server on `http://localhost:3000` with a web dashboard for monitoring requests and testing.

## How It Works

1. **Capture or upload an image**: The app allows users to take a picture or upload an existing image of food.
2. **Image analysis**: The image is sent to the server along with a unique session ID.
3. **Server processing**: The server identifies the food and analyzes its properties.
4. **Results display**: The app displays freshness score, nutritional data, health risk factors, and storage recommendations.
5. **Local analysis**: Health risk factors are calculated directly in the app based on the nutrition data.
6. **History tracking**: Each analysis is saved in a local SQLite database for future reference.

## Key Features

- Real-time image analysis
- Comprehensive nutritional breakdown
- Health risk indicators (diabetes, cholesterol, etc.)
- Storage recommendations with estimated shelf-life extension
- History of previous analyses
- Clean, intuitive UI

## Application Structure

- `lib/screens/` - Main application screens
- `lib/models/` - Data models
- `lib/services/` - Business logic and API services
- `lib/utils/` - Helper functions and utilities
- `lib/widgets/` - Reusable UI components
- `lib/config/` - Application configuration
- `local_server/` - FastAPI test server

## Environment Configuration

The app can work with different backend environments:

- `local` - Uses the local development server (localhost:3000)
- `development` - Uses development API server
- `production` - Uses production API server

## Local Server Dashboard

The local server provides a web dashboard at `http://localhost:3000` where you can:

1. View incoming requests from the app
2. See uploaded images stored in the uploads folder
3. Create custom JSON responses for testing

## License

This project is licensed under the MIT License.
