import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  ImageBackground,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
  LayoutAnimation,
  Platform,
  UIManager,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import Icon from 'react-native-vector-icons/MaterialIcons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';
import { locationService } from '../services/LocationService';
import { Venue } from '../types/Venue';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const ACCENT = '#FFC107';

const CROWD_ALERT_PREFIX = 'crowdAlert:';

type FavRow = {
  venueId: string;
  name?: string;
  imageUrl?: string;
  currentCrowdSize?: number | null;
  lastPeepAt?: string | { seconds?: number } | null;
};

type Nav = StackNavigationProp<RootStackParamList, 'Favorites'>;

type Props = { navigation: Nav };

if (Platform.OS === 'android') {
  UIManager.setLayoutAnimationEnabledExperimental?.(true);
}

function crowdColor(size: number): string {
  if (size <= 2) return '#4CAF50';
  if (size === 3) return '#FFA726';
  return '#F44336';
}

function formatAgo(raw: FavRow['lastPeepAt']): string {
  if (!raw) return '—';
  let ms: number;
  if (typeof raw === 'string') {
    ms = new Date(raw).getTime();
  } else if (raw && typeof raw === 'object' && 'seconds' in raw && raw.seconds != null) {
    ms = Number(raw.seconds) * 1000;
  } else {
    return '—';
  }
  if (Number.isNaN(ms)) return '—';
  const diff = Date.now() - ms;
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'Just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

function distMi(
  lat1: number,
  lng1: number,
  lat2?: number,
  lng2?: number
): string {
  if (lat2 == null || lng2 == null) return '';
  const R = 3959;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const mi = R * c;
  return `${mi.toFixed(1)} mi`;
}

export default function FavoritesScreen({ navigation }: Props) {
  const [rows, setRows] = useState<FavRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [userPos, setUserPos] = useState<{ lat: number; lng: number } | null>(null);
  const [alerts, setAlerts] = useState<Record<string, boolean>>({});

  const loadAlerts = useCallback(async (list: FavRow[]) => {
    const next: Record<string, boolean> = {};
    await Promise.all(
      list.map(async v => {
        const raw = await AsyncStorage.getItem(`${CROWD_ALERT_PREFIX}${v.venueId}`);
        next[v.venueId] = raw === '1';
      })
    );
    setAlerts(next);
  }, []);

  const load = useCallback(async () => {
    try {
      const loc = await locationService.getCurrentLocation();
      if (loc) setUserPos({ lat: loc.latitude, lng: loc.longitude });
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/users/favorites`, {
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) {
        setRows([]);
        return;
      }
      const data = await res.json();
      const list = (data.favorites || []) as FavRow[];
      setRows(list);
      await loadAlerts(list);
    } catch {
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [loadAlerts]);

  useEffect(() => {
    load();
  }, [load]);

  const onRefresh = async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  };

  const toggleAlert = async (venueId: string) => {
    const on = !alerts[venueId];
    setAlerts(s => ({ ...s, [venueId]: on }));
    await AsyncStorage.setItem(`${CROWD_ALERT_PREFIX}${venueId}`, on ? '1' : '0');
  };

  const removeFavorite = async (venueId: string) => {
    const prev = rows;
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setRows(r => r.filter(x => x.venueId !== venueId));
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/users/favorites/${venueId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) throw new Error('fail');
    } catch {
      setRows(prev);
    }
  };

  const renderItem = ({ item }: { item: FavRow }) => {
    const crowd = item.currentCrowdSize ?? 3;
    const lat = (item as unknown as { latitude?: number }).latitude;
    const lng = (item as unknown as { longitude?: number }).longitude;
    const distance =
      userPos && lat != null && lng != null
        ? distMi(userPos.lat, userPos.lng, lat, lng)
        : '';
    return (
      <View>
        <TouchableOpacity
          activeOpacity={0.92}
          onPress={() => {
            const v: Venue = {
              id: item.venueId,
              name: item.name || 'Venue',
              address: '',
              latitude: lat ?? 0,
              longitude: lng ?? 0,
              category: '',
              createdBy: '',
              createdAt: new Date().toISOString(),
              updatedAt: new Date().toISOString(),
              isActive: true,
              peepCount: 0,
              averageRating: 0,
              totalRatings: 0,
              imageUrl: item.imageUrl,
            };
            navigation.navigate('Venue', { venue: v });
          }}
        >
          <View style={styles.card}>
            <ImageBackground
              source={{ uri: item.imageUrl || 'https://via.placeholder.com/800x320' }}
              style={styles.bg}
              imageStyle={styles.bgImg}
            >
              <LinearGradient
                colors={['rgba(0,0,0,0.15)', 'rgba(0,0,0,0.82)']}
                style={styles.scrim}
              >
                <View style={styles.topRow}>
                  <View style={styles.leftIcons}>
                    <TouchableOpacity
                      onPress={e => {
                        e.stopPropagation?.();
                        removeFavorite(item.venueId);
                      }}
                      hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                    >
                      <Icon name="favorite" size={26} color="#E91E63" />
                    </TouchableOpacity>
                    <TouchableOpacity
                      onPress={e => {
                        e.stopPropagation?.();
                        toggleAlert(item.venueId);
                      }}
                      style={{ marginLeft: 10 }}
                      hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                    >
                      <Icon
                        name={alerts[item.venueId] ? 'notifications-active' : 'notifications-none'}
                        size={22}
                        color={alerts[item.venueId] ? ACCENT : '#fff'}
                      />
                    </TouchableOpacity>
                  </View>
                  <View style={[styles.crowdCircle, { borderColor: crowdColor(crowd) }]}>
                    <View style={[styles.crowdDot, { backgroundColor: crowdColor(crowd) }]} />
                    <Text style={styles.crowdNum}>{crowd}</Text>
                  </View>
                </View>
                <View style={styles.bottomText}>
                  <Text style={styles.venueName}>{item.name || 'Venue'}</Text>
                  <Text style={styles.lastPeep}>Last peep: {formatAgo(item.lastPeepAt)}</Text>
                  {distance ? <Text style={styles.dist}>{distance}</Text> : null}
                </View>
              </LinearGradient>
            </ImageBackground>
          </View>
        </TouchableOpacity>
      </View>
    );
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color={ACCENT} />
      </View>
    );
  }

  if (rows.length === 0) {
    return (
      <View style={styles.emptyWrap}>
        <Text style={styles.emptyText}>
          No favorites yet. Tap the ♡ on any venue to save it.
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={rows}
        keyExtractor={i => i.venueId}
        renderItem={renderItem}
        contentContainerStyle={styles.listPad}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={ACCENT} />
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f5f5' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' },
  listPad: { paddingVertical: 12, paddingHorizontal: 12 },
  card: {
    width: '100%',
    height: 160,
    marginBottom: 12,
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#ddd',
  },
  bg: { flex: 1, width: '100%', height: '100%' },
  bgImg: { borderRadius: 12 },
  scrim: { flex: 1, padding: 12, justifyContent: 'space-between' },
  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  leftIcons: { flexDirection: 'row', alignItems: 'center' },
  crowdCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    borderWidth: 2,
    backgroundColor: 'rgba(0,0,0,0.35)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  crowdDot: { width: 10, height: 10, borderRadius: 5, position: 'absolute', top: 6 },
  crowdNum: { color: '#fff', fontWeight: 'bold', fontSize: 16, marginTop: 10 },
  bottomText: { alignSelf: 'stretch' },
  venueName: { color: '#fff', fontWeight: 'bold', fontSize: 20 },
  lastPeep: { color: '#fff', fontSize: 12, marginTop: 4 },
  dist: { color: 'rgba(255,255,255,0.85)', fontSize: 12, marginTop: 2 },
  emptyWrap: {
    flex: 1,
    backgroundColor: '#fff',
    justifyContent: 'center',
    paddingHorizontal: 32,
  },
  emptyText: { fontSize: 16, color: '#444', textAlign: 'center', lineHeight: 24 },
});
