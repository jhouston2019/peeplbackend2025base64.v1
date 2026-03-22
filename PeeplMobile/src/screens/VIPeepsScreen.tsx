import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
  ActivityIndicator,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';
import analytics from '../services/AnalyticsService';

const PRIMARY = '#1565C0';
const GOLD = '#FFC107';

type VipUser = {
  isVIP?: boolean;
  subscriptionRenewalDate?: string;
  paymentLast4?: string;
  adsHiddenCount?: number;
  dealAlertsReceived?: number;
  crowdGraphsViewed?: number;
  createdAt?: string;
};

type Props = {
  navigation: StackNavigationProp<RootStackParamList, 'VIPeeps'>;
};

function formatDate(iso?: string): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function parseCreated(raw: unknown): string | undefined {
  if (raw == null) return undefined;
  if (typeof raw === 'string') return raw;
  if (typeof raw === 'object' && raw !== null && 'seconds' in raw) {
    return new Date((raw as { seconds: number }).seconds * 1000).toISOString();
  }
  return undefined;
}

export default function VIPeepsScreen({ navigation }: Props) {
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<VipUser | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const u = await authService.getCurrentUser();
      const raw = u as unknown as Record<string, unknown>;
      setUser({
        isVIP: raw.isVIP === true,
        subscriptionRenewalDate: raw.subscriptionRenewalDate as string | undefined,
        paymentLast4: raw.paymentLast4 as string | undefined,
        adsHiddenCount: Number(raw.adsHiddenCount ?? 0),
        dealAlertsReceived: Number(raw.dealAlertsReceived ?? 0),
        crowdGraphsViewed: Number(raw.crowdGraphsViewed ?? 0),
        createdAt: parseCreated(raw.createdAt) ?? (u as { createdAt?: string })?.createdAt,
      });
    } catch {
      setUser({ isVIP: false });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={GOLD} size="large" />
      </View>
    );
  }

  const isVip = user?.isVIP === true;

  if (isVip) {
    return (
      <ScrollView style={styles.flex}>
        <LinearGradient colors={['#1565C0', '#0D47A1']} style={styles.gradHeader}>
          <TouchableOpacity style={styles.backBtn} onPress={() => navigation.goBack()} hitSlop={12}>
            <Text style={styles.backText}>‹ Back</Text>
          </TouchableOpacity>
        </LinearGradient>
        <View style={styles.activeBody}>
          <View style={styles.badge}>
            <Text style={styles.badgeText}>VIPeeps Active ✓</Text>
          </View>
          <Text style={styles.crownSmall}>👑</Text>
          <View style={styles.grid}>
            <View style={styles.statCard}>
              <Text style={styles.statVal}>{user?.adsHiddenCount ?? 0}</Text>
              <Text style={styles.statLabel}>Ads hidden</Text>
            </View>
            <View style={styles.statCard}>
              <Text style={styles.statVal}>{user?.dealAlertsReceived ?? 0}</Text>
              <Text style={styles.statLabel}>Deal alerts received</Text>
            </View>
            <View style={styles.statCard}>
              <Text style={styles.statVal}>{user?.crowdGraphsViewed ?? 0}</Text>
              <Text style={styles.statLabel}>Crowd graphs viewed</Text>
            </View>
            <View style={styles.statCard}>
              <Text style={styles.statValSmall}>{formatDate(user?.createdAt)}</Text>
              <Text style={styles.statLabel}>Member since</Text>
            </View>
          </View>
          <Text style={styles.billTitle}>Billing</Text>
          <Text style={styles.billLine}>
            Next billing date: {formatDate(user?.subscriptionRenewalDate)}
          </Text>
          <Text style={styles.billLine}>
            Payment method: •••• {user?.paymentLast4 || '0000'}
          </Text>
          <TouchableOpacity
            onPress={() =>
              Alert.alert(
                'Cancel subscription',
                'Cancellation coming with full Stripe integration in Task 68'
              )
            }
          >
            <Text style={styles.cancel}>Cancel subscription</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    );
  }

  return (
    <View style={styles.flex}>
      <LinearGradient colors={['#1565C0', '#0D47A1']} style={styles.gradUpsell}>
        <TouchableOpacity style={styles.backBtn} onPress={() => navigation.goBack()} hitSlop={12}>
          <Text style={styles.backText}>‹ Back</Text>
        </TouchableOpacity>
        <Text style={styles.crown}>👑</Text>
        <Text style={styles.title}>VIPeeps</Text>
        <Text style={styles.price}>$4.99 / month</Text>
        <View style={styles.featureBlock}>
          {[
            'No ads — ever',
            'Crowd history graphs for any venue',
            'Deal alerts before everyone else',
            'Advanced crowd filters',
          ].map(line => (
            <Text key={line} style={styles.featureLine}>
              ✓ {line}
            </Text>
          ))}
        </View>
        <TouchableOpacity
          style={styles.cta}
          onPress={() => {
            analytics.track('vipeeps_started');
            Alert.alert('VIPeeps', 'Stripe integration coming in Task 68');
          }}
        >
          <Text style={styles.ctaText}>Start VIPeeps — $4.99/mo</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.secondaryWrap}>
          <Text style={styles.secondary}>Stay on free plan</Text>
        </TouchableOpacity>
      </LinearGradient>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: '#fff' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  gradUpsell: {
    flex: 1,
    paddingTop: 48,
    paddingHorizontal: 24,
    paddingBottom: 40,
  },
  gradHeader: { paddingTop: 48, paddingHorizontal: 16, paddingBottom: 16 },
  backBtn: { alignSelf: 'flex-start', marginBottom: 8 },
  backText: { color: '#fff', fontSize: 18, fontWeight: '600' },
  crown: { fontSize: 64, textAlign: 'center', marginTop: 16 },
  crownSmall: { fontSize: 48, textAlign: 'center', marginVertical: 12 },
  title: { color: '#fff', fontSize: 32, fontWeight: 'bold', textAlign: 'center' },
  price: { color: GOLD, fontSize: 24, textAlign: 'center', marginTop: 12, fontWeight: '600' },
  featureBlock: { marginTop: 32 },
  featureLine: { color: '#fff', fontSize: 16, marginBottom: 14 },
  cta: {
    marginTop: 32,
    backgroundColor: GOLD,
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  ctaText: { color: '#111', fontWeight: 'bold', fontSize: 17 },
  secondaryWrap: { marginTop: 20, alignItems: 'center' },
  secondary: { color: '#B0BEC5', fontSize: 14 },
  activeBody: { padding: 20 },
  badge: {
    alignSelf: 'center',
    backgroundColor: GOLD,
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 24,
  },
  badgeText: { fontWeight: 'bold', fontSize: 18, color: '#111' },
  grid: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', marginTop: 20 },
  statCard: {
    width: '48%',
    backgroundColor: '#f5f5f5',
    borderRadius: 12,
    padding: 14,
    marginBottom: 12,
  },
  statVal: { fontSize: 22, fontWeight: 'bold', color: PRIMARY },
  statValSmall: { fontSize: 14, fontWeight: '600', color: '#333' },
  statLabel: { fontSize: 12, color: '#666', marginTop: 6 },
  billTitle: { fontWeight: 'bold', fontSize: 16, marginTop: 16, color: '#333' },
  billLine: { fontSize: 14, color: '#555', marginTop: 8 },
  cancel: { color: '#c62828', marginTop: 20, fontSize: 16, fontWeight: '600' },
});
