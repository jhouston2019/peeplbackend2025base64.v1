import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Image,
  TouchableOpacity,
  ScrollView,
} from 'react-native';
import KeepAwake from 'react-native-keep-awake';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';

type Props = {
  route: RouteProp<RootStackParamList, 'DealClaimed'>;
  navigation: StackNavigationProp<RootStackParamList, 'DealClaimed'>;
};

function formatRemaining(ms: number): string {
  if (ms <= 0) return '00:00:00';
  const totalSec = Math.floor(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

export default function DealClaimedScreen({ route }: Props) {
  const { deal } = route.params;
  const [now, setNow] = useState(Date.now());
  const [keepScreenOn, setKeepScreenOn] = useState(false);

  const postClaim = useCallback(async () => {
    try {
      const token = await authService.getIdToken();
      await fetch(`${BASE_URL}/merchant/ads/${deal.adId}/claim`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
    } catch {
      // claim recording best-effort
    }
  }, [deal.adId]);

  useEffect(() => {
    postClaim();
  }, [postClaim]);

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    return () => {
      setKeepScreenOn(false);
      const KA = KeepAwake as unknown as { deactivate?: () => void };
      KA.deactivate?.();
    };
  }, []);

  const endMs = new Date(deal.expiresAt).getTime();
  const remaining = endMs - now;
  const expired = remaining <= 0;

  const onShowStaffPress = () => {
    const KA = KeepAwake as unknown as { activate?: () => void };
    KA.activate?.();
    setKeepScreenOn(true);
  };

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollContent}>
      {keepScreenOn ? <KeepAwake /> : null}
      <View style={styles.heroWrap}>
        <Image source={{ uri: deal.venueImageUrl }} style={styles.hero} resizeMode="cover" />
        <View style={styles.stampOuter}>
          <View style={styles.stamp}>
            <Text style={styles.stampText}>DEAL CLAIMED ✓</Text>
          </View>
        </View>
      </View>

      <View style={styles.blueSection}>
        <Text style={styles.merchantName}>{deal.merchantName}</Text>
        <Text style={styles.offerText}>{deal.offerText}</Text>
        <Text style={styles.instruction}>Show this screen to your server</Text>

        {expired ? (
          <Text style={styles.expiredText}>This deal has expired</Text>
        ) : (
          <Text style={styles.countdownLabel}>
            Expires in {formatRemaining(remaining)}
          </Text>
        )}

        <TouchableOpacity style={styles.cta} onPress={onShowStaffPress} activeOpacity={0.85}>
          <Text style={styles.ctaText}>Show staff this screen</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    flex: 1,
    backgroundColor: '#1565C0',
  },
  scrollContent: {
    paddingBottom: 32,
  },
  heroWrap: {
    height: 200,
    width: '100%',
    position: 'relative',
  },
  hero: {
    width: '100%',
    height: 200,
  },
  stampOuter: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
  },
  stamp: {
    backgroundColor: '#FFC107',
    paddingHorizontal: 16,
    paddingVertical: 12,
    transform: [{ rotate: '-12deg' }],
    borderWidth: 2,
    borderColor: '#000000',
  },
  stampText: {
    color: '#000000',
    fontSize: 24,
    fontWeight: 'bold',
  },
  blueSection: {
    padding: 20,
  },
  merchantName: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 8,
  },
  offerText: {
    color: '#FFFFFF',
    fontSize: 16,
    textAlign: 'center',
    marginBottom: 16,
  },
  instruction: {
    color: '#FFC107',
    fontSize: 15,
    fontStyle: 'italic',
    textAlign: 'center',
    marginBottom: 12,
  },
  countdownLabel: {
    color: '#FFFFFF',
    fontSize: 18,
    textAlign: 'center',
    marginBottom: 16,
  },
  expiredText: {
    color: '#F44336',
    fontSize: 18,
    textAlign: 'center',
    marginBottom: 16,
    fontWeight: '600',
  },
  cta: {
    backgroundColor: '#FFC107',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 8,
  },
  ctaText: {
    color: '#000000',
    fontSize: 16,
    fontWeight: 'bold',
  },
});
