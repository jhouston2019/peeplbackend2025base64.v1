import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
} from 'react-native';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../../types/Navigation';

type Props = {
  route: RouteProp<RootStackParamList, 'HowToAdvertise'>;
  navigation: StackNavigationProp<RootStackParamList, 'HowToAdvertise'>;
};

const STEPS: { n: string; title: string; body: string; icon: string }[] = [
  {
    n: '1',
    title: 'Create your offer',
    body: "Write a short offer (up to 40 characters). Keep it punchy — 'Half-price drinks until 10pm' works great.",
    icon: '✏️',
  },
  {
    n: '2',
    title: 'Pick your time slot',
    body: 'Choose when your ad runs. Start any time, end any time. You control the schedule.',
    icon: '🕐',
  },
  {
    n: '3',
    title: 'Choose your rate',
    body: 'Basic ($10/hr), Standard ($25/hr), or Premium ($50/hr). Higher rate = more reach and visibility.',
    icon: '💰',
  },
  {
    n: '4',
    title: 'Go live instantly',
    body: 'Your ad goes live at your chosen start time. No approval process, no waiting.',
    icon: '⚡',
  },
  {
    n: '5',
    title: 'See your results',
    body: 'Track impressions, deal claims, and claim rate in your activity dashboard.',
    icon: '📊',
  },
];

export default function HowToAdvertiseScreen({ navigation }: Props) {
  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
          <Text style={styles.backText}>‹ Back</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>How Advertising Works</Text>
      </View>

      <ScrollView contentContainerStyle={styles.scroll}>
        {STEPS.map(s => (
          <View key={s.n} style={styles.card}>
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{s.n}</Text>
            </View>
            <Text style={styles.icon}>{s.icon}</Text>
            <Text style={styles.cardTitle}>{s.title}</Text>
            <Text style={styles.cardBody}>{s.body}</Text>
          </View>
        ))}

        <TouchableOpacity
          style={styles.cta}
          onPress={() => navigation.navigate('MerchantSignIn')}
          activeOpacity={0.85}
        >
          <Text style={styles.ctaText}>Start Advertising →</Text>
        </TouchableOpacity>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#ffffff' },
  header: {
    backgroundColor: '#1565C0',
    paddingTop: 48,
    paddingBottom: 16,
    paddingHorizontal: 16,
  },
  backBtn: { marginBottom: 8 },
  backText: { color: '#ffffff', fontSize: 17 },
  headerTitle: { color: '#ffffff', fontSize: 20, fontWeight: 'bold' },
  scroll: { padding: 16, paddingBottom: 40 },
  card: {
    backgroundColor: '#FAFAFA',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#ECEFF1',
  },
  badge: {
    position: 'absolute',
    top: 12,
    right: 12,
    backgroundColor: '#1565C0',
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeText: { color: '#fff', fontWeight: 'bold', fontSize: 14 },
  icon: { fontSize: 28, marginBottom: 8 },
  cardTitle: { fontSize: 17, fontWeight: 'bold', color: '#0D47A1', marginBottom: 8 },
  cardBody: { fontSize: 14, color: '#546E7A', lineHeight: 21 },
  cta: {
    backgroundColor: '#FFC107',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 16,
  },
  ctaText: { color: '#000000', fontSize: 17, fontWeight: '700' },
});
