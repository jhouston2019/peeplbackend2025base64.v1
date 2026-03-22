import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
  Alert,
  ActivityIndicator,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { authService } from '../../services/AuthService';
import { RootStackParamList } from '../../types/Navigation';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';

type Props = {
  route: RouteProp<RootStackParamList, 'MerchantSetupStep2'>;
  navigation: StackNavigationProp<RootStackParamList, 'MerchantSetupStep2'>;
};

export default function MerchantSetupStep2Screen({ route, navigation }: Props) {
  const { step1 } = route.params;
  const [contactName, setContactName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);

  const validate = () => {
    const e: Record<string, string> = {};
    if (!contactName.trim()) e.contactName = 'Required';
    if (!email.trim()) e.email = 'Required';
    if (!phone.trim()) e.phone = 'Required';
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const onNext = async () => {
    if (!validate()) return;
    setLoading(true);
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/merchant/setup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          businessName: step1.businessName,
          category: step1.category,
          address: step1.address,
          city: step1.city,
          contactName: contactName.trim(),
          email: email.trim(),
          phone: phone.trim(),
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        Alert.alert('Setup', (data as { error?: string }).error || 'Setup failed');
        return;
      }
      const { merchantId, merchantNumber } = data as {
        merchantId: string;
        merchantNumber: string;
      };
      navigation.navigate('MerchantAccountNumber', {
        merchantId,
        merchantNumber,
        businessName: step1.businessName,
        address: step1.address,
        city: step1.city,
        category: step1.category,
        contactName: contactName.trim(),
        email: email.trim(),
        phone: phone.trim(),
      });
    } catch {
      Alert.alert('Setup', 'Network error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <LinearGradient colors={['#1565C0', '#0D47A1']} style={styles.gradient}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <View style={styles.progressTrack}>
            <View style={[styles.progressFill, { width: '66%' }]} />
          </View>
          <Text style={styles.stepLabel}>Step 2 of 3</Text>

          <Text style={styles.title}>Contact & Billing</Text>

          <TextInput
            style={styles.input}
            placeholder="Contact name"
            placeholderTextColor="#90A4AE"
            value={contactName}
            onChangeText={setContactName}
          />
          {errors.contactName ? (
            <Text style={styles.err}>{errors.contactName}</Text>
          ) : null}

          <TextInput
            style={styles.input}
            placeholder="Email"
            placeholderTextColor="#90A4AE"
            keyboardType="email-address"
            autoCapitalize="none"
            value={email}
            onChangeText={setEmail}
          />
          {errors.email ? <Text style={styles.err}>{errors.email}</Text> : null}

          <TextInput
            style={styles.input}
            placeholder="Phone"
            placeholderTextColor="#90A4AE"
            keyboardType="phone-pad"
            value={phone}
            onChangeText={setPhone}
          />
          {errors.phone ? <Text style={styles.err}>{errors.phone}</Text> : null}

          <Text style={styles.payTitle}>Payment Method</Text>
          {/* TODO: Replace with @stripe/stripe-react-native CardField in Task 68. */}
          <View style={styles.payPlaceholder}>
            <Text style={styles.payPlaceholderText}>
              💳 Stripe card entry will appear here
            </Text>
          </View>

          <Text style={styles.rateNote}>
            You are only charged for active ad time — no minimums, no commitments.{'\n'}
            Basic: $10/hr • Standard: $25/hr • Premium: $50/hr
          </Text>

          <TouchableOpacity
            style={styles.goldBtn}
            onPress={onNext}
            disabled={loading}
            activeOpacity={0.85}
          >
            {loading ? (
              <ActivityIndicator color="#000" />
            ) : (
              <Text style={styles.goldBtnText}>Next →</Text>
            )}
          </TouchableOpacity>
        </ScrollView>
      </KeyboardAvoidingView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  gradient: { flex: 1 },
  flex: { flex: 1 },
  scroll: { padding: 20, paddingBottom: 40 },
  progressTrack: {
    height: 4,
    backgroundColor: 'rgba(255,255,255,0.25)',
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: { height: '100%', backgroundColor: '#42A5F5' },
  stepLabel: { color: '#E3F2FD', fontSize: 13, marginTop: 8, marginBottom: 16 },
  title: {
    color: '#ffffff',
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  input: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    fontSize: 16,
    marginBottom: 6,
  },
  err: { color: '#FFCDD2', fontSize: 13, marginBottom: 8 },
  payTitle: {
    color: '#ffffff',
    fontWeight: 'bold',
    fontSize: 17,
    marginTop: 12,
    marginBottom: 10,
  },
  payPlaceholder: {
    backgroundColor: '#ECEFF1',
    borderRadius: 12,
    padding: 20,
    alignItems: 'center',
  },
  payPlaceholderText: { color: '#546E7A', fontSize: 15 },
  rateNote: {
    color: '#ffffff',
    fontSize: 13,
    textAlign: 'center',
    marginTop: 20,
    lineHeight: 20,
  },
  goldBtn: {
    backgroundColor: '#FFC107',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 24,
    minHeight: 52,
    justifyContent: 'center',
  },
  goldBtnText: { color: '#000000', fontSize: 17, fontWeight: '700' },
});
