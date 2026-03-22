import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  ScrollView,
  TextInput,
  TouchableOpacity,
  Image,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';

type Group = {
  id: string;
  name: string;
  photoUrl?: string | null;
  memberCount?: number;
  peepsToday?: number;
};

export default function GroupsScreen() {
  const [discover, setDiscover] = useState<Group[]>([]);
  const [mine, setMine] = useState<Group[]>([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState('');
  const [joined, setJoined] = useState<Record<string, boolean>>({});

  const load = useCallback(async () => {
    try {
      const token = await authService.getIdToken();
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      };
      const [dRes, mRes] = await Promise.all([
        fetch(`${BASE_URL}/groups`, { headers }),
        fetch(`${BASE_URL}/groups/mine`, { headers }),
      ]);
      const dJson = dRes.ok ? await dRes.json() : { groups: [] };
      const mJson = mRes.ok ? await mRes.json() : { groups: [] };
      const dList = (dJson.groups || []) as Group[];
      const mList = (mJson.groups || []) as Group[];
      setDiscover(dList);
      setMine(mList);
      const mineIds = new Set(mList.map(g => g.id));
      const j: Record<string, boolean> = {};
      dList.forEach(g => {
        j[g.id] = mineIds.has(g.id);
      });
      mList.forEach(g => {
        j[g.id] = true;
      });
      setJoined(j);
    } catch {
      setDiscover([]);
      setMine([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const filtered = useMemo(() => {
    const t = q.trim().toLowerCase();
    if (!t) return discover;
    return discover.filter(g => g.name.toLowerCase().includes(t));
  }, [discover, q]);

  const toggleJoin = async (g: Group) => {
    const isJoined = joined[g.id];
    const next = !isJoined;
    setJoined(s => ({ ...s, [g.id]: next }));
    try {
      const token = await authService.getIdToken();
      await fetch(`${BASE_URL}/groups/${g.id}/${next ? 'join' : 'leave'}`, {
        method: next ? 'POST' : 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      await load();
    } catch {
      setJoined(s => ({ ...s, [g.id]: isJoined }));
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
      <View style={styles.headerRow}>
        <Text style={styles.title}>Groups</Text>
        <TouchableOpacity
          onPress={() => Alert.alert('Create group', 'Create group coming soon')}
        >
          <Text style={styles.create}>+ Create</Text>
        </TouchableOpacity>
      </View>
      <TextInput
        style={styles.search}
        placeholder="Search groups"
        placeholderTextColor="#999"
        value={q}
        onChangeText={setQ}
      />

      {mine.length > 0 ? (
        <View style={styles.section}>
          <Text style={styles.sectionLabel}>Your Groups</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false}>
            {mine.map(g => (
              <View key={g.id} style={styles.yourCard}>
                <Image
                  source={{ uri: g.photoUrl || 'https://via.placeholder.com/200' }}
                  style={styles.yourImg}
                />
                <Text numberOfLines={2} style={styles.yourName}>
                  {g.name}
                </Text>
                <Text style={styles.yourMeta}>{g.peepsToday ?? 0} peeps today</Text>
              </View>
            ))}
          </ScrollView>
        </View>
      ) : null}

      <Text style={styles.sectionLabel}>Discover Groups</Text>
      <FlatList
        data={filtered}
        keyExtractor={g => g.id}
        renderItem={({ item }) => {
          const isJoined = joined[item.id];
          return (
            <View style={styles.row}>
              <Image
                source={{ uri: item.photoUrl || 'https://via.placeholder.com/120' }}
                style={styles.thumb}
              />
              <View style={{ flex: 1 }}>
                <Text style={styles.gname}>{item.name}</Text>
                <Text style={styles.meta}>
                  {item.memberCount ?? 0} members · {item.peepsToday ?? 0} peeps today
                </Text>
              </View>
              <TouchableOpacity
                style={[styles.joinBtn, isJoined && styles.joinedBtn]}
                onPress={() => toggleJoin(item)}
              >
                <Text style={[styles.joinText, isJoined && styles.joinedText]}>
                  {isJoined ? 'Joined' : 'Join'}
                </Text>
              </TouchableOpacity>
            </View>
          );
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 8,
  },
  title: { fontSize: 22, fontWeight: 'bold', color: PRIMARY },
  create: { color: ACCENT, fontWeight: 'bold', fontSize: 16 },
  search: {
    margin: 16,
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  section: { marginBottom: 8 },
  sectionLabel: {
    fontSize: 14,
    color: '#888',
    fontWeight: '600',
    marginLeft: 16,
    marginBottom: 8,
  },
  yourCard: {
    width: 140,
    height: 100,
    marginLeft: 16,
    borderRadius: 10,
    overflow: 'hidden',
    backgroundColor: '#eee',
  },
  yourImg: { width: '100%', height: 56 },
  yourName: { fontWeight: 'bold', fontSize: 13, paddingHorizontal: 8, marginTop: 4 },
  yourMeta: { fontSize: 11, color: '#666', paddingHorizontal: 8 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
    minHeight: 80,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: '#eee',
  },
  thumb: { width: 60, height: 60, borderRadius: 8, marginRight: 12 },
  gname: { fontWeight: 'bold', fontSize: 16 },
  meta: { fontSize: 12, color: '#888', marginTop: 4 },
  joinBtn: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: PRIMARY,
  },
  joinedBtn: { backgroundColor: '#E3F2FD', borderColor: '#E3F2FD' },
  joinText: { color: PRIMARY, fontWeight: '600', fontSize: 13 },
  joinedText: { color: PRIMARY },
});
