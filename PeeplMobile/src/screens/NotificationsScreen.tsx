import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';

type Nav = StackNavigationProp<RootStackParamList, 'Notifications'>;

type Props = { navigation: Nav };

type Notif = {
  id: string;
  type: string;
  read?: boolean;
  createdAt?: string;
  venueName?: string;
  username?: string;
  venueId?: string;
  peepId?: string;
  userId?: string;
  offerText?: string;
};

function formatAgo(iso?: string): string {
  if (!iso) return '';
  const ms = new Date(iso).getTime();
  const diff = Date.now() - ms;
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'Just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

function messageFor(n: Notif): { icon: string; text: string } {
  const v = n.venueName || 'Venue';
  const u = n.username || 'Someone';
  switch (n.type) {
    case 'pioneer_buzz':
      return { icon: '⭐', text: `${v} is picking up — you discovered it first!` };
    case 'crowd_spike':
      return { icon: '🔥', text: `${v} is getting crowded right now` };
    case 'follower_peep':
      return { icon: '👀', text: `${u} just peeped at ${v}` };
    case 'like':
      return { icon: '❤️', text: `${u} liked your Peep at ${v}` };
    case 'new_follower':
      return { icon: '👤', text: `${u} started following you` };
    case 'comment':
      return { icon: '💬', text: `${u} commented on your Peep` };
    case 'deal_alert':
      return {
        icon: '🎉',
        text: `New deal at ${v}: ${n.offerText || 'Special offer'}`,
      };
    default:
      return { icon: '🔔', text: 'Notification' };
  }
}

export default function NotificationsScreen({ navigation }: Props) {
  const [items, setItems] = useState<Notif[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/notifications`, {
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) {
        setItems([]);
        return;
      }
      const data = await res.json();
      setItems(data.notifications || []);
    } catch {
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const markAllRead = async () => {
    try {
      const token = await authService.getIdToken();
      await fetch(`${BASE_URL}/notifications/read-all`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      setItems(prev => prev.map(n => ({ ...n, read: true })));
    } catch {
      setItems(prev => prev.map(n => ({ ...n, read: true })));
    }
  };

  const onPressRow = async (n: Notif) => {
    try {
      const token = await authService.getIdToken();
      await fetch(`${BASE_URL}/notifications/${n.id}/read`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
    } catch {
      /* ignore */
    }
    setItems(prev => prev.map(x => (x.id === n.id ? { ...x, read: true } : x)));

    if (n.peepId) {
      navigation.navigate('PeepDetail', { peepId: n.peepId });
      return;
    }
    if (n.venueId) {
      navigation.navigate('Venue', {
        venue: {
          id: n.venueId,
          name: n.venueName || 'Venue',
          address: '',
          latitude: 0,
          longitude: 0,
          category: '',
          createdBy: '',
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          isActive: true,
          peepCount: 0,
          averageRating: 0,
          totalRatings: 0,
        },
      });
      return;
    }
    if (n.userId) {
      navigation.navigate('UserProfile', { userId: n.userId });
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color={ACCENT} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={items}
        keyExtractor={i => i.id}
        ListHeaderComponent={
          <TouchableOpacity style={styles.markAll} onPress={markAllRead}>
            <Text style={styles.markAllText}>Mark all read</Text>
          </TouchableOpacity>
        }
        renderItem={({ item }) => {
          const { icon, text } = messageFor(item);
          const unread = !item.read;
          return (
            <TouchableOpacity
              style={[styles.row, unread && styles.rowUnread]}
              onPress={() => onPressRow(item)}
            >
              <View style={styles.iconCircle}>
                <Text style={styles.iconText}>{icon}</Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.msg}>{text}</Text>
                <Text style={styles.time}>{formatAgo(item.createdAt)}</Text>
              </View>
            </TouchableOpacity>
          );
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  markAll: { alignSelf: 'flex-end', padding: 12 },
  markAllText: { color: PRIMARY, fontWeight: '600' },
  row: { flexDirection: 'row', padding: 14, borderBottomWidth: StyleSheet.hairlineWidth, borderColor: '#eee' },
  rowUnread: { backgroundColor: '#E3F2FD' },
  iconCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#f0f0f0',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  iconText: { fontSize: 16 },
  msg: { fontSize: 14, color: '#222' },
  time: { fontSize: 11, color: '#888', marginTop: 4 },
});
