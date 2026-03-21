import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  TouchableOpacity,
  Platform,
  PermissionsAndroid,
} from 'react-native';
import Geolocation from 'react-native-geolocation-service';
import messaging from '@react-native-firebase/messaging';
import { CommonActions } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';

type Step = 'location' | 'push';

interface PermissionsScreenProps {
  navigation: StackNavigationProp<RootStackParamList>;
}

export default function PermissionsScreen({ navigation }: PermissionsScreenProps) {
  const [currentStep, setCurrentStep] = useState<Step>('location');

  const goToFeed = () => {
    navigation.dispatch(
      CommonActions.reset({
        index: 0,
        routes: [{ name: 'MainTabs' }],
      })
    );
  };

  const requestLocation = async () => {
    try {
      if (Platform.OS === 'ios') {
        await Geolocation.requestAuthorization('whenInUse');
      } else {
        await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
          {
            title: 'Location Permission',
            message:
              'Peepl needs your location to show crowd levels near you and help when you post.',
            buttonPositive: 'OK',
            buttonNegative: 'Cancel',
          }
        );
      }
    } catch {
      // proceed to next step whether granted or denied
    }
    setCurrentStep('push');
  };

  const skipLocation = () => {
    setCurrentStep('push');
  };

  const requestPush = async () => {
    try {
      await messaging().requestPermission();
    } catch {
      // still go to feed
    }
    goToFeed();
  };

  if (currentStep === 'location') {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.inner}>
          <Text style={styles.bigIcon}>📍</Text>
          <Text style={styles.title}>Enable location</Text>

          <View style={styles.bulletRow}>
            <Text style={styles.bulletMark}>✓</Text>
            <Text style={styles.bulletText}>See crowd levels at venues near you</Text>
          </View>
          <View style={styles.bulletRow}>
            <Text style={styles.bulletMark}>✓</Text>
            <Text style={styles.bulletText}>Auto-detect your venue when posting</Text>
          </View>
          <View style={styles.bulletRow}>
            <Text style={styles.bulletMark}>✓</Text>
            <Text style={styles.bulletText}>Get notified about your favorite spots</Text>
          </View>

          <TouchableOpacity style={styles.primaryButton} onPress={requestLocation} activeOpacity={0.85}>
            <Text style={styles.primaryButtonText}>Allow Location</Text>
          </TouchableOpacity>

          <TouchableOpacity onPress={skipLocation} hitSlop={{ top: 12, bottom: 12 }}>
            <Text style={styles.link}>Not now</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.inner}>
        <Text style={styles.bigIcon}>🔔</Text>
        <Text style={styles.title}>Stay in the loop</Text>

        <Text style={styles.example}>🔥 Central Park is getting packed</Text>
        <Text style={styles.example}>⭐ You earned Pioneer status!</Text>
        <Text style={styles.example}>❤️ Someone liked your Peep</Text>

        <TouchableOpacity style={styles.primaryButton} onPress={requestPush} activeOpacity={0.85}>
          <Text style={styles.primaryButtonText}>Allow Notifications</Text>
        </TouchableOpacity>

        <TouchableOpacity onPress={goToFeed} hitSlop={{ top: 12, bottom: 12 }}>
          <Text style={styles.link}>Maybe later</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1565C0',
  },
  inner: {
    flex: 1,
    paddingHorizontal: 24,
    paddingTop: 32,
    justifyContent: 'center',
  },
  bigIcon: {
    fontSize: 72,
    textAlign: 'center',
    marginBottom: 20,
  },
  title: {
    color: '#FFFFFF',
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 28,
  },
  bulletRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 14,
  },
  bulletMark: {
    color: '#FFFFFF',
    fontSize: 18,
    marginRight: 10,
    marginTop: 2,
  },
  bulletText: {
    flex: 1,
    color: '#FFFFFF',
    fontSize: 16,
    lineHeight: 22,
  },
  example: {
    color: '#FFFFFF',
    fontSize: 16,
    marginBottom: 12,
    textAlign: 'center',
  },
  primaryButton: {
    backgroundColor: '#FFC107',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 28,
    marginBottom: 16,
  },
  primaryButtonText: {
    color: '#000000',
    fontSize: 16,
    fontWeight: 'bold',
  },
  link: {
    color: '#FFFFFF',
    fontSize: 16,
    textAlign: 'center',
    textDecorationLine: 'underline',
  },
});
