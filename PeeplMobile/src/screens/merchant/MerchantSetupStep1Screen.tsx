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
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import {
  MerchantSetupStep1Data,
  RootStackParamList,
} from '../../types/Navigation';

type Props = {
  route: RouteProp<RootStackParamList, 'MerchantSetupStep1'>;
  navigation: StackNavigationProp<RootStackParamList, 'MerchantSetupStep1'>;
};

const CATEGORIES: {
  key: MerchantSetupStep1Data['category'];
  label: string;
  emoji: string;
}[] = [
  { key: 'bar_pub', label: 'Bar / Pub', emoji: '🍺' },
  { key: 'restaurant', label: 'Restaurant', emoji: '🍽️' },
  { key: 'coffee', label: 'Coffee Shop', emoji: '☕' },
  { key: 'retail', label: 'Retail', emoji: '🛍️' },
  { key: 'services', label: 'Services', emoji: '🔧' },
  { key: 'entertainment', label: 'Entertainment', emoji: '🎭' },
  { key: 'other', label: 'Other', emoji: '📍' },
];

export default function MerchantSetupStep1Screen({ navigation }: Props) {
  const [businessName, setBusinessName] = useState('');
  const [address, setAddress] = useState('');
  const [city, setCity] = useState('');
  const [category, setCategory] = useState<MerchantSetupStep1Data['category'] | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});

  const validate = () => {
    const e: Record<string, string> = {};
    if (!businessName.trim()) e.businessName = 'Required';
    if (!address.trim()) e.address = 'Required';
    if (!city.trim()) e.city = 'Required';
    if (!category) e.category = 'Required';
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const onNext = () => {
    if (!validate()) return;
    const step1: MerchantSetupStep1Data = {
      businessName: businessName.trim(),
      address: address.trim(),
      city: city.trim(),
      category: category!,
    };
    navigation.navigate('MerchantSetupStep2', { step1 });
  };

  return (
    <LinearGradient colors={['#1565C0', '#0D47A1']} style={styles.gradient}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <View style={styles.progressTrack}>
            <View style={[styles.progressFill, { width: '33%' }]} />
          </View>
          <Text style={styles.stepLabel}>Step 1 of 3</Text>

          <Text style={styles.title}>Your Business</Text>

          <TextInput
            style={styles.input}
            placeholder="Business name"
            placeholderTextColor="#90A4AE"
            value={businessName}
            onChangeText={setBusinessName}
          />
          {errors.businessName ? (
            <Text style={styles.err}>{errors.businessName}</Text>
          ) : null}

          <TextInput
            style={styles.input}
            placeholder="Street address"
            placeholderTextColor="#90A4AE"
            value={address}
            onChangeText={setAddress}
          />
          {errors.address ? <Text style={styles.err}>{errors.address}</Text> : null}

          <TextInput
            style={styles.input}
            placeholder="City"
            placeholderTextColor="#90A4AE"
            value={city}
            onChangeText={setCity}
          />
          {errors.city ? <Text style={styles.err}>{errors.city}</Text> : null}

          <View style={styles.grid}>
            {CATEGORIES.map(c => {
              const selected = category === c.key;
              return (
                <TouchableOpacity
                  key={c.key}
                  style={[styles.card, selected && styles.cardSelected]}
                  onPress={() => setCategory(c.key)}
                  activeOpacity={0.85}
                >
                  <Text style={styles.cardEmoji}>{c.emoji}</Text>
                  <Text style={[styles.cardLabel, selected && styles.cardLabelSelected]}>
                    {c.label}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
          {errors.category ? <Text style={styles.err}>{errors.category}</Text> : null}

          <TouchableOpacity style={styles.goldBtn} onPress={onNext} activeOpacity={0.85}>
            <Text style={styles.goldBtnText}>Next →</Text>
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
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginTop: 8,
  },
  card: {
    width: '48%',
    backgroundColor: 'rgba(255,255,255,0.95)',
    borderRadius: 12,
    padding: 14,
    marginBottom: 12,
    borderWidth: 2,
    borderColor: 'transparent',
    alignItems: 'center',
  },
  cardSelected: {
    borderColor: '#1565C0',
    backgroundColor: 'rgba(227,242,253,0.95)',
  },
  cardEmoji: { fontSize: 28, marginBottom: 6 },
  cardLabel: { fontSize: 14, color: '#37474F', textAlign: 'center' },
  cardLabelSelected: { fontWeight: '700', color: '#0D47A1' },
  goldBtn: {
    backgroundColor: '#FFC107',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 16,
  },
  goldBtnText: { color: '#000000', fontSize: 17, fontWeight: '700' },
});
