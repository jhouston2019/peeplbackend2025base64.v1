import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Image,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';
import auth from '@react-native-firebase/auth';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const PRIMARY = '#1565C0';

type Props = {
  route: RouteProp<RootStackParamList, 'Likers'>;
  navigation: StackNavigationProp<RootStackParamList, 'Likers'>;
};

type Row = {
  userId: string;
  username: string;
  profileImageUrl?: string;
  pioneerCount?: number;
  following?: boolean;
};

export default function LikersScreen({ route, navigation }: Props) {
  const { peepId } = route.params;
  const [loading, setLoading] = useState(true);
  const [rows, setRows] = useState<Row[]>([]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/peeps/${peepId}/likes`, {
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
      const ids: string[] = data.likers || data.userIds || [];
      const users = await Promise.all(
        ids.map(async (userId: string) => {
          const ures = await fetch(`${BASE_URL}/users/${userId}`, {
            headers: {
              'Content-Type': 'application/json',
              ...(token ? { Authorization: `Bearer ${token}` } : {}),
            },
          });
          if (!ures.ok) {
            return {
              userId,
              username: 'User',
              pioneerCount: 0,
              following: false,
            };
          }
          const u = await ures.json();
          return {
            userId,
            username: String(u.username || 'User'),
            profileImageUrl: u.profileImageUrl ? String(u.profileImageUrl) : undefined,
            pioneerCount: u.pioneerCount != null ? Number(u.pioneerCount) : 0,
            following: !!u.isFollowing,
          };
        })
      );
      setRows(users);
    } catch {
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [peepId]);

  useEffect(() => {
    load();
  }, [load]);

  const toggleFollow = async (item: Row) => {
    const next = !item.following;
    setRows(r =>
      r.map(x => (x.userId === item.userId ? { ...x, following: next } : x))
    );
    try {
      const token = await authService.getIdToken();
      await fetch(`${BASE_URL}/users/${item.userId}/follow`, {
        method: next ? 'POST' : 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
    } catch {
      setRows(r =>
        r.map(x => (x.userId === item.userId ? { ...x, following: item.following } : x))
      );
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color={PRIMARY} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={rows}
        keyExtractor={i => i.userId}
        renderItem={({ item }) => (
          <TouchableOpacity
            style={styles.row}
            onPress={() => navigation.navigate('UserProfile', { userId: item.userId })}
          >
            <Image
              source={{ uri: item.profileImageUrl || 'https://via.placeholder.com/88' }}
              style={styles.avatar}
            />
            <View style={{ flex: 1 }}>
              <Text style={styles.name}>
                {item.username}{' '}
                {(item.pioneerCount || 0) > 0 ? <Text>⭐</Text> : null}
              </Text>
            </View>
            {auth().currentUser?.uid !== item.userId ? (
              <TouchableOpacity
                style={[styles.followBtn, item.following && styles.followBtnActive]}
                onPress={() => toggleFollow(item)}
              >
                <Text style={[styles.followText, item.following && styles.followTextActive]}>
                  {item.following ? 'Following' : 'Follow'}
                </Text>
              </TouchableOpacity>
            ) : null}
          </TouchableOpacity>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: '#eee',
  },
  avatar: { width: 44, height: 44, borderRadius: 22, marginRight: 12, backgroundColor: '#ddd' },
  name: { fontWeight: 'bold', fontSize: 16 },
  followBtn: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: PRIMARY,
  },
  followBtnActive: { backgroundColor: '#E3F2FD', borderColor: '#E3F2FD' },
  followText: { color: PRIMARY, fontWeight: '600' },
  followTextActive: { color: PRIMARY },
});
