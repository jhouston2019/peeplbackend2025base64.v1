import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Image,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
  Share,
} from 'react-native';
import auth from '@react-native-firebase/auth';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';
import { Peep } from '../types/Peep';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';

const CROWD_LABELS = ['Empty', 'Light', 'Moderate', 'Busy', 'Packed'];

function formatAgo(iso: string): string {
  const d = new Date(iso).getTime();
  const diff = Date.now() - d;
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'Just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const days = Math.floor(h / 24);
  return `${days}d ago`;
}

function crowdColor(size: number): string {
  if (size <= 2) return '#4CAF50';
  if (size === 3) return '#FFA726';
  return '#F44336';
}

type Nav = StackNavigationProp<RootStackParamList, 'MyPeeps'>;

interface MyPeepsScreenProps {
  navigation: Nav;
}

export default function MyPeepsScreen({ navigation }: MyPeepsScreenProps) {
  const [peeps, setPeeps] = useState<Peep[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const rootNav = navigation.getParent() ?? navigation;

  const load = useCallback(async () => {
    const uid = auth().currentUser?.uid;
    if (!uid) {
      setPeeps([]);
      return;
    }
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/peeps?userId=${encodeURIComponent(uid)}`, {
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) {
        setPeeps([]);
        return;
      }
      const data = await res.json();
      const list = Array.isArray(data) ? data : data.peeps || [];
      setPeeps(
        (list as Peep[]).sort(
          (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
        )
      );
    } catch {
      setPeeps([]);
    }
  }, []);

  useEffect(() => {
    let c = false;
    (async () => {
      setLoading(true);
      await load();
      if (!c) setLoading(false);
    })();
    return () => {
      c = true;
    };
  }, [load]);

  const onRefresh = async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  };

  const sharePeep = (item: Peep) => {
    Share.share({
      message: `${item.venue?.name ?? 'Venue'} on Peepl — ${item.description.slice(0, 120)}`,
    });
  };

  const goCreatePeep = () => {
    (rootNav as { navigate: (a: string, b?: object) => void }).navigate('CreatePeep', {
      location: undefined,
      venues: [],
    });
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color={ACCENT} />
      </View>
    );
  }

  if (peeps.length === 0) {
    return (
      <View style={styles.emptyWrap}>
        <Text style={styles.emptyTitle}>{"You haven't posted any Peeps yet."}</Text>
        <TouchableOpacity onPress={goCreatePeep} style={styles.ctaEmpty}>
          <Text style={styles.ctaEmptyText}>Post your first Peep →</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={peeps}
        keyExtractor={item => item.id}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={ACCENT} />}
        renderItem={({ item }) => (
          <TouchableOpacity
            style={styles.card}
            activeOpacity={0.9}
            onPress={() => {
              (rootNav as { navigate: (n: string, p: object) => void }).navigate('PeepDetail', {
                peepId: item.id,
              });
            }}
          >
            {item.imageUrl || item.venue?.name ? (
              <Image
                source={{
                  uri: item.imageUrl || 'https://via.placeholder.com/80x80/1565C0/FFFFFF?text=P',
                }}
                style={styles.thumb}
              />
            ) : (
              <View style={[styles.thumb, styles.thumbPh]} />
            )}
            <View style={styles.cardBody}>
              <View style={styles.cardTop}>
                <Text style={styles.venueName}>{item.venue?.name ?? 'Venue'}</Text>
                <TouchableOpacity onPress={() => sharePeep(item)}>
                  <Text style={styles.share}>Share</Text>
                </TouchableOpacity>
              </View>
              <Text style={styles.time}>{formatAgo(item.createdAt)}</Text>
              <View style={[styles.crowdPill, { backgroundColor: crowdColor(item.crowdSize) }]}>
                <Text style={styles.crowdText}>{CROWD_LABELS[item.crowdSize - 1]}</Text>
              </View>
              <View style={styles.chips}>
                {(item.vibe || []).map(v => (
                  <View key={v} style={styles.chip}>
                    <Text style={styles.chipText}>{v}</Text>
                  </View>
                ))}
              </View>
              {item.isPioneer ? (
                <View style={styles.pioneerBadge}>
                  <Text style={styles.pioneerBadgeText}>⭐ Pioneer</Text>
                </View>
              ) : null}
              <View style={styles.counts}>
                <Text style={styles.countText}>🤍 {item.likeCount ?? 0}</Text>
                <Text style={styles.countText}>  💬 {item.commentCount ?? 0}</Text>
              </View>
            </View>
          </TouchableOpacity>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  card: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    marginHorizontal: 12,
    marginVertical: 8,
    borderRadius: 12,
    padding: 12,
    elevation: 1,
    shadowColor: '#000',
    shadowOpacity: 0.05,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 1 },
  },
  thumb: {
    width: 80,
    height: 80,
    borderRadius: 8,
    marginRight: 12,
    backgroundColor: '#E0E0E0',
  },
  thumbPh: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  cardBody: {
    flex: 1,
  },
  cardTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  venueName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#212121',
    flex: 1,
  },
  share: {
    color: PRIMARY,
    fontWeight: '600',
    fontSize: 14,
  },
  time: {
    fontSize: 12,
    color: '#9E9E9E',
    marginTop: 4,
  },
  crowdPill: {
    alignSelf: 'flex-start',
    marginTop: 8,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
  },
  crowdText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
  },
  chips: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginTop: 8,
  },
  chip: {
    backgroundColor: '#EEEEEE',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    marginRight: 6,
    marginBottom: 4,
  },
  chipText: {
    fontSize: 11,
    color: '#616161',
  },
  pioneerBadge: {
    marginTop: 8,
    alignSelf: 'flex-start',
    backgroundColor: ACCENT,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 8,
  },
  pioneerBadgeText: {
    color: '#000000',
    fontWeight: 'bold',
    fontSize: 12,
  },
  counts: {
    flexDirection: 'row',
    marginTop: 8,
  },
  countText: {
    fontSize: 14,
    color: '#424242',
  },
  emptyWrap: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
    backgroundColor: '#F5F5F5',
  },
  emptyTitle: {
    fontSize: 16,
    color: '#424242',
    textAlign: 'center',
    marginBottom: 16,
  },
  ctaEmpty: {
    paddingVertical: 12,
    paddingHorizontal: 20,
    backgroundColor: ACCENT,
    borderRadius: 10,
  },
  ctaEmptyText: {
    color: '#000000',
    fontWeight: 'bold',
    fontSize: 16,
  },
});
