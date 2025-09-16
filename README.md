# Peepl 2025 - Complete Social Location Platform

A modern, cross-platform social location app with real-time features, push notifications, and comprehensive venue discovery.

## 🚀 Features

### ✅ **Backend (Node.js + Firebase)**
- **REST API** with Express.js and comprehensive endpoints
- **Real-time features** with Socket.io integration
- **Location-based push notifications** with geofencing
- **Firebase Firestore** database with optimized queries
- **File upload system** for photos with Firebase Storage
- **JWT authentication** with secure token management
- **Rate limiting** and security middleware
- **Production deployment** with Docker and CI/CD

### ✅ **Mobile App (React Native)**
- **Cross-platform** iOS and Android support
- **Real-time location tracking** with GPS
- **Interactive maps** with Google Maps integration
- **Push notifications** with FCM/APNs
- **Photo capture and sharing** with image picker
- **Modern UI/UX** with Material Design components
- **Offline support** with AsyncStorage
- **TypeScript** for type safety

### ✅ **Advanced Features**
- **Geofencing system** with 100-meter precision
- **Smart push notifications** when users are near venues
- **Real-time social updates** with Socket.io
- **Venue discovery** with nearby search
- **User profiles** with preferences and settings
- **Content moderation** and safety features
- **Analytics tracking** for user behavior

## 🏗️ Architecture

```
peepl2025.v1/
├── Backend (Node.js + Firebase)
│   ├── REST API endpoints
│   ├── Real-time Socket.io
│   ├── Push notification system
│   ├── Geofencing service
│   └── Firebase integration
├── Mobile App (React Native)
│   ├── Cross-platform UI
│   ├── Location services
│   ├── Push notifications
│   └── Real-time updates
└── Production Deployment
    ├── Docker containerization
    ├── CI/CD pipeline
    └── Cloud deployment
```

## 🚀 Quick Start

### **Backend Setup**
```bash
# Install dependencies
npm install

# Configure environment
cp env.example .env
# Add your Firebase and API keys to .env

# Start development server
npm start

# Start production server
npm run production
```

### **Mobile App Setup**
```bash
cd PeeplMobile

# Install dependencies
npm install

# iOS setup
cd ios && pod install && cd ..

# Run on iOS
npm run ios

# Run on Android
npm run android
```

### **Production Deployment**
```bash
# Using Docker
docker-compose up -d

# Using cloud deployment
# Follow deployment guide in docs/
```

## 📱 API Endpoints

### **Authentication**
- `POST /auth/register` - User registration
- `POST /auth/login` - User login
- `GET /users/profile` - Get user profile
- `PUT /users/profile` - Update user profile

### **Venues**
- `GET /venues/nearby` - Get nearby venues
- `POST /venues` - Create new venue
- `GET /venues/:id` - Get venue details
- `PUT /venues/:id` - Update venue

### **Peeps**
- `POST /peeps` - Create new peep
- `GET /peeps/venue/:venueId` - Get venue peeps
- `GET /peeps/user/:userId` - Get user peeps
- `PUT /peeps/:id` - Update peep

### **Location & Notifications**
- `POST /location/update` - Update user location
- `POST /notifications/register-token` - Register device token
- `GET /geofencing/status` - Get geofencing status

## 🗄️ Database Schema

### **Firestore Collections**
- **users** - User profiles and preferences
- **venues** - Venue information and statistics
- **peeps** - User posts and ratings
- **user_locations** - Real-time location tracking
- **geofence_events** - Location-based event logging
- **device_tokens** - Push notification tokens

## 🔧 Configuration

### **Environment Variables**
```bash
# Firebase Configuration
FIREBASE_CONFIG_B64=your_base64_encoded_firebase_config
FIREBASE_STORAGE_BUCKET=your-firebase-storage-bucket.appspot.com

# Server Configuration
PORT=3000
NODE_ENV=production

# JWT Configuration
JWT_SECRET=your_super_secret_jwt_key
JWT_EXPIRES_IN=7d

# API Keys
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
YELP_API_KEY=your_yelp_api_key
FCM_SERVER_KEY=your_fcm_server_key

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# CORS Configuration
CORS_ORIGIN=https://yourdomain.com
```

## 📊 Performance & Scalability

- **Horizontal scaling** with multiple server instances
- **Database optimization** with composite indexes
- **CDN integration** for image delivery
- **Background job processing** for notifications
- **Caching strategies** for improved performance
- **Load balancing** for high availability

## 🔒 Security Features

- **JWT authentication** with secure token management
- **Password hashing** with bcrypt
- **Rate limiting** to prevent abuse
- **Input validation** with express-validator
- **CORS protection** with configurable origins
- **Helmet.js** for security headers
- **Firestore security rules** for data protection

## 🧪 Testing

```bash
# Run backend tests
npm test

# Run mobile app tests
cd PeeplMobile && npm test

# Run integration tests
npm run test:integration
```

## 📈 Monitoring & Analytics

- **Winston logging** with multiple transports
- **Health check endpoints** for monitoring
- **Error tracking** with detailed logging
- **Performance metrics** collection
- **User analytics** tracking
- **Real-time monitoring** dashboard

## 🚀 Deployment

### **Docker Deployment**
```bash
# Build and run with Docker Compose
docker-compose up -d

# Scale services
docker-compose up -d --scale peepl-backend=3
```

### **Cloud Deployment**
- **Google Cloud Run** - Serverless container deployment
- **AWS Elastic Beanstalk** - Managed platform deployment
- **Heroku** - Simple cloud deployment
- **DigitalOcean** - VPS deployment

### **CI/CD Pipeline**
- **GitHub Actions** for automated testing and deployment
- **Automated testing** on pull requests
- **Production deployment** on main branch
- **Rollback capabilities** for quick recovery

## 📱 Mobile App Features

### **Core Features**
- **User authentication** with secure login/register
- **Location services** with GPS tracking
- **Interactive maps** with venue markers
- **Photo sharing** with image capture
- **Push notifications** for location-based alerts
- **Real-time updates** with Socket.io

### **Social Features**
- **Venue discovery** with nearby search
- **Peep creation** with photos and ratings
- **User profiles** with customizable settings
- **Social interactions** with likes and comments
- **Real-time chat** for venue discussions

### **Advanced Features**
- **Offline support** with local data caching
- **Background location** tracking
- **Smart notifications** with user preferences
- **Accessibility support** for all users
- **Dark mode** and theme customization

## 🔄 Migration from 2019 Version

This implementation completely replaces the 2019 iOS-only version with:
- **Cross-platform support** (iOS + Android)
- **Modern architecture** with Node.js backend
- **Enhanced security** with proper authentication
- **Real-time features** with Socket.io
- **Scalable database** with Firebase Firestore
- **Production-ready** deployment configuration

## 📞 Support

For support and questions:
- **Documentation**: See `/docs` folder
- **Issues**: Create GitHub issues
- **Email**: Contact development team
- **Community**: Join our Discord server

## 📄 License

MIT License - see LICENSE file for details

## 🎯 Roadmap

### **Phase 1 (Current)**
- ✅ Core platform implementation
- ✅ Mobile app development
- ✅ Basic social features
- ✅ Location-based notifications

### **Phase 2 (Next)**
- 🔄 Advanced social features
- 🔄 Business/venue owner tools
- 🔄 Analytics dashboard
- 🔄 Content moderation

### **Phase 3 (Future)**
- 📋 Machine learning recommendations
- 📋 Advanced geofencing
- 📋 AR features
- 📋 International expansion

---

**Peepl 2025** - The future of social location sharing is here! 🚀