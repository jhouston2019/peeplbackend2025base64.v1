# Peepl Mobile App 2025

A modern React Native mobile application for the Peepl social platform, featuring location-based venue discovery, photo sharing, and real-time social interactions.

## 🚀 Features

### ✅ **Core Features**
- **Cross-platform**: iOS and Android support
- **Modern Authentication**: Secure login/register with JWT tokens
- **Location Services**: Real-time GPS tracking and nearby venue discovery
- **Interactive Maps**: Google Maps integration with custom markers
- **Real-time Updates**: Socket.io integration for live features
- **Photo Sharing**: Image capture and upload functionality
- **Push Notifications**: Location-based and social notifications
- **Social Features**: Peeps, ratings, and venue interactions

### ✅ **Advanced Features**
- **Geofencing**: Automatic venue detection when nearby
- **Background Location**: Continuous location tracking
- **Offline Support**: Local data caching and sync
- **Modern UI/UX**: Clean, intuitive interface with Material Design
- **TypeScript**: Full type safety throughout the app
- **Performance Optimized**: Smooth animations and fast loading

## 🏗️ Technology Stack

- **Framework**: React Native 0.72.6
- **Language**: TypeScript
- **Navigation**: React Navigation 6
- **Maps**: React Native Maps with Google Maps
- **State Management**: React Hooks + Context
- **HTTP Client**: Axios
- **Real-time**: Socket.io
- **Storage**: AsyncStorage + Keychain
- **UI Components**: React Native Elements + Paper
- **Push Notifications**: Firebase Cloud Messaging
- **Location**: React Native Geolocation Service

## 📱 Getting Started

### **Prerequisites**

- Node.js 16+
- React Native CLI
- Android Studio (for Android development)
- Xcode (for iOS development)
- Google Maps API key
- Firebase project setup

### **Installation**

1. **Clone the repository**
   ```bash
   git clone https://github.com/jhouston2019/peepl2025.v1.git
   cd peepl2025.v1/PeeplMobile
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **iOS Setup**
   ```bash
   cd ios && pod install && cd ..
   ```

4. **Configure environment**
   - Copy `env.example` to `.env`
   - Add your API keys and configuration
   - Update Firebase configuration files

5. **Run the app**
   ```bash
   # iOS
   npm run ios
   
   # Android
   npm run android
   ```

## 🔧 Configuration

### **Environment Variables**
```bash
# API Configuration
API_BASE_URL=http://localhost:3000
SOCKET_URL=http://localhost:3000

# Google Maps
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here

# App Configuration
APP_NAME=Peepl
APP_VERSION=2.0.0

# Development
DEBUG_MODE=true
LOG_LEVEL=debug
```

### **Firebase Configuration**

**Android**: Update `android/app/google-services.json`
**iOS**: Update `ios/PeeplMobile/GoogleService-Info.plist`

### **Google Maps Setup**

1. Get API key from Google Cloud Console
2. Enable Maps SDK for iOS and Android
3. Add API key to environment configuration
4. Update platform-specific configurations

## 📁 Project Structure

```
src/
├── components/          # Reusable UI components
│   ├── common/         # Common components
│   ├── forms/          # Form components
│   └── maps/           # Map-related components
├── screens/            # Screen components
│   ├── auth/           # Authentication screens
│   ├── main/           # Main app screens
│   └── modals/         # Modal screens
├── services/           # API and external services
│   ├── api/            # API service layer
│   ├── auth/           # Authentication service
│   ├── location/       # Location services
│   └── notifications/  # Push notification service
├── types/              # TypeScript type definitions
├── utils/              # Utility functions
├── hooks/              # Custom React hooks
├── constants/          # App constants and configuration
├── navigation/         # Navigation configuration
└── store/              # State management
```

## 🚀 Build & Deployment

### **Development Build**
```bash
# Start Metro bundler
npm start

# Run on iOS simulator
npm run ios

# Run on Android emulator
npm run android
```

### **Production Build**

**Android**
```bash
# Generate APK
npm run build:android

# Generate AAB (for Play Store)
npm run build:android-bundle
```

**iOS**
```bash
# Build for App Store
npm run build:ios
```

### **App Store Deployment**

**iOS App Store**
1. Configure app in App Store Connect
2. Build production app: `npm run build:ios`
3. Upload to App Store Connect
4. Submit for review

**Google Play Store**
1. Configure app in Play Console
2. Build production APK/AAB: `npm run build:android`
3. Upload to Play Console
4. Submit for review

## 🧪 Testing

```bash
# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# Run tests in watch mode
npm run test:watch

# Type checking
npm run type-check
```

## 🔧 Development

### **Code Style**
- ESLint configuration included
- Prettier for code formatting
- TypeScript for type safety
- Husky for git hooks

### **Debugging**
- React Native Debugger
- Flipper integration
- Console logging
- Error boundary implementation

### **Performance**
- Image optimization
- Lazy loading
- Memory management
- Bundle size optimization

## 📊 Features Overview

### **Authentication**
- Secure login/register
- JWT token management
- Biometric authentication
- Social login integration

### **Location Services**
- Real-time GPS tracking
- Background location updates
- Geofencing for venues
- Location-based notifications

### **Social Features**
- Venue discovery
- Peep creation and sharing
- User profiles
- Social interactions

### **Maps & Navigation**
- Interactive Google Maps
- Custom venue markers
- Route planning
- Location search

### **Push Notifications**
- Location-based alerts
- Social notifications
- Custom notification handling
- Background processing

## 🔒 Security

- Secure token storage with Keychain
- API request encryption
- Input validation
- Secure image uploads
- Privacy controls

## 📈 Performance

- Optimized image loading
- Efficient state management
- Background task optimization
- Memory leak prevention
- Fast app startup

## 🐛 Troubleshooting

### **Common Issues**

**Metro bundler issues**
```bash
npm run reset-cache
```

**iOS build issues**
```bash
cd ios && pod install && cd ..
npm run clean:ios
```

**Android build issues**
```bash
npm run clean:android
```

**Permission issues**
- Check Info.plist (iOS)
- Check AndroidManifest.xml (Android)
- Verify runtime permissions

## 📞 Support

For support and questions:
- **Documentation**: See project docs
- **Issues**: Create GitHub issues
- **Community**: Join our Discord
- **Email**: Contact development team

## 📄 License

MIT License - see LICENSE file for details

---

**Peepl Mobile 2025** - The future of social location sharing! 📱✨
