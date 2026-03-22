import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Image,
  ImageBackground,
  Share,
  Alert,
  ActivityIndicator,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import Icon from 'react-native-vector-icons/MaterialIcons';
import auth from '@react-native-firebase/auth';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';

type ProfileUser = {
  uid?: string;
  username: string;
  firstName?: string;
  lastName?: string;
  email?: string;
  profileImageUrl?: string;
  pioneerCount?: number;
  peepsCount?: number;
  points?: number;
  followersCount?: number;
  followingCount?: number;
};

interface ProfileScreenProps {
  navigation: StackNavigationProp<RootStackParamList, 'Profile'>;
}

export default function ProfileScreen({ navigation }: ProfileScreenProps) {
  const [user, setUser] = useState<ProfileUser | null>(null);
  const [loading, setLoading] = useState(true);

  const rootNav = navigation.getParent() ?? navigation;

  const loadProfile = useCallback(async () => {
    const uid = auth().currentUser?.uid;
    if (!uid) {
      setUser(null);
      setLoading(false);
      return;
    }
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/users/${uid}`, {
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) {
        const fallback = await authService.getCurrentUser();
        if (fallback) {
          setUser({
            username: fallback.username,
            firstName: fallback.firstName,
            lastName: fallback.lastName,
            email: fallback.email,
            profileImageUrl: fallback.profileImageUrl,
            uid: fallback.uid,
          });
        }
        return;
      }
      const data = (await res.json()) as Record<string, unknown>;
      setUser({
        uid: String(data.uid ?? data.id ?? uid),
        username: String(data.username ?? ''),
        firstName: data.firstName != null ? String(data.firstName) : undefined,
        lastName: data.lastName != null ? String(data.lastName) : undefined,
        email: data.email != null ? String(data.email) : undefined,
        profileImageUrl: data.profileImageUrl ? String(data.profileImageUrl) : undefined,
        pioneerCount: data.pioneerCount != null ? Number(data.pioneerCount) : 0,
        peepsCount: data.peepsCount != null ? Number(data.peepsCount) : Number(data.peepCount ?? 0),
        points: data.points != null ? Number(data.points) : 0,
        followersCount:
          data.followersCount != null ? Number(data.followersCount) : Number(data.followers ?? 0),
        followingCount:
          data.followingCount != null ? Number(data.followingCount) : Number(data.following ?? 0),
      });
    } catch {
      const fallback = await authService.getCurrentUser();
      if (fallback) {
        setUser({
          username: fallback.username,
          firstName: fallback.firstName,
          lastName: fallback.lastName,
          email: fallback.email,
          profileImageUrl: fallback.profileImageUrl,
          uid: fallback.uid,
        });
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadProfile();
  }, [loadProfile]);

  const displayName =
    user?.firstName || user?.lastName
      ? `${user?.firstName ?? ''} ${user?.lastName ?? ''}`.trim()
      : user?.username ?? 'Peepl user';

  const onSharePeepl = async () => {
    try {
      await Share.share({
        message: 'Check out Peepl — know before you go. https://peepl.app/download',
      });
    } catch {
      // ignore
    }
  };

  const onLogout = () => {
    Alert.alert('Log out', 'Are you sure you want to log out?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Log Out',
        style: 'destructive',
        onPress: async () => {
          await authService.logout();
        },
      },
    ]);
  };

  const go = (screen: string, params?: object) => {
    (rootNav as { navigate: (name: string, p?: object) => void }).navigate(screen, params);
  };

  if (loading) {
    return (
      <View style={styles.loadingWrap}>
        <ActivityIndicator size="large" color={ACCENT} />
      </View>
    );
  }

  if (!user) {
    return (
      <View style={styles.loadingWrap}>
        <Text style={styles.errText}>Could not load profile</Text>
      </View>
    );
  }

  const uid = auth().currentUser?.uid ?? user.uid ?? '';

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollContent}>
      <View style={styles.heroWrap}>
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
        {user.username ? <Text style={styles.handle}>@{user.username}</Text> : null}
        {(user.pioneerCount ?? 0) > 0 ? (
          <View style={styles.pioneerPill}>
            <Text style={styles.pioneerPillText}>⭐ {user.pioneerCount} Pioneer</Text>
          </View>
        ) : null}
      </View>

      <View style={styles.statsRow}>
        <TouchableOpacity style={styles.statCard} onPress={() => go('MyPeeps')} activeOpacity={0.8}>
          <Text style={styles.statNum}>{user.peepsCount ?? 0}</Text>
          <Text style={styles.statLbl}>Peeps</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.statCard} onPress={() => go('Leaderboard')} activeOpacity={0.8}>
          <Text style={styles.statNum}>{user.points ?? 0}</Text>
          <Text style={styles.statLbl}>Points</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.statCard}
          onPress={() => go('FollowList', { userId: uid, type: 'followers' })}
          activeOpacity={0.8}
        >
          <Text style={styles.statNum}>{user.followersCount ?? 0}</Text>
          <Text style={styles.statLbl}>Followers</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.statCard}
          onPress={() => go('FollowList', { userId: uid, type: 'following' })}
          activeOpacity={0.8}
        >
          <Text style={styles.statNum}>{user.followingCount ?? 0}</Text>
          <Text style={styles.statLbl}>Following</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.menu}>
        <MenuRow icon="chat-bubble-outline" label="My Peeps" onPress={() => go('MyPeeps')} />
        <MenuRow icon="favorite-border" label="Favorites" onPress={() => go('Favorites')} />
        <MenuRow icon="leaderboard" label="Points & Leaderboard" onPress={() => go('Leaderboard')} />
        <MenuRow
          icon="thumb-up-off-alt"
          label="Likes"
          onPress={() => Alert.alert('Likes', 'Coming soon.')}
        />
        <MenuRow icon="star-outline" label="Places Pioneered" onPress={() => go('Pioneers')} />
        <MenuRow icon="group" label="Groups" onPress={() => go('Groups')} />
        <MenuRow icon="share" label="Share Peepl" onPress={onSharePeepl} />
        <MenuRow icon="storefront" label="Merchant / Advertise" onPress={() => go('MerchantSignIn')} />
        <MenuRow icon="settings" label="Settings" onPress={() => go('Settings')} />
        <MenuRow icon="logout" label="Log Out" onPress={onLogout} danger />
      </View>
    </ScrollView>
  );
}

function MenuRow({
  icon,
  label,
  onPress,
  danger,
}: {
  icon: string;
  label: string;
  onPress: () => void;
  danger?: boolean;
}) {
  return (
    <TouchableOpacity style={styles.menuRow} onPress={onPress} activeOpacity={0.7}>
      <Icon name={icon} size={22} color={danger ? '#C62828' : PRIMARY} />
      <Text style={[styles.menuLabel, danger && styles.menuLabelDanger]}>{label}</Text>
      <Icon name="chevron-right" size={22} color="#BDBDBD" />
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  scroll: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  scrollContent: {
    paddingBottom: 40,
  },
  loadingWrap: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5F5F5',
  },
  errText: {
    color: '#666',
  },
  heroWrap: {
    position: 'relative',
    marginBottom: 44,
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
    paddingBottom: 20,
    backgroundColor: PRIMARY,
    marginTop: -1,
  },
  name: {
    color: '#FFFFFF',
    fontSize: 22,
    fontWeight: 'bold',
    textAlign: 'center',
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
    marginTop: 20,
    marginBottom: 8,
  },
  statCard: {
    flex: 1,
    backgroundColor: '#FFFFFF',
    marginHorizontal: 4,
    borderRadius: 12,
    paddingVertical: 12,
    alignItems: 'center',
    elevation: 1,
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 1 },
  },
  statNum: {
    fontSize: 18,
    fontWeight: 'bold',
    color: PRIMARY,
  },
  statLbl: {
    fontSize: 11,
    color: '#757575',
    marginTop: 4,
  },
  menu: {
    backgroundColor: '#FFFFFF',
    marginHorizontal: 12,
    borderRadius: 12,
    overflow: 'hidden',
    marginTop: 8,
  },
  menuRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 14,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  menuLabel: {
    flex: 1,
    marginLeft: 12,
    fontSize: 16,
    color: '#212121',
  },
  menuLabelDanger: {
    color: '#C62828',
    fontWeight: '600',
  },
});
