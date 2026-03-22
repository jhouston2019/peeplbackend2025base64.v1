import React, { useCallback, useEffect, useLayoutEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TextInput,
  Image,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import auth from '@react-native-firebase/auth';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';

type RowUser = {
  userId: string;
  username: string;
  pioneerCount?: number;
  points?: number;
  profileImageUrl?: string;
  isFollowing?: boolean;
};

type Props = {
  route: RouteProp<RootStackParamList, 'FollowList'>;
  navigation: StackNavigationProp<RootStackParamList, 'FollowList'>;
};

export default function FollowListScreen({ route, navigation }: Props) {
  const { userId, type } = route.params;
  const myUid = auth().currentUser?.uid;
  const isOwn = myUid === userId;

  const [query, setQuery] = useState('');
  const [rows, setRows] = useState<RowUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [followMap, setFollowMap] = useState<Record<string, boolean>>({});

  const title = type === 'followers' ? 'Followers' : 'Following';

  useLayoutEffect(() => {
    navigation.setOptions({ title });
  }, [navigation, title]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const token = await authService.getIdToken();
      const path =
        type === 'followers'
          ? `${BASE_URL}/users/${userId}/followers`
          : `${BASE_URL}/users/${userId}/following`;
      const res = await fetch(path, {
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
      const raw = Array.isArray(data) ? data : data.users || data.items || [];
      const mapped: RowUser[] = raw.map((r: Record<string, unknown>) => ({
        userId: String(r.userId ?? r.uid ?? r.id ?? ''),
        username: String(r.username ?? r.name ?? 'User'),
        pioneerCount: r.pioneerCount != null ? Number(r.pioneerCount) : 0,
        points: r.points != null ? Number(r.points) : 0,
        profileImageUrl: r.profileImageUrl ? String(r.profileImageUrl) : undefined,
        isFollowing: r.isFollowing as boolean | undefined,
      }));
      setRows(mapped);
      const fm: Record<string, boolean> = {};
      mapped.forEach(u => {
        if (u.isFollowing != null) fm[u.userId] = u.isFollowing;
      });
      setFollowMap(fm);
    } catch {
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [userId, type]);

  useEffect(() => {
    load();
  }, [load]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter(r => r.username.toLowerCase().includes(q));
  }, [rows, query]);

  const setFollowState = (id: string, val: boolean) => {
    setFollowMap(prev => ({ ...prev, [id]: val }));
  };

  const onAction = async (item: RowUser, mode: 'follow' | 'remove' | 'unfollow') => {
    const token = await authService.getIdToken();
    try {
      if (mode === 'follow') {
        const next = !(followMap[item.userId] ?? item.isFollowing);
        setFollowState(item.userId, next);
        await fetch(`${BASE_URL}/users/${item.userId}/follow`, {
          method: next ? 'POST' : 'DELETE',
          headers: {
            'Content-Type': 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        });
      } else if (mode === 'remove') {
        await fetch(`${BASE_URL}/users/${item.userId}/follow`, {
          method: 'DELETE',
          headers: {
            'Content-Type': 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        });
        setRows(prev => prev.filter(r => r.userId !== item.userId));
      } else if (mode === 'unfollow') {
        await fetch(`${BASE_URL}/users/${item.userId}/follow`, {
          method: 'DELETE',
          headers: {
            'Content-Type': 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        });
        setRows(prev => prev.filter(r => r.userId !== item.userId));
      }
    } catch {
      if (mode === 'follow') {
        const next = !(followMap[item.userId] ?? item.isFollowing);
        setFollowState(item.userId, !next);
      }
    }
  };

  const renderItem = ({ item }: { item: RowUser }) => {
    const following = followMap[item.userId] ?? item.isFollowing ?? false;

    return (
      <TouchableOpacity
        style={styles.row}
        onPress={() => navigation.navigate('UserProfile', { userId: item.userId })}
        activeOpacity={0.75}
      >
        {item.profileImageUrl ? (
          <Image source={{ uri: item.profileImageUrl }} style={styles.avatar} />
        ) : (
          <View style={styles.avatarPh}>
            <Icon name="person" size={24} color="#757575" />
          </View>
        )}
        <View style={styles.mid}>
          <Text style={styles.uname}>{item.username}</Text>
          {(item.pioneerCount ?? 0) > 0 ? <Text style={styles.star}>⭐</Text> : null}
          <Text style={styles.pts}>{item.points ?? 0} pts</Text>
        </View>
        {!isOwn ? (
          <TouchableOpacity
            style={[styles.miniBtn, following && styles.miniBtnOn]}
            onPress={() => onAction(item, 'follow')}
          >
            <Text style={[styles.miniTxt, following && styles.miniTxtOn]}>
              {following ? 'Following' : 'Follow'}
            </Text>
          </TouchableOpacity>
        ) : type === 'followers' ? (
          <TouchableOpacity style={styles.miniOutline} onPress={() => onAction(item, 'remove')}>
            <Text style={styles.miniOutlineTxt}>Remove</Text>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity style={styles.miniOutline} onPress={() => onAction(item, 'unfollow')}>
            <Text style={styles.miniOutlineTxt}>Unfollow</Text>
          </TouchableOpacity>
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
      <View style={styles.searchWrap}>
        <Icon name="search" size={22} color="#757575" style={styles.searchIcon} />
        <TextInput
          style={styles.search}
          placeholder="Search"
          placeholderTextColor="#9E9E9E"
          value={query}
          onChangeText={setQuery}
        />
      </View>
      <FlatList
        data={filtered}
        keyExtractor={item => item.userId}
        renderItem={renderItem}
        ListEmptyComponent={<Text style={styles.empty}>No users found.</Text>}
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
  },
  searchWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F5F5F5',
    margin: 12,
    borderRadius: 10,
    paddingHorizontal: 10,
  },
  searchIcon: {
    marginRight: 6,
  },
  search: {
    flex: 1,
    paddingVertical: 10,
    fontSize: 16,
    color: '#212121',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 14,
    borderBottomWidth: 1,
    borderBottomColor: '#EEEEEE',
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
  uname: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#000000',
  },
  star: {
    marginTop: 2,
    fontSize: 14,
  },
  pts: {
    fontSize: 14,
    color: '#9E9E9E',
    marginTop: 2,
  },
  miniBtn: {
    borderWidth: 1,
    borderColor: '#1565C0',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  miniBtnOn: {
    backgroundColor: '#1565C0',
  },
  miniTxt: {
    fontSize: 12,
    fontWeight: '600',
    color: '#1565C0',
  },
  miniTxtOn: {
    color: '#FFFFFF',
  },
  miniOutline: {
    borderWidth: 1,
    borderColor: '#BDBDBD',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  miniOutlineTxt: {
    fontSize: 12,
    color: '#424242',
    fontWeight: '600',
  },
  empty: {
    textAlign: 'center',
    color: '#9E9E9E',
    marginTop: 24,
  },
});
