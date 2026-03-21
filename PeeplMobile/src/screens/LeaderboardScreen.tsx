import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Image,
  ActivityIndicator,
  TouchableOpacity,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import auth from '@react-native-firebase/auth';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';

type Nav = StackNavigationProp<RootStackParamList, 'Leaderboard'>;

interface LeaderboardScreenProps {
  navigation: Nav;
}

interface LBRow {
  rank: number;
  username: string;
  points: number;
  pioneerCount?: number;
  avatarUrl?: string;
  userId?: string;
}

interface RankMe {
  points: number;
  rank: number;
  pioneerCount: number;
}

async function authGet(path: string): Promise<unknown> {
  const token = await authService.getIdToken();
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });
  if (!res.ok) throw new Error('Failed');
  return res.json();
}

function Avatar({ uri, size, style }: { uri?: string; size: number; style?: object }) {
  if (uri) {
    return <Image source={{ uri }} style={[{ width: size, height: size, borderRadius: size / 2 }, style]} />;
  }
  return (
    <View style={[{ width: size, height: size, borderRadius: size / 2, backgroundColor: '#B0BEC5', justifyContent: 'center', alignItems: 'center' }, style]}>
      <Icon name="person" size={size * 0.5} color="#37474F" />
    </View>
  );
}

export default function LeaderboardScreen({}: LeaderboardScreenProps) {
  const [mode, setMode] = useState<'everyone' | 'friends'>('everyone');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [me, setMe] = useState<RankMe | null>(null);
  const [rows, setRows] = useState<LBRow[]>([]);

  const currentUid = auth().currentUser?.uid;

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const rankData = (await authGet('/leaderboard/rank')) as RankMe;
      setMe(rankData);

      const path =
        mode === 'everyone' ? '/leaderboard/everyone' : '/leaderboard/friends';
      const listData = (await authGet(path)) as { users?: LBRow[] } | LBRow[];
      const list = Array.isArray(listData) ? listData : listData.users || [];
      setRows(
        list.map((r: Record<string, unknown>, i: number) => ({
          rank: Number(r.rank ?? i + 1),
          username: String(r.username ?? r.name ?? 'User'),
          points: Number(r.points ?? 0),
          pioneerCount: r.pioneerCount != null ? Number(r.pioneerCount) : 0,
          avatarUrl: r.avatarUrl ? String(r.avatarUrl) : undefined,
          userId: r.userId ? String(r.userId) : r.uid ? String(r.uid) : undefined,
        }))
      );
    } catch (e) {
      setError('Could not load leaderboard');
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [mode]);

  useEffect(() => {
    load();
  }, [load]);

  const sortedRows = useMemo(
    () => [...rows].sort((a, b) => a.rank - b.rank),
    [rows]
  );
  const top3 = sortedRows.slice(0, 3);
  const rest = sortedRows.slice(3);

  const renderRow = ({ item, index }: { item: LBRow; index: number }) => {
    const isMe =
      (item.userId && item.userId === currentUid) ||
      (!item.userId && item.username === auth().currentUser?.displayName);
    return (
      <View
        style={[
          styles.row,
          index % 2 === 1 && styles.rowAlt,
          isMe && styles.rowMe,
        ]}
      >
        <Text style={styles.rankCol}>#{item.rank}</Text>
        <Avatar uri={item.avatarUrl} size={40} style={styles.avatarSm} />
        <View style={styles.rowMid}>
          <Text style={styles.rowName}>{item.username}</Text>
          {item.pioneerCount != null && item.pioneerCount > 0 ? (
            <Text style={styles.badge}>⭐</Text>
          ) : null}
        </View>
        <Text style={styles.rowPts}>{item.points}</Text>
      </View>
    );
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#FFC107" />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.err}>{error}</Text>
        <TouchableOpacity style={styles.retry} onPress={load}>
          <Text style={styles.retryText}>Retry</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const p1 = top3[0];
  const p2 = top3[1];
  const p3 = top3[2];

  return (
    <View style={styles.container}>
      <View style={styles.statsCard}>
        <View style={styles.statCell}>
          <Text style={styles.statVal}>{me?.points ?? '—'}</Text>
          <Text style={styles.statLbl}>Points</Text>
        </View>
        <View style={styles.statCell}>
          <Text style={styles.statVal}>#{me?.rank ?? '—'}</Text>
          <Text style={styles.statLbl}>Rank</Text>
        </View>
        <View style={styles.statCell}>
          <Text style={styles.statVal}>{me?.pioneerCount ?? '—'}</Text>
          <Text style={styles.statLbl}>Pioneer Count</Text>
        </View>
      </View>

      <View style={styles.toggle}>
        <TouchableOpacity
          style={[styles.togBtn, mode === 'everyone' && styles.togActive]}
          onPress={() => setMode('everyone')}
        >
          <Text style={[styles.togText, mode === 'everyone' && styles.togTextActive]}>Everyone</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.togBtn, mode === 'friends' && styles.togActive]}
          onPress={() => setMode('friends')}
        >
          <Text style={[styles.togText, mode === 'friends' && styles.togTextActive]}>Friends</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.podium}>
        <View style={styles.podiumSide}>
          {p2 ? (
            <>
              <Avatar uri={p2.avatarUrl} size={44} style={styles.avatarPod} />
              <View style={[styles.bar, styles.barSilver]}>
                <Text style={styles.barPts}>{p2.points}</Text>
              </View>
              <Text style={styles.pName} numberOfLines={1}>
                {p2.username}
              </Text>
            </>
          ) : (
            <View style={styles.barPlaceholder} />
          )}
        </View>

        <View style={styles.podiumCenter}>
          {p1 ? (
            <>
              <Icon name="emoji-events" size={28} color="#FFC107" style={styles.crown} />
              <Avatar uri={p1.avatarUrl} size={44} style={styles.avatarPod} />
              <View style={[styles.bar, styles.barGold]}>
                <Text style={styles.barPts}>{p1.points}</Text>
              </View>
              <Text style={styles.pName} numberOfLines={1}>
                {p1.username}
              </Text>
            </>
          ) : null}
        </View>

        <View style={styles.podiumSide}>
          {p3 ? (
            <>
              <Avatar uri={p3.avatarUrl} size={44} style={styles.avatarPod} />
              <View style={[styles.bar, styles.barBronze]}>
                <Text style={styles.barPts}>{p3.points}</Text>
              </View>
              <Text style={styles.pName} numberOfLines={1}>
                {p3.username}
              </Text>
            </>
          ) : (
            <View style={styles.barPlaceholder} />
          )}
        </View>
      </View>

      <FlatList
        data={rest}
        keyExtractor={(item, i) => `${item.rank}-${i}`}
        renderItem={renderRow}
        ListEmptyComponent={
          rows.length <= 3 ? (
            <Text style={styles.emptySmall}>No additional ranks</Text>
          ) : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1565C0',
    paddingTop: 12,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1565C0',
  },
  err: {
    color: '#FFFFFF',
    marginBottom: 12,
  },
  retry: {
    backgroundColor: '#FFC107',
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 8,
  },
  retryText: {
    fontWeight: 'bold',
    color: '#000',
  },
  statsCard: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    marginHorizontal: 16,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    justifyContent: 'space-between',
  },
  statCell: {
    alignItems: 'center',
    flex: 1,
  },
  statVal: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#1565C0',
  },
  statLbl: {
    fontSize: 12,
    color: '#546E7A',
    marginTop: 4,
  },
  toggle: {
    flexDirection: 'row',
    marginHorizontal: 16,
    marginBottom: 12,
    backgroundColor: 'rgba(255,255,255,0.2)',
    borderRadius: 8,
    padding: 4,
  },
  togBtn: {
    flex: 1,
    paddingVertical: 10,
    alignItems: 'center',
    borderRadius: 6,
  },
  togActive: {
    backgroundColor: '#FFC107',
  },
  togText: {
    color: '#FFFFFF',
    fontWeight: '600',
  },
  togTextActive: {
    color: '#000000',
  },
  podium: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'center',
    paddingHorizontal: 8,
    marginBottom: 16,
    minHeight: 200,
  },
  podiumSide: {
    flex: 1,
    alignItems: 'center',
  },
  podiumCenter: {
    flex: 1,
    alignItems: 'center',
  },
  crown: {
    marginBottom: 4,
  },
  avatarPod: {
    width: 44,
    height: 44,
    borderRadius: 22,
    marginBottom: 6,
    backgroundColor: '#E0E0E0',
  },
  bar: {
    width: '80%',
    justifyContent: 'flex-end',
    alignItems: 'center',
    borderTopLeftRadius: 6,
    borderTopRightRadius: 6,
    paddingBottom: 6,
  },
  barGold: {
    height: 80,
    backgroundColor: '#FFD54F',
  },
  barSilver: {
    height: 60,
    backgroundColor: '#E0E0E0',
  },
  barBronze: {
    height: 50,
    backgroundColor: '#D7A574',
  },
  barPts: {
    fontWeight: 'bold',
    fontSize: 14,
    color: '#212121',
  },
  pName: {
    fontSize: 11,
    color: '#FFFFFF',
    marginTop: 4,
    maxWidth: 90,
    textAlign: 'center',
  },
  barPlaceholder: {
    height: 80,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#ECEFF1',
  },
  rowAlt: {
    backgroundColor: '#F5F5F5',
  },
  rowMe: {
    borderLeftWidth: 4,
    borderLeftColor: '#1565C0',
    backgroundColor: '#E3F2FD',
  },
  rankCol: {
    width: 36,
    fontWeight: '600',
    color: '#37474F',
  },
  avatarSm: {
    width: 40,
    height: 40,
    borderRadius: 20,
    marginRight: 10,
    backgroundColor: '#E0E0E0',
  },
  rowMid: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
  rowName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212121',
  },
  badge: {
    marginLeft: 6,
    fontSize: 14,
  },
  rowPts: {
    fontWeight: 'bold',
    color: '#1565C0',
    fontSize: 15,
  },
  emptySmall: {
    textAlign: 'center',
    color: '#FFFFFF',
    padding: 16,
  },
});
