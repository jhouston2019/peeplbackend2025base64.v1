import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Share,
  SafeAreaView,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import { CommonActions } from '@react-navigation/native';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';

type PioneerCongratScreenProps = {
  route: RouteProp<RootStackParamList, 'PioneerCongrats'>;
  navigation: StackNavigationProp<RootStackParamList, 'PioneerCongrats'>;
};

export default function PioneerCongratScreen({ route, navigation }: PioneerCongratScreenProps) {
  const { venueName, venuesPioneedCount } = route.params;

  const backToFeed = () => {
    navigation.dispatch(
      CommonActions.reset({
        index: 0,
        routes: [{ name: 'MainTabs' }],
      })
    );
  };

  const sharePioneer = async () => {
    try {
      await Share.share({
        message: `I just became the first Pioneer at ${venueName} on Peepl! 🌟 #PeeplPioneer`,
      });
    } catch {
      // ignore share errors
    }
  };

  return (
    <LinearGradient colors={['#1565C0', '#0D47A1']} style={styles.gradient}>
      <SafeAreaView style={styles.safe}>
        <View style={styles.content}>
          <Text style={styles.star}>⭐</Text>

          <View style={styles.badge}>
            <Text style={styles.badgeText}>Pioneer</Text>
          </View>

          <Text style={styles.title}>{"You're a Peepl Pioneer!"}</Text>
          <Text style={styles.venueName}>{venueName}</Text>

          <View style={styles.statsRow}>
            <View style={styles.statCard}>
              <Text style={styles.statNumber}>1</Text>
              <Text style={styles.statLabel}>1st Pioneer</Text>
            </View>
            <View style={styles.statCard}>
              <Text style={styles.statNumber}>{venuesPioneedCount}</Text>
              <Text style={styles.statLabel}>Venues Pioneered</Text>
            </View>
            <View style={styles.statCard}>
              <Text style={styles.statNumber}>+50</Text>
              <Text style={styles.statLabel}>pts for this discovery</Text>
            </View>
          </View>

          <TouchableOpacity style={styles.primaryBtn} onPress={backToFeed} activeOpacity={0.85}>
            <Text style={styles.primaryBtnText}>Back to Feed</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.outlineBtn} onPress={sharePioneer} activeOpacity={0.85}>
            <Text style={styles.outlineBtnText}>Share your Pioneer status</Text>
          </TouchableOpacity>
        </View>
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
  content: {
    flex: 1,
    paddingHorizontal: 24,
    justifyContent: 'center',
    alignItems: 'center',
  },
  star: {
    fontSize: 80,
    textAlign: 'center',
    marginBottom: 16,
  },
  badge: {
    backgroundColor: '#FFC107',
    paddingHorizontal: 20,
    paddingVertical: 8,
    borderRadius: 999,
    marginBottom: 20,
  },
  badgeText: {
    color: '#000000',
    fontWeight: 'bold',
    fontSize: 16,
  },
  title: {
    color: '#FFFFFF',
    fontSize: 28,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 12,
  },
  venueName: {
    color: '#FFC107',
    fontSize: 20,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 28,
  },
  statsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
    marginBottom: 32,
  },
  statCard: {
    flex: 1,
    marginHorizontal: 4,
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderRadius: 12,
    paddingVertical: 14,
    paddingHorizontal: 6,
    alignItems: 'center',
  },
  statNumber: {
    color: '#FFFFFF',
    fontSize: 22,
    fontWeight: 'bold',
    marginBottom: 6,
  },
  statLabel: {
    color: '#FFFFFF',
    fontSize: 11,
    textAlign: 'center',
    lineHeight: 14,
  },
  primaryBtn: {
    width: '100%',
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    marginBottom: 12,
  },
  primaryBtnText: {
    color: '#1565C0',
    fontSize: 16,
    fontWeight: 'bold',
  },
  outlineBtn: {
    width: '100%',
    borderWidth: 2,
    borderColor: '#FFFFFF',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  outlineBtnText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
});
