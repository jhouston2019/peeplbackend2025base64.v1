import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Image,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import auth from '@react-native-firebase/auth';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';

export interface PioneerRowUser {
  userId?: string;
  uid?: string;
  username: string;
  pioneerCount: number;
  profileImageUrl?: string;
  isFollowing?: boolean;
}

type Nav = StackNavigationProp<RootStackParamList, 'Pioneers'>;

interface PioneersScreenProps {
  navigation: Nav;
}

async function fetchEveryone(): Promise<PioneerRowUser[]> {
  const token = await authService.getIdToken();
  const res = await fetch(`${BASE_URL}/leaderboard/everyone`, {
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });
  if (!res.ok) return [];
  const data = await res.json();
  const raw = Array.isArray(data) ? data : data.users || data.rows || [];
  return raw.map((r: Record<string, unknown>) => ({
    userId: (r.userId || r.uid || r.id) as string | undefined,
    uid: r.uid as string | undefined,
    username: String(r.username ?? r.name ?? 'User'),
    pioneerCount: Number(r.pioneerCount ?? r.pioneer_count ?? 0),
    profileImageUrl: r.profileImageUrl ? String(r.profileImageUrl) : undefined,
    isFollowing: r.isFollowing as boolean | undefined,
  }));
}

export default function PioneersScreen({ navigation }: PioneersScreenProps) {
  const [rows, setRows] = useState<PioneerRowUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [followingMap, setFollowingMap] = useState<Record<string, boolean>>({});

  const myUid = auth().currentUser?.uid;

  const load = useCallback(async () => {
    const list = await fetchEveryone();
    const sorted = [...list].sort((a, b) => b.pioneerCount - a.pioneerCount);
    setRows(sorted);
    const fm: Record<string, boolean> = {};
    sorted.forEach((u, i) => {
      const id = u.userId || u.uid || `idx-${i}`;
      if (u.isFollowing != null) fm[id] = u.isFollowing;
    });
    setFollowingMap(fm);
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      await load();
      if (!cancelled) setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [load]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  const rootNav = useMemo(() => navigation.getParent() ?? navigation, [navigation]);

  const toggleFollow = async (item: PioneerRowUser, index: number) => {
    const id = item.userId || item.uid || `idx-${index}`;
    const next = !followingMap[id];
    setFollowingMap(prev => ({ ...prev, [id]: next }));
    try {
      const token = await authService.getIdToken();
      const uid = item.userId || item.uid;
      if (!uid) return;
      await fetch(`${BASE_URL}/users/${uid}/follow`, {
        method: next ? 'POST' : 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
    } catch {
      setFollowingMap(prev => ({ ...prev, [id]: !next }));
    }
  };

  const openUser = (item: PioneerRowUser, index: number) => {
    const uid = item.userId || item.uid;
    if (!uid) return;
    rootNav.navigate('UserProfile', { userId: uid });
  };

  const renderItem = ({ item, index }: { item: PioneerRowUser; index: number }) => {
    const uid = item.userId || item.uid || `idx-${index}`;
    const rank = index + 1;
    const isMe = !!(myUid && (item.userId === myUid || item.uid === myUid));
    const following = followingMap[uid] ?? item.isFollowing ?? false;

    return (
      <TouchableOpacity
        style={[styles.row, isMe && styles.rowMe]}
        onPress={() => openUser(item, index)}
        activeOpacity={0.75}
      >
        <Text style={styles.rank}>{rank}</Text>
        {item.profileImageUrl ? (
          <Image source={{ uri: item.profileImageUrl }} style={styles.avatar} />
        ) : (
          <View style={styles.avatarPh}>
            <Icon name="person" size={26} color="#757575" />
          </View>
        )}
        <View style={styles.mid}>
          <Text style={styles.username}>{item.username}</Text>
          <View style={styles.badgeRow}>
            <Text style={styles.star}>⭐</Text>
            <Text style={styles.venues}>{item.pioneerCount} venues</Text>
          </View>
        </View>
        {!isMe ? (
          <TouchableOpacity
            style={[styles.followBtn, following && styles.followBtnOn]}
            onPress={e => {
              e.stopPropagation?.();
              toggleFollow(item, index);
            }}
          >
            <Text style={[styles.followText, following && styles.followTextOn]}>
              {following ? 'Following' : 'Follow'}
            </Text>
          </TouchableOpacity>
        ) : (
          <View style={styles.followPlaceholder} />
        )}
      </TouchableOpacity>
    );
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#FFC107" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Pioneers</Text>
        <Text style={styles.headerIcon}>⭐</Text>
      </View>
      <FlatList
        data={rows}
        keyExtractor={(item, i) => String(item.userId || item.uid || i)}
        renderItem={renderItem}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#FFC107" />}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1565C0',
    paddingVertical: 16,
    paddingHorizontal: 16,
  },
  headerTitle: {
    color: '#FFFFFF',
    fontSize: 22,
    fontWeight: 'bold',
    marginRight: 8,
  },
  headerIcon: {
    fontSize: 22,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#EEEEEE',
  },
  rowMe: {
    backgroundColor: '#E3F2FD',
    borderLeftWidth: 4,
    borderLeftColor: '#1565C0',
  },
  rank: {
    width: 40,
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
  },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    marginRight: 10,
  },
  avatarPh: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#E0E0E0',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 10,
  },
  mid: {
    flex: 1,
  },
  username: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#000000',
  },
  badgeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
  },
  star: {
    marginRight: 4,
    fontSize: 14,
  },
  venues: {
    color: '#FFC107',
    fontSize: 14,
    fontWeight: '600',
  },
  followBtn: {
    borderWidth: 1,
    borderColor: '#1565C0',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 6,
    minWidth: 88,
    alignItems: 'center',
  },
  followBtnOn: {
    backgroundColor: '#1565C0',
    borderColor: '#1565C0',
  },
  followText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#1565C0',
  },
  followTextOn: {
    color: '#FFFFFF',
  },
  followPlaceholder: {
    width: 88,
  },
});
