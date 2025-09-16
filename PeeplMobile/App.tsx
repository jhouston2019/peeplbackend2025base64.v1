import React, { useEffect, useState } from 'react';
import {
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Text,
  View,
  Alert,
  PermissionsAndroid,
  Platform,
} from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import Icon from 'react-native-vector-icons/MaterialIcons';
import Toast from 'react-native-toast-message';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Import screens
import LoginScreen from './src/screens/LoginScreen';
import RegisterScreen from './src/screens/RegisterScreen';
import MapScreen from './src/screens/MapScreen';
import VenueScreen from './src/screens/VenueScreen';
import ProfileScreen from './src/screens/ProfileScreen';
import CreatePeepScreen from './src/screens/CreatePeepScreen';
import VenueListScreen from './src/screens/VenueListScreen';

// Import services
import { AuthService } from './src/services/AuthService';
import { LocationService } from './src/services/LocationService';
import { SocketService } from './src/services/SocketService';
import { pushNotificationService } from './src/services/PushNotificationService';

// Import types
import { User } from './src/types/User';
import { Venue } from './src/types/Venue';

const Tab = createBottomTabNavigator();
const Stack = createStackNavigator();

// Main Tab Navigator
function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: string;

          if (route.name === 'Map') {
            iconName = 'map';
          } else if (route.name === 'Venues') {
            iconName = 'place';
          } else if (route.name === 'Profile') {
            iconName = 'person';
          } else {
            iconName = 'help';
          }

          return <Icon name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: '#007AFF',
        tabBarInactiveTintColor: 'gray',
        headerShown: false,
      })}
    >
      <Tab.Screen name="Map" component={MapScreen} />
      <Tab.Screen name="Venues" component={VenueListScreen} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
    </Tab.Navigator>
  );
}

// Main App Component
export default function App(): JSX.Element {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    initializeApp();
  }, []);

  const initializeApp = async () => {
    try {
      // Request permissions
      await requestPermissions();
      
      // Initialize push notifications
      await pushNotificationService.initialize();
      
      // Check authentication
      const token = await AsyncStorage.getItem('authToken');
      if (token) {
        const userData = await AuthService.getCurrentUser();
        if (userData) {
          setUser(userData);
          setIsAuthenticated(true);
          await SocketService.connect(token);
        }
      }
    } catch (error) {
      console.error('App initialization error:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const requestPermissions = async () => {
    if (Platform.OS === 'android') {
      try {
        const granted = await PermissionsAndroid.requestMultiple([
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
          PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION,
          PermissionsAndroid.PERMISSIONS.CAMERA,
          PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
          PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
        ]);

        const allGranted = Object.values(granted).every(
          permission => permission === PermissionsAndroid.RESULTS.GRANTED
        );

        if (!allGranted) {
          Alert.alert(
            'Permissions Required',
            'Please grant all permissions for the app to work properly.'
          );
        }
      } catch (error) {
        console.error('Permission request error:', error);
      }
    }
  };

  const handleLogin = async (email: string, password: string) => {
    try {
      setIsLoading(true);
      const response = await AuthService.login(email, password);
      
      if (response.success) {
        setUser(response.user);
        setIsAuthenticated(true);
        await AsyncStorage.setItem('authToken', response.token);
        await SocketService.connect(response.token);
        
        Toast.show({
          type: 'success',
          text1: 'Welcome back!',
          text2: `Hello ${response.user.firstName}`,
        });
      } else {
        Toast.show({
          type: 'error',
          text1: 'Login Failed',
          text2: response.error || 'Invalid credentials',
        });
      }
    } catch (error) {
      Toast.show({
        type: 'error',
        text1: 'Login Error',
        text2: 'Please try again',
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleRegister = async (userData: any) => {
    try {
      setIsLoading(true);
      const response = await AuthService.register(userData);
      
      if (response.success) {
        setUser(response.user);
        setIsAuthenticated(true);
        await AsyncStorage.setItem('authToken', response.token);
        await SocketService.connect(response.token);
        
        Toast.show({
          type: 'success',
          text1: 'Welcome to Peepl!',
          text2: 'Your account has been created',
        });
      } else {
        Toast.show({
          type: 'error',
          text1: 'Registration Failed',
          text2: response.error || 'Please try again',
        });
      }
    } catch (error) {
      Toast.show({
        type: 'error',
        text1: 'Registration Error',
        text2: 'Please try again',
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      await AsyncStorage.removeItem('authToken');
      await SocketService.disconnect();
      setUser(null);
      setIsAuthenticated(false);
      
      Toast.show({
        type: 'info',
        text1: 'Logged Out',
        text2: 'See you next time!',
      });
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  if (isLoading) {
    return (
      <SafeAreaView style={styles.loadingContainer}>
        <View style={styles.loadingContent}>
          <Icon name="location-on" size={80} color="#007AFF" />
          <Text style={styles.loadingText}>Peepl</Text>
          <Text style={styles.loadingSubtext}>Loading...</Text>
        </View>
      </SafeAreaView>
    );
  }

  if (!isAuthenticated) {
    return (
      <NavigationContainer>
        <Stack.Navigator screenOptions={{ headerShown: false }}>
          <Stack.Screen name="Login">
            {props => <LoginScreen {...props} onLogin={handleLogin} />}
          </Stack.Screen>
          <Stack.Screen name="Register">
            {props => <RegisterScreen {...props} onRegister={handleRegister} />}
          </Stack.Screen>
        </Stack.Navigator>
        <Toast />
      </NavigationContainer>
    );
  }

  return (
    <NavigationContainer>
      <StatusBar barStyle="dark-content" backgroundColor="#ffffff" />
      <Stack.Navigator>
        <Stack.Screen 
          name="MainTabs" 
          component={MainTabs} 
          options={{ headerShown: false }}
        />
        <Stack.Screen 
          name="Venue" 
          component={VenueScreen}
          options={({ route }) => ({
            title: (route.params as any)?.venue?.name || 'Venue',
            headerBackTitle: 'Back',
          })}
        />
        <Stack.Screen 
          name="CreatePeep" 
          component={CreatePeepScreen}
          options={{
            title: 'Create Peep',
            headerBackTitle: 'Cancel',
          }}
        />
      </Stack.Navigator>
      <Toast />
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  loadingContent: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#007AFF',
    marginTop: 20,
  },
  loadingSubtext: {
    fontSize: 16,
    color: '#666666',
    marginTop: 10,
  },
});
