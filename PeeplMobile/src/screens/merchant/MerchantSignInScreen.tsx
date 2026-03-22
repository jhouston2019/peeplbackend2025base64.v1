import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Alert,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { MerchantDoc, RootStackParamList } from '../../types/Navigation';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';

type Props = {
  route: RouteProp<RootStackParamList, 'MerchantSignIn'>;
  navigation: StackNavigationProp<RootStackParamList, 'MerchantSignIn'>;
};

export default function MerchantSignInScreen({ navigation }: Props) {
  const [merchantNumber, setMerchantNumber] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const onSignIn = async () => {
    setLoading(true);
    try {
      const res = await fetch(`${BASE_URL}/merchant/signin`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ merchantNumber: merchantNumber.trim(), password }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        Alert.alert('Sign in', (data as { error?: string }).error || 'Could not sign in');
        return;
      }
      const merchant = (data as { merchant: MerchantDoc }).merchant;
      navigation.navigate('MerchantPortal', { merchant });
    } catch {
      Alert.alert('Sign in', 'Network error');
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
          <Text style={styles.logo}>Peepl</Text>
          <Text style={styles.subtitle}>Merchant Portal</Text>

          <TextInput
            style={styles.input}
            placeholder="Merchant #"
            placeholderTextColor="#90A4AE"
            keyboardType="numeric"
            value={merchantNumber}
            onChangeText={setMerchantNumber}
            autoCapitalize="none"
          />
          <TextInput
            style={styles.input}
            placeholder="Password"
            placeholderTextColor="#90A4AE"
            secureTextEntry
            value={password}
            onChangeText={setPassword}
          />

          <TouchableOpacity
            style={styles.goldBtn}
            onPress={onSignIn}
            disabled={loading}
            activeOpacity={0.85}
          >
            <Text style={styles.goldBtnText}>Sign In to Portal</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.outlineBtn}
            onPress={() => navigation.navigate('MerchantSetupStep1')}
            activeOpacity={0.85}
          >
            <Text style={styles.outlineBtnText}>Set Up Merchant Account</Text>
          </TouchableOpacity>

          <TouchableOpacity
            onPress={() => navigation.navigate('HowToAdvertise')}
            style={styles.linkWrap}
          >
            <Text style={styles.link}>How to Advertise on Peepl</Text>
          </TouchableOpacity>
        </ScrollView>
      </KeyboardAvoidingView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  gradient: { flex: 1 },
  flex: { flex: 1 },
  scroll: {
    flexGrow: 1,
    paddingHorizontal: 24,
    paddingTop: 48,
    paddingBottom: 32,
    justifyContent: 'center',
  },
  logo: {
    color: '#ffffff',
    fontSize: 52,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  subtitle: {
    color: '#ffffff',
    fontSize: 16,
    fontStyle: 'italic',
    textAlign: 'center',
    marginBottom: 32,
  },
  input: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    fontSize: 16,
    marginBottom: 12,
  },
  goldBtn: {
    backgroundColor: '#FFC107',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 8,
  },
  goldBtnText: { color: '#000000', fontSize: 17, fontWeight: '700' },
  outlineBtn: {
    marginTop: 16,
    borderWidth: 2,
    borderColor: '#ffffff',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  outlineBtnText: { color: '#ffffff', fontSize: 16, fontWeight: '600' },
  linkWrap: { marginTop: 24, alignItems: 'center' },
  link: { color: '#E3F2FD', fontSize: 15, textDecorationLine: 'underline' },
});
