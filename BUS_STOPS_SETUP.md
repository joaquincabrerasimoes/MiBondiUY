# Bus Stops Setup Guide

This guide explains how to set up the new bus stops functionality that uses OAuth 2.0 authentication.

## 🚀 Features Added

- **OAuth 2.0 Authentication**: Secure token-based authentication for bus stops API
- **Smart Caching**: Bus stops are cached locally and only refreshed when needed
- **Token Management**: Automatic token renewal (tokens expire after 5 minutes)
- **Different Markers**: Bus stops have distinct square markers vs circular bus markers
- **Refresh Button**: Manual refresh button in the app bar to update bus stops cache
- **Error Handling**: Graceful error handling for API failures
- **Configurable APIs**: Both bus tracking and bus stops APIs are now configurable via .env file

## 📋 Setup Instructions

### 1. Create the .env file

Create a file named `.env` in the `assets/` folder with the following content:

```env
# OAuth 2.0 Configuration for Bus Stops API
ACCESS_TOKEN_URL=https://your-oauth-server.com/oauth/token
CLIENT_ID=your_client_id_here
CLIENT_SECRET=your_client_secret_here

# Bus Stops API Endpoint
BUS_STOPS_API=https://your-bus-stops-api.com/api/stops

# Bus Tracking API Configuration
BUS_API_URL=https://montevideo.gub.uy/buses/rest/stm-online
BUS_API_ORIGIN=https://montevideo.gub.uy
BUS_API_REFERER=https://montevideo.gub.uy/buses/mapaBuses.html
```

### 2. Replace placeholder values

Replace the placeholder values with your actual API credentials:

- `ACCESS_TOKEN_URL`: Your OAuth 2.0 token endpoint
- `CLIENT_ID`: Your OAuth 2.0 application client ID
- `CLIENT_SECRET`: Your OAuth 2.0 application client secret
- `BUS_STOPS_API`: Your bus stops data API endpoint
- `BUS_API_URL`: Bus tracking API endpoint (defaults to Montevideo's API)
- `BUS_API_ORIGIN`: Origin header for bus API requests
- `BUS_API_REFERER`: Referer header for bus API requests

**Note**: The bus API configuration (BUS_API_*) has default values for Montevideo's bus system. You only need to change these if you're using a different bus tracking API.

### 3. File structure

Your project structure should look like this:

```
MiBondiUY/
├── assets/
│   └── .env                 # <- Create this file
├── lib/
│   ├── models/
│   │   ├── bus_stop.dart    # ✅ Created
│   │   └── ...
│   ├── services/
│   │   ├── bus_stop_service.dart  # ✅ Created
│   │   └── ...
│   ├── widgets/
│   │   ├── bus_stop_info_dialog.dart  # ✅ Created
│   │   └── ...
│   └── ...
└── pubspec.yaml             # ✅ Updated with flutter_dotenv
```

## 🔧 How It Works

### Authentication Flow

1. **First Launch**: App tries to load bus stops from cache
2. **Cache Miss**: If no cache, requests OAuth 2.0 token using client credentials
3. **Token Storage**: Token is cached with timestamp
4. **API Request**: Uses Bearer token to fetch bus stops
5. **Data Caching**: Bus stops are stored locally for 24 hours
6. **Token Renewal**: Tokens are automatically renewed when they expire (5 minutes)

### Caching Strategy

- **Bus Stops Cache**: 24 hours (they don't change frequently)
- **OAuth Token Cache**: 5 minutes (as per API specification)
- **Force Refresh**: Available via refresh button in app bar

### UI Features

- **Bus Stop Markers**: Square markers with bus icon (different from circular bus markers)
- **Zoom-based Display**: Bus stops only show when zoomed in (zoom level > 14)
- **Info Dialog**: Tap bus stops to see details (name, code, address, lines)
- **Status Display**: Shows count of loaded bus stops in bottom-left card
- **Refresh Button**: Top-right refresh button with loading indicator

## 🎨 API Response Format

The service handles multiple API response formats:

```json
// Format 1: Direct array
[
  {
    "id": "stop1",
    "name": "Main Station",
    "code": "001",
    "latitude": -34.8941,
    "longitude": -56.1650,
    "address": "18 de Julio 1234",
    "lines": ["101", "102", "103"]
  }
]

// Format 2: Wrapped in data property
{
  "data": [ /* stops array */ ]
}

// Format 3: Wrapped in stops property
{
  "stops": [ /* stops array */ ]
}
```

## 🔒 Security Notes

- ⚠️ **Never commit the .env file to version control**
- 🔐 Keep your CLIENT_SECRET secure
- 🔄 Tokens automatically expire for security
- 📱 All credentials are stored locally on device

## 🛠️ Troubleshooting

### Common Issues

1. **"Could not load .env file"**
   - Ensure `.env` file exists in `assets/` folder
   - Check file has correct format and no extra spaces

2. **"Authentication failed"**
   - Verify CLIENT_ID and CLIENT_SECRET are correct
   - Check ACCESS_TOKEN_URL is reachable

3. **"Error fetching bus stops"**
   - Verify BUS_STOPS_API endpoint is correct
   - Check API returns data in expected format

4. **No bus stops visible**
   - Zoom in more (bus stops show at zoom level > 14)
   - Check if API returned empty data
   - Try refreshing with the refresh button

5. **Buses not loading**
   - Check BUS_API_URL is correct and accessible
   - Verify BUS_API_ORIGIN and BUS_API_REFERER match your server requirements
   - Default values work for Montevideo's system

### Debug Mode

The app includes console logging for debugging:
- Token requests and caching
- API responses
- Cache hits/misses

## 📱 User Experience

1. **App Launch**: Instantly shows cached bus stops if available
2. **First Time**: Downloads and caches bus stops automatically
3. **Background Updates**: Tokens refresh automatically
4. **Manual Refresh**: Use refresh button to update bus stops
5. **Offline Support**: Shows cached data when offline
6. **Visual Feedback**: Loading indicators and error messages

The bus stops functionality integrates seamlessly with the existing bus tracking features! 