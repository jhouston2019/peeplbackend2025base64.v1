import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Image,
  ImageBackground,
  FlatList,
  ActivityIndicator,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import Icon from 'react-native-vector-icons/MaterialIcons';
import auth from '@react-native-firebase/auth';
import { RouteProp } from '@react-navigation/native';
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

type ProfileUser = {
  username: string;
  firstName?: string;
  lastName?: string;
  profileImageUrl?: string;
  pioneerCount?: number;
  peepsCount?: number;
  points?: number;
  followersCount?: number;
  followingCount?: number;
};

type Props = {
  route: RouteProp<RootStackParamList, 'UserProfile'>;
  navigation: StackNavigationProp<RootStackParamList, 'UserProfile'>;
};

export default function UserProfileScreen({ route, navigation }: Props) {
  const { userId } = route.params;
  const myUid = auth().currentUser?.uid;
  const [user, setUser] = useState<ProfileUser | null>(null);
  const [peeps, setPeeps] = useState<Peep[]>([]);
  const [loading, setLoading] = useState(true);
  const [following, setFollowing] = useState(false);
  const [followLoading, setFollowLoading] = useState(false);

  const load = useCallback(async () => {
    if (!userId) return;
    if (myUid && userId === myUid) return;
    setLoading(true);
    try {
      const token = await authService.getIdToken();
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      };
      const [uRes, pRes] = await Promise.all([
        fetch(`${BASE_URL}/users/${userId}`, { headers }),
        fetch(`${BASE_URL}/peeps?userId=${encodeURIComponent(userId)}`, { headers }),
      ]);
      if (uRes.ok) {
        const data = (await uRes.json()) as Record<string, unknown>;
        setUser({
          username: String(data.username ?? ''),
          firstName: data.firstName != null ? String(data.firstName) : undefined,
          lastName: data.lastName != null ? String(data.lastName) : undefined,
          profileImageUrl: data.profileImageUrl ? String(data.profileImageUrl) : undefined,
          pioneerCount: data.pioneerCount != null ? Number(data.pioneerCount) : 0,
          peepsCount: data.peepsCount != null ? Number(data.peepsCount) : Number(data.peepCount ?? 0),
          points: data.points != null ? Number(data.points) : 0,
          followersCount:
            data.followersCount != null ? Number(data.followersCount) : Number(data.followers ?? 0),
          followingCount:
            data.followingCount != null ? Number(data.followingCount) : Number(data.following ?? 0),
        });
        if (typeof data.isFollowing === 'boolean') {
          setFollowing(data.isFollowing);
        }
      }
      if (pRes.ok) {
        const pJson = await pRes.json();
        const list = Array.isArray(pJson) ? pJson : pJson.peeps || [];
        setPeeps(
          (list as Peep[]).sort(
            (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
          )
        );
      }
    } catch {
      setUser(null);
    } finally {
      setLoading(false);
    }
  }, [userId, myUid]);

  useEffect(() => {
    if (!userId) return;
    if (myUid && userId === myUid) {
      navigation.replace('MainTabs', { screen: 'Profile' });
      return;
    }
    load();
  }, [userId, myUid, navigation, load]);

  const toggleFollow = async () => {
    if (!userId) return;
    setFollowLoading(true);
    const next = !following;
    setFollowing(next);
    try {
      const token = await authService.getIdToken();
      await fetch(`${BASE_URL}/users/${userId}/follow`, {
        method: next ? 'POST' : 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
    } catch {
      setFollowing(!next);
    } finally {
      setFollowLoading(false);
    }
  };

  if (myUid && userId === myUid) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color={ACCENT} />
      </View>
    );
  }

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color={ACCENT} />
      </View>
    );
  }

  if (!user) {
    return (
      <View style={styles.center}>
        <Text style={styles.err}>User not found</Text>
      </View>
    );
  }

  const displayName =
    user.firstName || user.lastName
      ? `${user.firstName ?? ''} ${user.lastName ?? ''}`.trim()
      : user.username;

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollContent}>
      <View style={styles.heroWrap}>
        <TouchableOpacity style={styles.followTop} onPress={toggleFollow} disabled={followLoading}>
          <View style={[styles.followBtn, following && styles.followBtnOn]}>
            <Text style={[styles.followTxt, following && styles.followTxtOn]}>
              {following ? 'Following' : 'Follow'}
            </Text>
          </View>
        </TouchableOpacity>
        {user.profileImageUrl ? (
          <ImageBackground source={{ uri: user.profileImageUrl }} style={styles.heroImg} imageStyle={styles.heroImgInner}>
            <LinearGradient colors={['transparent', PRIMARY]} style={styles.heroGrad} />
          </ImageBackground>
        ) : (
          <View style={[styles.heroImg, styles.heroSolid]}>
            <LinearGradient colors={['transparent', PRIMARY]} style={styles.heroGrad} />
          </View>
        )}
        <View style={styles.avatarWrap}>
          {user.profileImageUrl ? (
            <Image source={{ uri: user.profileImageUrl }} style={styles.avatar} />
          ) : (
            <View style={[styles.avatar, styles.avatarPh]}>
              <Icon name="person" size={44} color="#FFFFFF" />
            </View>
          )}
        </View>
      </View>

      <View style={styles.nameBlock}>
        <Text style={styles.name}>{displayName}</Text>
        <Text style={styles.handle}>@{user.username}</Text>
        {(user.pioneerCount ?? 0) > 0 ? (
          <View style={styles.pioneerPill}>
            <Text style={styles.pioneerPillText}>⭐ {user.pioneerCount} Pioneer</Text>
          </View>
        ) : null}
      </View>

      <View style={styles.statsRow}>
        <View style={styles.statCard}>
          <Text style={styles.statNum}>{user.peepsCount ?? 0}</Text>
          <Text style={styles.statLbl}>Peeps</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statNum}>{user.points ?? 0}</Text>
          <Text style={styles.statLbl}>Points</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statNum}>{user.followersCount ?? 0}</Text>
          <Text style={styles.statLbl}>Followers</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statNum}>{user.followingCount ?? 0}</Text>
          <Text style={styles.statLbl}>Following</Text>
        </View>
      </View>

      <Text style={styles.sectionTitle}>Recent Peeps</Text>
      <FlatList
        data={peeps}
        scrollEnabled={false}
        keyExtractor={item => item.id}
        renderItem={({ item }) => (
          <View style={styles.peepRow}>
            <View style={styles.peepTop}>
              <Text style={styles.venueName}>{item.venue?.name ?? 'Venue'}</Text>
              <View style={[styles.crowdPill, { backgroundColor: crowdColor(item.crowdSize) }]}>
                <Text style={styles.crowdPillText}>{CROWD_LABELS[item.crowdSize - 1]}</Text>
              </View>
            </View>
            <Text style={styles.time}>{formatAgo(item.createdAt)}</Text>
          </View>
        )}
        ListEmptyComponent={<Text style={styles.emptyPeeps}>No peeps yet.</Text>}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  scrollContent: {
    paddingBottom: 32,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5F5F5',
  },
  err: {
    color: '#666',
  },
  heroWrap: {
    position: 'relative',
    marginBottom: 44,
  },
  followTop: {
    position: 'absolute',
    top: 12,
    right: 12,
    zIndex: 10,
  },
  followBtn: {
    borderWidth: 2,
    borderColor: '#FFFFFF',
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 8,
    backgroundColor: 'transparent',
  },
  followBtnOn: {
    backgroundColor: PRIMARY,
    borderColor: PRIMARY,
  },
  followTxt: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    fontSize: 14,
  },
  followTxtOn: {
    color: '#FFFFFF',
  },
  heroImg: {
    height: 200,
    width: '100%',
    justifyContent: 'flex-end',
  },
  heroImgInner: {
    resizeMode: 'cover',
  },
  heroSolid: {
    backgroundColor: PRIMARY,
  },
  heroGrad: {
    height: '50%',
    width: '100%',
  },
  avatarWrap: {
    position: 'absolute',
    bottom: -40,
    alignSelf: 'center',
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    borderWidth: 4,
    borderColor: '#FFFFFF',
    backgroundColor: PRIMARY,
  },
  avatarPh: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  nameBlock: {
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 48,
    paddingBottom: 16,
    backgroundColor: PRIMARY,
  },
  name: {
    color: '#FFFFFF',
    fontSize: 22,
    fontWeight: 'bold',
  },
  handle: {
    color: '#E3F2FD',
    marginTop: 4,
    fontSize: 15,
  },
  pioneerPill: {
    marginTop: 10,
    backgroundColor: ACCENT,
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 999,
  },
  pioneerPillText: {
    color: '#000000',
    fontWeight: 'bold',
    fontSize: 14,
  },
  statsRow: {
    flexDirection: 'row',
    marginHorizontal: 12,
    marginTop: 12,
    marginBottom: 16,
  },
  statCard: {
    flex: 1,
    backgroundColor: '#FFFFFF',
    marginHorizontal: 4,
    borderRadius: 12,
    paddingVertical: 12,
    alignItems: 'center',
  },
  statNum: {
    fontSize: 16,
    fontWeight: 'bold',
    color: PRIMARY,
  },
  statLbl: {
    fontSize: 10,
    color: '#757575',
    marginTop: 4,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: PRIMARY,
    marginHorizontal: 16,
    marginBottom: 8,
  },
  peepRow: {
    backgroundColor: '#FFFFFF',
    marginHorizontal: 12,
    marginBottom: 8,
    borderRadius: 10,
    padding: 12,
  },
  peepTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  venueName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#212121',
    flex: 1,
  },
  crowdPill: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
  },
  crowdPillText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
  },
  time: {
    fontSize: 12,
    color: '#9E9E9E',
    marginTop: 6,
  },
  emptyPeeps: {
    marginHorizontal: 16,
    color: '#757575',
    fontStyle: 'italic',
  },
});
