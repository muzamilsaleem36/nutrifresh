# NutriFresh API Reference

## Overview

This document provides a comprehensive reference for the NutriFresh API, which powers the mobile application's food analysis, nutrition tracking, and user management features. The API follows RESTful principles and uses JSON for data exchange.

## Base URLs

| Environment | URL                          |
|-------------|------------------------------|
| Development | http://localhost:8000        |
| Production  | https://api.nutrifresh.app   |

## Authentication

The API uses JWT (JSON Web Tokens) for authentication. Most endpoints require a valid token.

### Headers

Include the following headers with all authenticated requests:

```
Authorization: Bearer <your_token>
Accept: application/json
Content-Type: application/json
```

### Error Handling

The API returns appropriate HTTP status codes and error messages in a consistent format:

```json
{
  "success": false,
  "message": "Error description",
  "errors": ["Detailed error 1", "Detailed error 2"]
}
```

Common status codes:

- `200 OK`: Request succeeded
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Missing or invalid authentication
- `403 Forbidden`: Authentication valid but insufficient permissions
- `404 Not Found`: Resource not found
- `422 Unprocessable Entity`: Validation error
- `500 Internal Server Error`: Server-side error

## Endpoints

### Authentication

#### POST /auth/login

Authenticates a user and returns a token.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "123",
      "name": "John Doe",
      "email": "user@example.com",
      "avatar_url": "https://example.com/avatar.jpg",
      "created_at": "2023-01-15T10:30:00Z"
    }
  }
}
```

#### POST /auth/register

Registers a new user.

**Request:**
```json
{
  "name": "John Doe",
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "123",
      "name": "John Doe",
      "email": "user@example.com",
      "avatar_url": null,
      "created_at": "2023-06-15T14:30:00Z"
    }
  }
}
```

#### POST /auth/refresh

Refreshes an expired access token.

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**
```json
{
  "success": true,
  "message": "Token refreshed",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

#### POST /auth/forgot-password

Sends a password reset email.

**Request:**
```json
{
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Password reset email sent"
}
```

### Food Analysis

#### POST /api/v1/analyze-food

Analyzes a food image and returns detailed information about the food, including freshness, nutrition facts, and storage recommendations.

**Request:**
- Content-Type: `multipart/form-data`
- Form Fields:
  - `image`: Food image file (JPEG, PNG, or WebP format)
  - `additional_info` (optional): JSON string with additional context

**Response:**
```json
{
  "success": true,
  "message": "Food analyzed successfully",
  "data": {
    "food_name": "Banana",
    "category": "Fruit",
    "icon_path": null,
    "freshness": {
      "level": "Mid-spoiled",
      "percentage": 60
    },
    "nutrition": [
      {
        "type": "Protein",
        "value": "1.3g",
        "icon": ""
      },
      {
        "type": "Carbohydrates",
        "value": "27g",
        "icon": ""
      },
      {
        "type": "Fats",
        "value": "0.4g",
        "icon": ""
      },
      {
        "type": "Sugars",
        "value": "14g",
        "icon": ""
      },
      {
        "type": "Fiber",
        "value": "3.1g",
        "icon": ""
      },
      {
        "type": "Vitamin C",
        "value": "10mg",
        "icon": ""
      },
      {
        "type": "Potassium",
        "value": "422mg",
        "icon": ""
      },
      {
        "type": "Sodium",
        "value": "1mg",
        "icon": ""
      }
    ],
    "storage_recommendation": {
      "text": "Consume soon or store in the fridge for 2–3 days.",
      "icon": ""
    },
    "storage_methods": [
      {
        "method": "Refrigeration",
        "icon": "",
        "description": "Store in the refrigerator to maintain what's left of freshness and slow down further spoilage. Consume within 1-2 days."
      },
      {
        "method": "Freezing",
        "icon": "",
        "description": "Peel and slice the banana, then freeze for smoothies or baking. Mid-spoiled bananas are perfect for banana bread."
      }
    ]
  }
}
```

Note: The API only returns textual information (no icon data). The mobile app will map these textual keys to appropriate local icons.

#### GET /api/v1/food-history

Retrieves the user's food analysis history.

**Query Parameters:**
- `limit` (optional): Number of results per page (default: 10)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
{
  "success": true,
  "message": "Food history retrieved",
  "data": {
    "foods": [
      {
        "food_name": "Banana",
        "category": "Fruit",
        "freshness": {
          "level": "Mid-spoiled",
          "percentage": 60
        },
        "analyzed_at": "2023-06-20T15:30:00Z",
        "thumbnail_url": "https://example.com/thumbnails/banana_123.jpg"
      },
      {
        "food_name": "Apple",
        "category": "Fruit",
        "freshness": {
          "level": "Fresh",
          "percentage": 90
        },
        "analyzed_at": "2023-06-19T12:15:00Z",
        "thumbnail_url": "https://example.com/thumbnails/apple_456.jpg"
      }
    ],
    "total": 24,
    "page": 1,
    "limit": 10
  }
}
```

#### GET /api/v1/food-details/{id}

Retrieves detailed information about a specific food analysis.

**Response:**
```json
{
  "success": true,
  "message": "Food details retrieved",
  "data": {
    "id": "food_123",
    "food_name": "Banana",
    "category": "Fruit",
    "icon_path": null,
    "image_url": "https://example.com/images/banana_123.jpg",
    "analyzed_at": "2023-06-20T15:30:00Z",
    "freshness": {
      "level": "Mid-spoiled",
      "percentage": 60
    },
    "nutrition": [
      {
        "type": "Protein",
        "value": "1.3g",
        "icon": ""
      },
      {
        "type": "Carbohydrates",
        "value": "27g",
        "icon": ""
      }
    ],
    "storage_recommendation": {
      "text": "Consume soon or store in the fridge for 2–3 days.",
      "icon": ""
    },
    "storage_methods": [
      {
        "method": "Refrigeration",
        "icon": "",
        "description": "Store in the refrigerator to maintain what's left of freshness and slow down further spoilage. Consume within 1-2 days."
      }
    ]
  }
}
```

### User Profile

#### GET /api/v1/profile

Gets the current user's profile.

**Response:**
```json
{
  "success": true,
  "message": "Profile retrieved",
  "data": {
    "id": "123",
    "name": "John Doe",
    "email": "user@example.com",
    "avatar_url": "https://example.com/avatar.jpg",
    "created_at": "2023-01-15T10:30:00Z"
  }
}
```

#### PUT /api/v1/profile/update

Updates the user's profile information.

**Request:**
```json
{
  "name": "John Smith",
  "email": "john.smith@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Profile updated",
  "data": {
    "id": "123",
    "name": "John Smith",
    "email": "john.smith@example.com",
    "avatar_url": "https://example.com/avatar.jpg",
    "created_at": "2023-01-15T10:30:00Z"
  }
}
```

## Webhooks

The API does not currently support webhooks.

## Rate Limiting

API requests are limited to:
- 60 requests per minute for authenticated users
- 5 requests per minute for unauthenticated users

## API Versioning

The API is versioned in the URL path (e.g., `/api/v1/analyze-food`). This ensures backward compatibility as new versions are released.

## Data Models

### Food Info

```json
{
  "food_name": "string",
  "category": "string",
  "icon_path": "string | null",
  "freshness": {
    "level": "string",
    "percentage": "integer"
  },
  "nutrition": [
    {
      "type": "string",
      "value": "string",
      "icon": "string"
    }
  ],
  "storage_recommendation": {
    "text": "string",
    "icon": "string"
  },
  "storage_methods": [
    {
      "method": "string",
      "icon": "string",
      "description": "string"
    }
  ]
}
```

### User Profile

```json
{
  "id": "string",
  "name": "string",
  "email": "string",
  "avatar_url": "string | null",
  "created_at": "string (ISO 8601 date)"
}
```

## Best Practices

1. Always validate and sanitize input data before sending requests
2. Implement proper error handling for all API calls
3. Cache responses where appropriate to reduce server load
4. Check token expiration and refresh when needed
5. Use appropriate timeout settings for network requests
6. Implement retry logic for transient failures

## Testing

The API includes a sandbox environment for testing:
- Sandbox URL: https://sandbox.api.nutrifresh.app
- Use test credentials:
  - Email: test@example.com
  - Password: testpassword123

## Support

For API support, contact:
- Developer Email: api-support@nutrifresh.app
- API Status Page: https://status.nutrifresh.app 