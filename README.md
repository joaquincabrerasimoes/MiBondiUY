# MiBondiUY

A real-time bus tracking Flutter app for Montevideo, Uruguay's public transportation system.

## Features

- **Real-time Bus Locations**: Shows current positions of buses across Montevideo metropolitan area
- **Cross-Platform Maps**: 
  - **Mobile/Web**: Google Maps integration with native performance  
  - **Desktop**: OpenStreetMap via flutter_map for Windows, macOS, and Linux
- **Advanced Filtering System**:
  - **Company Filtering**: Filter by transportation companies with color-coded markers (all selected by default)
  - **Subsystem Filtering**: Dropdown selection for geographic regions (Montevideo, Canelones, San Jose, Metropolitano)
  - **Line Filtering**: Filter by specific bus line codes (comma-separated input)
- **Adaptive UI**: 
  - **Portrait Mode**: Filters accessible via hamburger menu drawer
  - **Landscape Mode**: Filters overlay the map as floating left panel with rounded corners
- **Smart Refresh Control**:
  - **Countdown Timer**: Visual circular countdown showing next refresh
  - **Tap to Refresh**: Instantly refresh data by tapping the countdown
  - **Customizable Interval**: Long press countdown to change refresh rate (5s to 1min)
- **Adaptive Theming**:
  - **System Theme Detection**: Automatically follows system light/dark mode on launch
  - **Manual Theme Toggle**: Sun/moon button in top-right corner to switch themes
  - **Persistent Preferences**: Theme choice saved in local storage and restored on app restart
  - **Full Dark Mode Support**: Complete dark theme for better night usage
- **Bus Information**: Tap any bus marker to see detailed information including:
  - Bus line and route
  - Company information
  - Current speed
  - Destination  
  - GPS coordinates
- **Modern UI**: Clean, intuitive interface following Material Design
- **Platform-Aware**: Automatically selects the best map provider for each platform

## Data Source

This app uses the official Montevideo government bus tracking API:
- **API Endpoint**: `https://montevideo.gub.uy/buses/rest/stm-online`
- **Data Format**: GeoJSON with real-time bus positions and metadata
- **Coverage**: All major bus companies in the Montevideo metropolitan area

## Supported Bus Companies

- COETC
- EMPRESA CASANOVA LIMITADA  
- COPSA
- COME/COMESA
- CITA
- SAN ANTONIO TRANSPORTE Y TURISMO
- C.O. DEL ESTE
- TALA-PANDO-MONTEVIDEO
- SOLFY SA
- TURIL
- ZEBALLOS HERMANOS
- RUTAS DEL NORTE
- CUTCSA
- UCOT
- COIT

## Setup Instructions

### Prerequisites

1. **Flutter SDK**: Install Flutter (version 3.0.0 or higher)
2. **Google Maps API Key**: Obtain from Google Cloud Console
3. **Android Studio**: For Android development
4. **Xcode**: For iOS development (macOS only)

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd MiBondiUY
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Google Maps API Key**:
   
   **For Android**:
   - Edit `android/app/src/main/AndroidManifest.xml`
   - Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key
   
   **For iOS**:
   - Edit `ios/Runner/AppDelegate.swift`
   - Add your API key to the GMSServices configuration

4. **Run the app**:
   ```bash
   flutter run
   ```

### Google Maps API Setup

**Note**: Google Maps API key is only required for mobile (Android/iOS) and web platforms. Desktop platforms use OpenStreetMap and don't require an API key.

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Geocoding API (optional)
4. Create API credentials (API Key)
5. Restrict the API key to your app's package name for security

## Architecture

The app follows a clean architecture pattern:

```
lib/
├── main.dart                 # App entry point with theme integration
├── models/                   # Data models
│   ├── bus.dart             # Bus entity model
│   ├── company.dart         # Company data and colors
│   └── subsystem.dart       # Subsystem definitions
├── services/                # External services
│   ├── bus_service.dart     # API communication
│   └── theme_service.dart   # Theme management with system detection
├── screens/                 # UI screens
│   └── map_screen.dart      # Main map interface with adaptive layout
└── widgets/                 # Reusable UI components
    ├── bus_info_dialog.dart # Bus details popup
    ├── filter_drawer.dart   # Portrait mode filtering drawer
    ├── adaptive_filter_panel.dart # Landscape mode floating filter panel
    ├── platform_map.dart    # Platform-aware map widget
    └── refresh_countdown.dart # Customizable refresh countdown timer
```

## API Usage

The app makes HTTP POST requests to the Montevideo bus API:

```json
{
  "subsistema": "-1",    // -1 for all, or specific code
  "empresa": "-1",       // -1 for all, or specific company code
  "lineas": ["2K"]       // Optional: specific bus lines
}
```

Response format is GeoJSON with bus features containing position and metadata.

## Platform-Specific Features

### Mobile & Web (Google Maps)
- Native Google Maps integration
- Satellite/hybrid map modes
- User location with GPS
- Smooth marker animations
- Requires Google Maps API key

### Desktop (OpenStreetMap)
- OpenStreetMap tiles via flutter_map package from [pub.dev](https://pub.dev/packages/flutter_map)
- No API key required
- Custom circular markers with company colors
- Excellent desktop mouse/keyboard support
- Works offline with cached tiles

## Permissions

The app requires the following permissions:
- **Internet**: To fetch real-time bus data
- **Location**: To show user's current position on map (optional on mobile)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source and available under the MIT License.

## Acknowledgments

- Data provided by Intendencia de Montevideo
- Built with Flutter and Google Maps
- Bus company information and routes courtesy of STM (Sistema de Transporte Metropolitano)

## Support

For issues, questions, or contributions, please use the GitHub issue tracker.
