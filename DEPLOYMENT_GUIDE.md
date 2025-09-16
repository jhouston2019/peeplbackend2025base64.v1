# 🚀 Peepl 2025 Deployment Guide

Complete guide to deploy the Peepl 2025 social location platform.

## 📋 Prerequisites

### **Required Accounts & Services**
- [ ] **GitHub Account** - For repository access
- [ ] **Firebase Project** - For database and storage
- [ ] **Google Cloud Console** - For Maps API
- [ ] **Apple Developer Account** - For iOS app (optional)
- [ ] **Google Play Console** - For Android app (optional)

### **Required Software**
- [ ] **Node.js 16+** - Backend runtime
- [ ] **npm 8+** - Package manager
- [ ] **Docker** - Container deployment (optional)
- [ ] **React Native CLI** - Mobile development (optional)

## 🔧 Step 1: Firebase Setup

### **1.1 Create Firebase Project**
```bash
1. Go to https://console.firebase.google.com
2. Click "Create a project"
3. Project name: "peepl-2025"
4. Enable Google Analytics (optional)
5. Create project
```

### **1.2 Enable Services**
```bash
# Enable Firestore Database
1. Go to Firestore Database
2. Click "Create database"
3. Start in test mode (we'll add security rules later)
4. Choose location (closest to your users)

# Enable Firebase Storage
1. Go to Storage
2. Click "Get started"
3. Start in test mode
4. Choose same location as Firestore

# Enable Authentication
1. Go to Authentication
2. Click "Get started"
3. Go to Sign-in method
4. Enable Email/Password
```

### **1.3 Get Service Account Key**
```bash
1. Go to Project Settings (gear icon)
2. Go to Service Accounts tab
3. Click "Generate new private key"
4. Download JSON file
5. Convert to base64: base64 -i service-account.json
6. Copy the base64 string
```

### **1.4 Get FCM Server Key**
```bash
1. Go to Project Settings
2. Go to Cloud Messaging tab
3. Copy the Server Key
```

## 🗺️ Step 2: Google Maps Setup

### **2.1 Create Google Cloud Project**
```bash
1. Go to https://console.cloud.google.com
2. Create new project or select existing
3. Enable billing (required for Maps API)
```

### **2.2 Enable APIs**
```bash
# Enable required APIs
1. Go to APIs & Services > Library
2. Enable "Maps SDK for Android"
3. Enable "Maps SDK for iOS"
4. Enable "Places API"
5. Enable "Geocoding API"
```

### **2.3 Create API Key**
```bash
1. Go to APIs & Services > Credentials
2. Click "Create Credentials" > "API Key"
3. Copy the API key
4. (Optional) Restrict the key to specific APIs
```

## ⚙️ Step 3: Environment Configuration

### **3.1 Backend Configuration**
```bash
# Copy environment template
cp env.example .env

# Update .env with your values
FIREBASE_CONFIG_B64=your_base64_encoded_service_account_key
FIREBASE_STORAGE_BUCKET=peepl-2025.appspot.com
JWT_SECRET=your_super_secret_jwt_key_here
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
FCM_SERVER_KEY=your_fcm_server_key
```

### **3.2 Mobile App Configuration**
```bash
# Update Firebase config files
# Android: PeeplMobile/android/app/google-services.json
# iOS: PeeplMobile/ios/PeeplMobile/GoogleService-Info.plist

# Update API endpoints in:
# PeeplMobile/src/services/AuthService.ts
# PeeplMobile/src/services/PushNotificationService.ts
```

## 🚀 Step 4: Local Development

### **4.1 Backend Setup**
```bash
# Install dependencies
npm install

# Start development server
npm start

# Test endpoints
curl http://localhost:3000/health
```

### **4.2 Mobile App Setup**
```bash
cd PeeplMobile

# Install dependencies
npm install

# iOS setup (macOS only)
cd ios && pod install && cd ..

# Run on iOS
npm run ios

# Run on Android
npm run android
```

## 🐳 Step 5: Docker Deployment

### **5.1 Build and Run**
```bash
# Build Docker image
docker build -t peepl-backend-2025 .

# Run with Docker Compose
docker-compose -f docker-compose.prod.yml up -d

# Check status
docker-compose -f docker-compose.prod.yml ps
```

### **5.2 Verify Deployment**
```bash
# Check health
curl http://localhost:3000/health

# View logs
docker-compose -f docker-compose.prod.yml logs -f
```

## ☁️ Step 6: Cloud Deployment

