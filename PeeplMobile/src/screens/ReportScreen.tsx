import React, { useCallback, useState } from 'react';
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
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const PRIMARY = '#1565C0';
const GOLD = '#FFC107';

const OPTIONS: { reason: string; title: string; subtitle: string }[] = [
  {
    reason: 'inaccurate_crowd',
    title: 'Inaccurate crowd info',
    subtitle: "The crowd level or details don't match reality",
  },
  {
    reason: 'wrong_venue',
    title: 'Wrong venue',
    subtitle: 'This peep is tagged at the wrong location',
  },
  {
    reason: 'inappropriate',
    title: 'Inappropriate content',
    subtitle: 'Photo or notes contain offensive content',
  },
  {
    reason: 'spam',
    title: 'Spam',
    subtitle: 'This is repeated or irrelevant content',
  },
  {
    reason: 'other',
    title: 'Other',
    subtitle: 'Something else is wrong',
  },
];

type Props = {
  route: RouteProp<RootStackParamList, 'Report'>;
  navigation: StackNavigationProp<RootStackParamList, 'Report'>;
};

export default function ReportScreen({ route, navigation }: Props) {
  const { peepId } = route.params;
  const [selected, setSelected] = useState<string | null>(null);

  const submit = useCallback(async () => {
    if (!selected) return;
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/peeps/${peepId}/report`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ reason: selected }),
      });
      if (!res.ok) throw new Error('fail');
      Alert.alert(
        'Thank you',
        "Thank you for your report. We'll review it shortly."
      );
      setTimeout(() => navigation.goBack(), 2000);
    } catch {
      Alert.alert('Error', 'Could not submit report.');
    }
  }, [peepId, selected, navigation]);

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scroll}>
        {OPTIONS.map(opt => {
          const on = selected === opt.reason;
          return (
            <TouchableOpacity
              key={opt.reason}
              style={[styles.card, on && styles.cardSelected]}
              onPress={() => setSelected(opt.reason)}
              activeOpacity={0.85}
            >
              <View style={{ flex: 1 }}>
                <Text style={styles.cardTitle}>{opt.title}</Text>
                <Text style={styles.cardSub}>{opt.subtitle}</Text>
              </View>
              <Text style={styles.arrow}>›</Text>
            </TouchableOpacity>
          );
        })}
      </ScrollView>
      {selected ? (
        <TouchableOpacity style={styles.submitBtn} onPress={submit}>
          <Text style={styles.submitText}>Submit Report</Text>
        </TouchableOpacity>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f5f5' },
  scroll: { padding: 16, paddingBottom: 100 },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#e0e0e0',
  },
  cardSelected: { borderLeftWidth: 4, borderLeftColor: PRIMARY },
  cardTitle: { fontSize: 16, fontWeight: '600', color: '#222' },
  cardSub: { fontSize: 13, color: '#666', marginTop: 6 },
  arrow: { fontSize: 24, color: '#bbb', marginLeft: 8 },
  submitBtn: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: GOLD,
    paddingVertical: 16,
    alignItems: 'center',
  },
  submitText: { fontWeight: 'bold', fontSize: 17, color: '#111' },
});
