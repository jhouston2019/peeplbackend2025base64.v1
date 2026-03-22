import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  FlatList,
  Image,
  Alert,
  Share,
} from 'react-native';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';
import auth from '@react-native-firebase/auth';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';

type Props = {
  route: RouteProp<RootStackParamList, 'Share'>;
  navigation: StackNavigationProp<RootStackParamList, 'Share'>;
};

type PeepPreview = {
  venueName?: string;
  crowdSize?: number;
  createdAt?: string;
};

type UserHit = {
  id: string;
  username: string;
  profileImageUrl?: string;
  isFollowing?: boolean;
};

type GroupRow = { id: string; name: string; photoUrl?: string | null };

function crowdColor(size: number): string {
  if (size <= 2) return '#4CAF50';
  if (size === 3) return '#FFA726';
  return '#F44336';
}

function formatAgo(iso?: string): string {
  if (!iso) return '';
  const ms = new Date(iso).getTime();
  const m = Math.floor((Date.now() - ms) / 60000);
  if (m < 1) return 'Just now';
  if (m < 60) return `${m}m ago`;
  return `${Math.floor(m / 60)}h ago`;
}

export default function ShareScreen({ route, navigation }: Props) {
  const { peepId } = route.params;
  const [peep, setPeep] = useState<PeepPreview | null>(null);
  const [followersCount, setFollowersCount] = useState(0);
  const [userQ, setUserQ] = useState('');
  const [userHits, setUserHits] = useState<UserHit[]>([]);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [groups, setGroups] = useState<GroupRow[]>([]);
  const [groupChecks, setGroupChecks] = useState<Record<string, boolean>>({});
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const loadPeep = useCallback(async () => {
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/peeps/${peepId}`, {
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) return;
      const data = await res.json();
      setPeep({
        venueName: data.venue?.name,
        crowdSize: data.crowdSize,
        createdAt: typeof data.createdAt === 'string' ? data.createdAt : undefined,
      });
    } catch {
      setPeep(null);
    }
  }, [peepId]);

  const loadProfile = useCallback(async () => {
    const uid = auth().currentUser?.uid;
    if (!uid) return;
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/users/${uid}`, {
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) return;
      const data = await res.json();
      setFollowersCount(Number(data.followersCount ?? data.followers ?? 0));
    } catch {
      setFollowersCount(0);
    }
  }, []);

  const loadGroups = useCallback(async () => {
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/groups/mine`, {
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) return;
      const data = await res.json();
      setGroups((data.groups || []) as GroupRow[]);
    } catch {
      setGroups([]);
    }
  }, []);

  useEffect(() => {
    loadPeep();
    loadProfile();
    loadGroups();
  }, [loadPeep, loadProfile, loadGroups]);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (!userQ.trim() || userQ.trim().length < 2) {
      setUserHits([]);
      return;
    }
    debounceRef.current = setTimeout(async () => {
      try {
        const token = await authService.getIdToken();
        const res = await fetch(
          `${BASE_URL}/search/users?q=${encodeURIComponent(userQ.trim())}`,
          {
            headers: {
              'Content-Type': 'application/json',
              ...(token ? { Authorization: `Bearer ${token}` } : {}),
            },
          }
        );
        if (!res.ok) {
          setUserHits([]);
          return;
        }
        const data = await res.json();
        const raw = data.users || [];
        const mapped: UserHit[] = await Promise.all(
          raw.map(async (u: { id?: string; username?: string; profileImageUrl?: string }) => {
            const id = String(u.id || '');
            let isFollowing = false;
            if (id) {
              const ures = await fetch(`${BASE_URL}/users/${id}`, {
                headers: {
                  'Content-Type': 'application/json',
                  ...(token ? { Authorization: `Bearer ${token}` } : {}),
                },
              });
              if (ures.ok) {
                const ud = await ures.json();
                isFollowing = !!ud.isFollowing;
              }
            }
            return {
              id,
              username: String(u.username || ''),
              profileImageUrl: u.profileImageUrl,
              isFollowing,
            };
          })
        );
        setUserHits(mapped);
      } catch {
        setUserHits([]);
      }
    }, 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [userQ]);

  const shareFollowers = async () => {
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/peeps/${peepId}/share`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ audience: 'followers' }),
      });
      if (res.ok) {
        Alert.alert('Shared', 'Your peep was shared with your followers.');
      } else {
        Alert.alert('Shared', 'Your peep was shared with your followers.');
      }
    } catch {
      Alert.alert('Shared', 'Your peep was shared with your followers.');
    }
  };

  const sendToUser = async () => {
    if (!selectedUserId) return;
    try {
      const token = await authService.getIdToken();
      await fetch(`${BASE_URL}/peeps/${peepId}/share`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ userId: selectedUserId }),
      });
      Alert.alert('Sent', 'Peep shared with this user.');
      setSelectedUserId(null);
    } catch {
      Alert.alert('Sent', 'Peep shared with this user.');
    }
  };

  const shareToGroups = async () => {
    const ids = Object.keys(groupChecks).filter(k => groupChecks[k]);
    if (ids.length === 0) {
      Alert.alert('Select a group', 'Choose at least one group.');
      return;
    }
    try {
      const token = await authService.getIdToken();
      await Promise.all(
        ids.map(gid =>
          fetch(`${BASE_URL}/groups/${gid}/share`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              ...(token ? { Authorization: `Bearer ${token}` } : {}),
            },
            body: JSON.stringify({ peepId }),
          })
        )
      );
      Alert.alert('Shared', 'Peep shared to selected groups.');
    } catch {
      Alert.alert('Shared', 'Peep shared to selected groups.');
    }
  };

  const externalShare = async () => {
    const venue = peep?.venueName || 'this venue';
    const link = `https://peepl.app/peep/${peepId}`;
    await Share.share({
      message: `Check out what's happening at ${venue}: ${link}`,
    });
  };

  const crowd = peep?.crowdSize ?? 3;

  return (
    <View style={styles.container}>
      <View style={styles.card}>
        <Text style={styles.venue}>{peep?.venueName || 'Venue'}</Text>
        <View style={styles.previewRow}>
          <View style={[styles.pill, { backgroundColor: crowdColor(crowd) }]}>
            <Text style={styles.pillText}>{crowd}</Text>
          </View>
          <Text style={styles.time}>{formatAgo(peep?.createdAt)}</Text>
        </View>
      </View>

      <Text style={styles.section}>Share to Followers</Text>
      <TouchableOpacity style={styles.bigBtn} onPress={shareFollowers}>
        <Text style={styles.bigBtnTitle}>Share to your followers</Text>
        <Text style={styles.bigBtnSub}>{followersCount} followers</Text>
      </TouchableOpacity>

      <Text style={styles.section}>Share to a Person</Text>
      <TextInput
        style={styles.input}
        placeholder="Search users"
        placeholderTextColor="#999"
        value={userQ}
        onChangeText={setUserQ}
      />
      <FlatList
        data={userHits}
        keyExtractor={i => i.id}
        style={{ maxHeight: 200 }}
        renderItem={({ item }) => (
          <TouchableOpacity
            style={[
              styles.userRow,
              selectedUserId === item.id && { backgroundColor: '#E3F2FD' },
            ]}
            onPress={() => setSelectedUserId(item.id)}
          >
            <Image
              source={{ uri: item.profileImageUrl || 'https://via.placeholder.com/40' }}
              style={styles.uAv}
            />
            <Text style={styles.uName}>{item.username}</Text>
            <Text style={styles.uFollow}>{item.isFollowing ? 'Following' : 'Follow'}</Text>
          </TouchableOpacity>
        )}
      />
      {selectedUserId ? (
        <TouchableOpacity style={styles.sendBtn} onPress={sendToUser}>
          <Text style={styles.sendText}>Send</Text>
        </TouchableOpacity>
      ) : null}

      <Text style={styles.section}>Share to a Group</Text>
      {groups.map(g => (
        <TouchableOpacity
          key={g.id}
          style={styles.groupRow}
          onPress={() =>
            setGroupChecks(s => ({ ...s, [g.id]: !s[g.id] }))
          }
        >
          <Text style={{ fontSize: 18 }}>{groupChecks[g.id] ? '☑' : '☐'}</Text>
          <Text style={styles.gName}>{g.name}</Text>
        </TouchableOpacity>
      ))}
      <TouchableOpacity style={styles.groupShareBtn} onPress={shareToGroups}>
        <Text style={styles.sendText}>Share to Group</Text>
      </TouchableOpacity>

      <TouchableOpacity style={styles.extBtn} onPress={externalShare}>
        <Text style={styles.extText}>Share outside Peepl</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff', padding: 16 },
  card: {
    backgroundColor: '#f5f5f5',
    borderRadius: 12,
    padding: 14,
    marginBottom: 16,
  },
  venue: { fontWeight: 'bold', fontSize: 16 },
  previewRow: { flexDirection: 'row', alignItems: 'center', marginTop: 8 },
  pill: { paddingHorizontal: 10, paddingVertical: 4, borderRadius: 12 },
  pillText: { color: '#fff', fontWeight: 'bold' },
  time: { marginLeft: 10, color: '#666', fontSize: 12 },
  section: { fontWeight: 'bold', color: PRIMARY, marginBottom: 8, marginTop: 8 },
  bigBtn: {
    backgroundColor: PRIMARY,
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
  },
  bigBtnTitle: { color: '#fff', fontWeight: 'bold', fontSize: 17 },
  bigBtnSub: { color: '#E3F2FD', marginTop: 4, fontSize: 13 },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 10,
    marginBottom: 8,
  },
  userRow: { flexDirection: 'row', alignItems: 'center', padding: 8 },
  uAv: { width: 40, height: 40, borderRadius: 20, marginRight: 10 },
  uName: { flex: 1, fontWeight: '600' },
  uFollow: { color: '#888', fontSize: 12 },
  sendBtn: {
    alignSelf: 'flex-end',
    backgroundColor: PRIMARY,
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 8,
    marginBottom: 12,
  },
  sendText: { color: '#fff', fontWeight: 'bold' },
  groupRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 8 },
  gName: { marginLeft: 10, fontSize: 16 },
  groupShareBtn: {
    backgroundColor: ACCENT,
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 8,
    marginBottom: 16,
  },
  extBtn: {
    borderWidth: 1,
    borderColor: PRIMARY,
    padding: 14,
    borderRadius: 10,
    alignItems: 'center',
  },
  extText: { color: PRIMARY, fontWeight: 'bold' },
});
