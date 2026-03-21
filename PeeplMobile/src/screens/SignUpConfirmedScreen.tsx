import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  TouchableOpacity,
  ScrollView,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import auth from '@react-native-firebase/auth';
import { CommonActions } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { RootStackParamList } from '../types/Navigation';

interface SignUpConfirmedScreenProps {
  navigation: StackNavigationProp<RootStackParamList>;
}

const STEPS = [
  'Check the feed to see what\'s happening near you',
  'Post your first Peep to earn your first points',
  'Earn Pioneer status at your first venue',
];

export default function SignUpConfirmedScreen({ navigation }: SignUpConfirmedScreenProps) {
  const displayName =
    auth().currentUser?.displayName ||
    auth().currentUser?.email?.split('@')[0] ||
    'Peepl member';

  const goToFeed = () => {
    navigation.dispatch(
      CommonActions.reset({
        index: 0,
        routes: [{ name: 'MainTabs' }],
      })
    );
  };

  return (
    <LinearGradient colors={['#1565C0', '#0D47A1']} style={styles.gradient}>
      <SafeAreaView style={styles.safe}>
        <ScrollView
          contentContainerStyle={styles.scroll}
          showsVerticalScrollIndicator={false}
        >
          <Text style={styles.emoji}>🎉</Text>
          <Text style={styles.title}>Welcome to Peepl!</Text>
          <Text style={styles.nameLine}>{displayName}</Text>

          {STEPS.map((line, i) => (
            <View key={i} style={styles.row}>
              <Icon name="check-circle" size={24} color="#FFFFFF" style={styles.check} />
              <Text style={styles.rowText}>{line}</Text>
            </View>
          ))}

          <TouchableOpacity style={styles.cta} onPress={goToFeed} activeOpacity={0.85}>
            <Text style={styles.ctaText}>Take me to the feed →</Text>
          </TouchableOpacity>
        </ScrollView>
      </SafeAreaView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  gradient: {
    flex: 1,
  },
  safe: {
    flex: 1,
  },
  scroll: {
    paddingHorizontal: 24,
    paddingTop: 48,
    paddingBottom: 40,
  },
  emoji: {
    fontSize: 72,
    textAlign: 'center',
    marginBottom: 24,
  },
  title: {
    color: '#FFFFFF',
    fontSize: 28,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 16,
  },
  nameLine: {
    color: '#FFC107',
    fontSize: 22,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 32,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 16,
  },
  check: {
    marginRight: 12,
    marginTop: 2,
  },
  rowText: {
    flex: 1,
    color: '#FFFFFF',
    fontSize: 16,
    lineHeight: 22,
  },
  cta: {
    backgroundColor: '#FFC107',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 24,
  },
  ctaText: {
    color: '#000000',
    fontSize: 16,
    fontWeight: 'bold',
  },
});
