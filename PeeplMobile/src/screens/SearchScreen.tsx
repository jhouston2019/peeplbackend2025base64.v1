import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  Image,
  ActivityIndicator,
  ScrollView,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';
import { Venue } from '../types/Venue';
import { locationService } from '../services/LocationService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';
const RECENT_KEY = 'recentSearches';

type Nav = StackNavigationProp<RootStackParamList, 'Search'>;

type Props = { navigation: Nav };

type VenueHit = {
  id: string;
  name: string;
  category?: string;
  imageUrl?: string;
  distance?: number;
  crowdSize?: number;
};

type UserHit = {
  id: string;
  username: string;
  profileImageUrl?: string;
  pioneerCount?: number;
};

function crowdColor(size: number): string {
  if (size <= 2) return '#4CAF50';
  if (size === 3) return '#FFA726';
  return '#F44336';
}

export default function SearchScreen({ navigation }: Props) {
  const [q, setQ] = useState('');
  const [loading, setLoading] = useState(false);
  const [venues, setVenues] = useState<VenueHit[]>([]);
  const [users, setUsers] = useState<UserHit[]>([]);
  const [recent, setRecent] = useState<string[]>([]);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const inputRef = useRef<TextInput>(null);

  const loadRecent = useCallback(async () => {
    const raw = await AsyncStorage.getItem(RECENT_KEY);
    if (raw) {
      try {
        setRecent(JSON.parse(raw));
      } catch {
        setRecent([]);
      }
    }
  }, []);

  useEffect(() => {
    loadRecent();
    const t = setTimeout(() => inputRef.current?.focus(), 100);
    return () => clearTimeout(t);
  }, [loadRecent]);

  const saveRecent = async (term: string) => {
    const t = term.trim();
    if (t.length < 2) return;
    setRecent(prev => {
      const next = [t, ...prev.filter(x => x.toLowerCase() !== t.toLowerCase())].slice(0, 5);
      AsyncStorage.setItem(RECENT_KEY, JSON.stringify(next)).catch(() => {});
      return next;
    });
  };

  const clearRecent = async () => {
    setRecent([]);
    await AsyncStorage.removeItem(RECENT_KEY);
  };

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (!q.trim() || q.trim().length < 2) {
      setVenues([]);
      setUsers([]);
      return;
    }
    debounceRef.current = setTimeout(async () => {
      setLoading(true);
      try {
        const token = await authService.getIdToken();
        const headers: Record<string, string> = {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        };
        const term = encodeURIComponent(q.trim());
        const [vRes, uRes] = await Promise.all([
          fetch(`${BASE_URL}/search/venues?q=${term}`, { headers }),
          fetch(`${BASE_URL}/search/users?q=${term}`, { headers }),
        ]);
        const vJson = vRes.ok ? await vRes.json() : { venues: [] };
        const uJson = uRes.ok ? await uRes.json() : { users: [] };
        const vRaw = vJson.venues || [];
        const loc = await locationService.getCurrentLocation();
        setVenues(
          vRaw.map((v: Record<string, unknown>) => {
            const lat = Number(v.lat ?? v.latitude ?? 0);
            const lng = Number(v.lng ?? v.longitude ?? 0);
            let distance: number | undefined;
            if (loc && lat && lng) {
              const R = 3959;
              const dLat = ((lat - loc.latitude) * Math.PI) / 180;
              const dLng = ((lng - loc.longitude) * Math.PI) / 180;
              const a =
                Math.sin(dLat / 2) ** 2 +
                Math.cos((loc.latitude * Math.PI) / 180) *
                  Math.cos((lat * Math.PI) / 180) *
                  Math.sin(dLng / 2) ** 2;
              distance = 2 * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
            }
            return {
              id: String(v.id ?? ''),
              name: String(v.name ?? ''),
              category: v.category ? String(v.category) : '',
              imageUrl: v.imageUrl ? String(v.imageUrl) : undefined,
              distance,
              crowdSize: v.crowdSize != null ? Number(v.crowdSize) : undefined,
            };
          })
        );
        setUsers(
          (uJson.users || []).map((u: Record<string, unknown>) => ({
            id: String(u.id ?? ''),
            username: String(u.username ?? ''),
            profileImageUrl: u.profileImageUrl ? String(u.profileImageUrl) : undefined,
            pioneerCount: u.pioneerCount != null ? Number(u.pioneerCount) : 0,
          }))
        );
      } catch {
        setVenues([]);
        setUsers([]);
      } finally {
        setLoading(false);
      }
    }, 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [q]);

  const submitSearch = () => {
    saveRecent(q);
  };

  const goVenue = (v: VenueHit) => {
    const venue: Venue = {
      id: v.id,
      name: v.name,
      address: '',
      latitude: 0,
      longitude: 0,
      category: v.category || '',
      createdBy: '',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      isActive: true,
      peepCount: 0,
      averageRating: 0,
      totalRatings: 0,
      imageUrl: v.imageUrl,
    };
    navigation.navigate('Venue', { venue });
  };

  const emptyQuery = !q.trim();

  return (
    <ScrollView style={styles.container} keyboardShouldPersistTaps="handled">
      <TextInput
        ref={inputRef}
        style={styles.input}
        placeholder="Search venues and people"
        placeholderTextColor="#999"
        value={q}
        onChangeText={setQ}
        onSubmitEditing={submitSearch}
        returnKeyType="search"
      />
      {loading ? <ActivityIndicator color={ACCENT} style={{ marginTop: 8 }} /> : null}

      {emptyQuery && recent.length > 0 ? (
        <View style={styles.recentBlock}>
          <View style={styles.recentHeader}>
            <Text style={styles.recentTitle}>Recent</Text>
            <TouchableOpacity onPress={clearRecent}>
              <Text style={styles.clear}>Clear</Text>
            </TouchableOpacity>
          </View>
          {recent.map(term => (
            <TouchableOpacity
              key={term}
              style={styles.recentRow}
              onPress={() => setQ(term)}
            >
              <Text>{term}</Text>
            </TouchableOpacity>
          ))}
        </View>
      ) : null}

      {!emptyQuery && venues.length > 0 ? (
        <>
          <Text style={styles.sec}>Venues</Text>
          {venues.map(item => (
            <TouchableOpacity key={item.id} style={styles.vRow} onPress={() => goVenue(item)}>
              <Image
                source={{ uri: item.imageUrl || 'https://via.placeholder.com/80' }}
                style={styles.vThumb}
              />
              <View style={{ flex: 1 }}>
                <Text style={styles.vName}>{item.name}</Text>
                <Text style={styles.vMeta}>
                  {item.category}
                  {item.distance != null ? ` · ${item.distance.toFixed(1)} mi` : ''}
                </Text>
              </View>
              {item.crowdSize != null ? (
                <View style={[styles.pill, { backgroundColor: crowdColor(item.crowdSize) }]}>
                  <Text style={styles.pillText}>{item.crowdSize}</Text>
                </View>
              ) : null}
            </TouchableOpacity>
          ))}
        </>
      ) : null}

      {!emptyQuery && users.length > 0 ? (
        <>
          <Text style={styles.sec}>People</Text>
          {users.map(item => (
            <TouchableOpacity
              key={item.id}
              style={styles.uRow}
              onPress={() => navigation.navigate('UserProfile', { userId: item.id })}
            >
              <Image
                source={{ uri: item.profileImageUrl || 'https://via.placeholder.com/80' }}
                style={styles.uAv}
              />
              <Text style={styles.uName}>
                {item.username}
                {(item.pioneerCount || 0) > 0 ? ' ⭐' : ''}
              </Text>
              <Text style={styles.follow}>Follow</Text>
            </TouchableOpacity>
          ))}
        </>
      ) : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff', padding: 12 },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 10,
    padding: 12,
    fontSize: 16,
  },
  recentBlock: { marginTop: 16 },
  recentHeader: { flexDirection: 'row', justifyContent: 'space-between' },
  recentTitle: { fontWeight: 'bold', color: PRIMARY },
  clear: { color: '#c62828' },
  recentRow: { paddingVertical: 10, borderBottomWidth: StyleSheet.hairlineWidth, borderColor: '#eee' },
  sec: { fontWeight: 'bold', fontSize: 16, marginTop: 16, marginBottom: 8, color: PRIMARY },
  vRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10 },
  vThumb: { width: 40, height: 40, borderRadius: 20, marginRight: 12 },
  vName: { fontWeight: 'bold' },
  vMeta: { color: '#888', fontSize: 13, marginTop: 2 },
  pill: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 12 },
  pillText: { color: '#fff', fontWeight: 'bold' },
  uRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10 },
  uAv: { width: 40, height: 40, borderRadius: 20, marginRight: 12 },
  uName: { flex: 1, fontWeight: 'bold' },
  follow: { color: PRIMARY, fontWeight: '600' },
});