### **6.1 Google Cloud Run**
```bash
# Build and push image
gcloud builds submit --tag gcr.io/PROJECT_ID/peepl-backend

# Deploy to Cloud Run
gcloud run deploy peepl-backend \
  --image gcr.io/PROJECT_ID/peepl-backend \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

### **6.2 AWS Elastic Beanstalk**
```bash
# Install EB CLI
pip install awsebcli

# Initialize EB
eb init

# Create environment
eb create production

# Deploy
eb deploy
```

### **6.3 Heroku**
```bash
# Install Heroku CLI
# Login to Heroku
heroku login

# Create app
heroku create peepl-backend-2025

# Set environment variables
heroku config:set FIREBASE_CONFIG_B64=your_key
heroku config:set JWT_SECRET=your_secret

# Deploy
git push heroku main
```

## 📱 Step 7: Mobile App Deployment

### **7.1 iOS App Store**
```bash
# Build for production
cd PeeplMobile
npm run build:ios

# Open Xcode
open ios/PeeplMobile.xcworkspace

# Archive and upload to App Store Connect
# Follow Apple's submission process
```

### **7.2 Google Play Store**
```bash
# Build APK
cd PeeplMobile
npm run build:android

# Build AAB (recommended)
npm run build:android-bundle

# Upload to Play Console
# Follow Google's submission process
```

## 🔒 Step 8: Security Configuration

### **8.1 Firestore Security Rules**
```javascript
// Update firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Add your security rules here
  }
}
```

### **8.2 Environment Security**
```bash
# Never commit .env files
echo ".env" >> .gitignore

# Use environment variables in production
# Set secure JWT secrets
# Enable HTTPS only
```

## 📊 Step 9: Monitoring & Analytics

### **9.1 Application Monitoring**
```bash
# Set up logging
# Configure Winston transports
# Set up error tracking
# Monitor performance metrics
```

### **9.2 Firebase Analytics**
```bash
# Enable Firebase Analytics
# Set up custom events
# Configure user properties
# Set up conversion tracking
```

## 🧪 Step 10: Testing

### **10.1 Backend Testing**
```bash
# Run tests
npm test

# Run with coverage
npm run test:coverage

# Integration tests
npm run test:integration
```

### **10.2 Mobile App Testing**
```bash
cd PeeplMobile

# Run tests
npm test

# E2E tests
npm run test:e2e
```

## 🔄 Step 11: CI/CD Pipeline

### **11.1 GitHub Actions**
```yaml
# .github/workflows/deploy.yml
name: Deploy Peepl 2025

on:
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install dependencies
        run: npm ci
      - name: Run tests
        run: npm test

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to production
        run: |
          # Add your deployment commands here
```

## 🚨 Troubleshooting

### **Common Issues**

**Firebase Connection Issues**
```bash
# Check service account key
# Verify project ID
# Check network connectivity
```

**Maps Not Loading**
```bash
# Verify API key
# Check API restrictions
# Verify bundle ID/package name
```

**Push Notifications Not Working**
```bash
# Check FCM server key
# Verify device tokens
# Check notification permissions
```

**Docker Issues**
```bash
# Check Docker daemon
# Verify port availability
# Check container logs
```

## 📞 Support

### **Getting Help**
- **Documentation**: Check README files
- **Issues**: Create GitHub issues
- **Community**: Join Discord server
- **Email**: Contact development team

### **Useful Commands**
```bash
# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Scale services
docker-compose up -d --scale peepl-backend=3

# Backup database
npm run db:backup

# Health check
curl http://localhost:3000/health
```

## 🎯 Production Checklist

### **Before Going Live**
- [ ] All environment variables configured
- [ ] Firebase security rules updated
- [ ] API keys secured and restricted
- [ ] SSL certificates installed
- [ ] Monitoring and logging configured
- [ ] Backup procedures tested
- [ ] Performance testing completed
- [ ] Security audit performed
- [ ] Mobile apps tested on devices
- [ ] Push notifications working
- [ ] Location services working
- [ ] Database optimized
- [ ] CDN configured
- [ ] Error tracking setup

### **Post-Launch**
- [ ] Monitor application performance
- [ ] Track user analytics
- [ ] Monitor error rates
- [ ] Check server resources
- [ ] Review user feedback
- [ ] Plan feature updates
- [ ] Schedule regular backups
- [ ] Update dependencies
- [ ] Security patches

---

**🎉 Congratulations! Your Peepl 2025 platform is now live!**

For ongoing maintenance and updates, refer to the documentation and keep your dependencies updated regularly.
