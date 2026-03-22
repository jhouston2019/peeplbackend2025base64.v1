import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { authService } from '../../services/AuthService';
import { RootStackParamList } from '../../types/Navigation';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';

type Props = {
  route: RouteProp<RootStackParamList, 'MerchantAccountInfo'>;
  navigation: StackNavigationProp<RootStackParamList, 'MerchantAccountInfo'>;
};

export default function MerchantAccountInfoScreen({ route, navigation }: Props) {
  const { merchant } = route.params;
  const [totalSpent, setTotalSpent] = useState(0);

  const loadSpent = useCallback(async () => {
    try {
      const token = await authService.getIdToken();
      const res = await fetch(
        `${BASE_URL}/merchant/ads?merchantId=${encodeURIComponent(merchant.id)}`,
        {
          headers: {
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        }
      );
      const data = await res.json().catch(() => ({}));
      const ads = (data as { ads?: { totalCost?: number }[] }).ads ?? [];
      const sum = ads.reduce((acc, a) => acc + (Number(a.totalCost) || 0), 0);
      setTotalSpent(sum);
    } catch {
      setTotalSpent(0);
    }
  }, [merchant.id]);

  useEffect(() => {
    loadSpent();
  }, [loadSpent]);

  const last4 = merchant.paymentLast4;
  const payLabel =
    last4 != null && String(last4).length > 0
      ? `•••• ${String(last4)}`
      : 'Not set';

  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
          <Text style={styles.backText}>‹ Back</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Account</Text>
      </View>

      <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={styles.sectionTitle}>Business</Text>
        <Row label="Business Name" value={merchant.businessName || '—'} />
        <Row label="Merchant #" value={merchant.merchantNumber || '—'} />
        <Row label="Category" value={merchant.category || '—'} />
        <Row label="Address" value={[merchant.address, merchant.city].filter(Boolean).join(', ') || '—'} />

        <Text style={styles.sectionTitle}>Billing</Text>
        <Row label="Payment Method" value={payLabel} />
        <Row label="Billing Email" value={merchant.email || '—'} />
        <Row label="Total Spent" value={`$${totalSpent.toFixed(2)}`} />

        <TouchableOpacity
          onPress={() => Alert.alert('Invoices', 'Invoice download coming soon')}
          style={styles.linkRow}
        >
          <Text style={styles.link}>View invoices</Text>
        </TouchableOpacity>

        <Text style={styles.sectionTitle}>Rates Reference</Text>
        <View style={styles.ratesCard}>
          <Text style={styles.rateLine}>Basic: $10/hr — Standard reach</Text>
          <Text style={styles.rateLine}>Standard: $25/hr — 2× reach + highlighted</Text>
          <Text style={styles.rateLine}>Premium: $50/hr — Maximum reach + deal alerts</Text>
        </View>

        <Text style={styles.sectionTitle}>Support</Text>
        <TouchableOpacity
          onPress={() => Alert.alert('Help & Support', 'support@peepl.app')}
          style={styles.linkRow}
        >
          <Text style={styles.link}>Help & Support</Text>
        </TouchableOpacity>

        <Text style={styles.sectionTitle}>Danger zone</Text>
        <TouchableOpacity
          onPress={() => {
            Alert.alert(
              'Close merchant account',
              'This will permanently remove your merchant presence. Continue?',
              [
                { text: 'Cancel', style: 'cancel' },
                {
                  text: 'Close account',
                  style: 'destructive',
                  onPress: () => Alert.alert('Account closure', 'Account closure coming soon'),
                },
              ]
            );
          }}
        >
          <Text style={styles.danger}>Close merchant account</Text>
        </TouchableOpacity>
      </ScrollView>
    </View>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={styles.rowValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#ECEFF1' },
  header: {
    backgroundColor: '#1565C0',
    paddingTop: 48,
    paddingBottom: 16,
    paddingHorizontal: 16,
  },
  backBtn: { marginBottom: 8 },
  backText: { color: '#ffffff', fontSize: 17 },
  headerTitle: { color: '#ffffff', fontSize: 22, fontWeight: 'bold' },
  scroll: { padding: 16, paddingBottom: 40 },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#546E7A',
    marginTop: 16,
    marginBottom: 8,
  },
  row: {
    backgroundColor: '#ffffff',
    borderRadius: 8,
    padding: 14,
    marginBottom: 8,
  },
  rowLabel: { color: '#78909C', fontSize: 12 },
  rowValue: { color: '#263238', fontSize: 16, marginTop: 4 },
  linkRow: { paddingVertical: 10 },
  link: { color: '#1565C0', fontSize: 15, fontWeight: '600' },
  ratesCard: {
    backgroundColor: '#ffffff',
    borderRadius: 10,
    padding: 16,
    borderLeftWidth: 4,
    borderLeftColor: '#FFC107',
  },
  rateLine: { color: '#37474F', fontSize: 14, marginBottom: 8 },
  danger: { color: '#C62828', fontSize: 16, fontWeight: '600', marginTop: 8 },
});
