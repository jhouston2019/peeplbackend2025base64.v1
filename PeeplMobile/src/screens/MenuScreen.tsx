import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  TouchableOpacity,
  Animated,
  Dimensions,
  ScrollView,
  Image,
  TouchableWithoutFeedback,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import {
  createNavigationContainerRef,
  NavigationContainerRefWithCurrent,
} from '@react-navigation/native';
import { MainTabsParamList, RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';
import auth from '@react-native-firebase/auth';

const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';
const { width: W } = Dimensions.get('window');
const DRAWER_W = Math.min(W * 0.88, 340);

export const navigationRef =
  createNavigationContainerRef<RootStackParamList>() as NavigationContainerRefWithCurrent<RootStackParamList>;

type MenuCtx = {
  openMenu: () => void;
  closeMenu: () => void;
};

const MenuContext = createContext<MenuCtx | null>(null);

export function useMenuDrawer(): MenuCtx {
  const v = useContext(MenuContext);
  if (!v) {
    return { openMenu: () => {}, closeMenu: () => {} };
  }
  return v;
}

type Row = { icon: string; label: string; screen: keyof RootStackParamList; params?: object };

const DISCOVER: Row[] = [
  { icon: 'dynamic-feed', label: 'Feed', screen: 'GetPeeps' },
  { icon: 'visibility', label: 'Get Peeps', screen: 'GetPeeps' },
  { icon: 'search', label: 'Search', screen: 'Search' },
  { icon: 'map', label: 'Map', screen: 'MainTabs', params: { screen: 'Map' } },
  { icon: 'local-offer', label: 'Deals', screen: 'Deals' },
];

const SOCIAL: Row[] = [
  { icon: 'person-add', label: 'Invite Friends', screen: 'Invite' },
  { icon: 'emoji-events', label: 'Leaderboard', screen: 'Leaderboard' },
  { icon: 'star', label: 'Pioneers', screen: 'Pioneers' },
  { icon: 'group', label: 'Groups', screen: 'Groups' },
  { icon: 'notifications', label: 'Notifications', screen: 'Notifications' },
];

const ACCOUNT: Row[] = [
  { icon: 'person', label: 'Profile', screen: 'MainTabs', params: { screen: 'Profile' } },
  { icon: 'badge', label: 'Account Info', screen: 'AccountInfo' },
  { icon: 'favorite', label: 'Favorites', screen: 'Favorites' },
  { icon: 'workspace-premium', label: 'VIPeeps', screen: 'VIPeeps' },
  { icon: 'photo-library', label: 'My Peeps', screen: 'MyPeeps' },
  { icon: 'settings', label: 'Settings', screen: 'Settings' },
];

export function MenuProvider({ children }: { children: React.ReactNode }) {
  const [visible, setVisible] = useState(false);
  const slide = useRef(new Animated.Value(-DRAWER_W)).current;

  const openMenu = useCallback(() => {
    setVisible(true);
    Animated.timing(slide, {
      toValue: 0,
      duration: 260,
      useNativeDriver: true,
    }).start();
  }, [slide]);

  const closeMenu = useCallback(() => {
    Animated.timing(slide, {
      toValue: -DRAWER_W,
      duration: 220,
      useNativeDriver: true,
    }).start(() => setVisible(false));
  }, [slide]);

  const ctx = useMemo(() => ({ openMenu, closeMenu }), [openMenu, closeMenu]);

  const [userCard, setUserCard] = useState<{
    name: string;
    avatar?: string;
    pioneerCount: number;
    points: number;
  }>({ name: 'Peepl', pioneerCount: 0, points: 0 });

  useEffect(() => {
    if (!visible) return;
    (async () => {
      try {
        const uid = auth().currentUser?.uid;
        if (!uid) return;
        const token = await authService.getIdToken();
        const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
        const res = await fetch(`${BASE_URL}/users/${uid}`, {
          headers: {
            'Content-Type': 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        });
        if (!res.ok) return;
        const u = await res.json();
        const name =
          [u.firstName, u.lastName].filter(Boolean).join(' ') || u.username || 'User';
        setUserCard({
          name,
          avatar: u.profileImageUrl,
          pioneerCount: Number(u.pioneerCount || 0),
          points: Number(u.points || 0),
        });
      } catch {
        /* ignore */
      }
    })();
  }, [visible]);

  const go = (r: Row) => {
    closeMenu();
    setTimeout(() => {
      if (!navigationRef.isReady()) return;
      if (r.screen === 'MainTabs' && r.params && 'screen' in r.params) {
        navigationRef.navigate('MainTabs', {
          screen: (r.params as { screen: keyof MainTabsParamList }).screen,
        });
      } else {
        navigationRef.navigate(r.screen as keyof RootStackParamList, r.params as never);
      }
    }, 200);
  };

  return (
    <MenuContext.Provider value={ctx}>
      {children}
      <Modal visible={visible} transparent animationType="none" onRequestClose={closeMenu}>
        <View style={styles.modalRoot}>
          <TouchableWithoutFeedback onPress={closeMenu}>
            <View style={styles.scrim} />
          </TouchableWithoutFeedback>
          <Animated.View style={[styles.drawer, { transform: [{ translateX: slide }] }]}>
            <ScrollView contentContainerStyle={styles.drawerScroll}>
              <View style={styles.userCard}>
                <Image
                  source={{ uri: userCard.avatar || 'https://via.placeholder.com/120' }}
                  style={styles.avatar}
                />
                <Text style={styles.displayName}>{userCard.name}</Text>
                {userCard.pioneerCount > 0 ? (
                  <View style={styles.pioneerBadge}>
                    <Text style={styles.pioneerText}>⭐ Pioneer</Text>
                  </View>
                ) : (
                  <TouchableOpacity
                    onPress={() => {
                      closeMenu();
                      setTimeout(() => {
                        if (navigationRef.isReady()) {
                          navigationRef.navigate('MainTabs', { screen: 'Map' });
                        }
                      }, 200);
                    }}
                  >
                    <Text style={styles.startPeep}>Start Peeping →</Text>
                  </TouchableOpacity>
                )}
                <Text style={styles.points}>{userCard.points} points</Text>
              </View>

              <Text style={styles.secLabel}>Discover</Text>
              {DISCOVER.map(row => (
                <TouchableOpacity key={row.label} style={styles.row} onPress={() => go(row)}>
                  <Icon name={row.icon} size={20} color={PRIMARY} />
                  <Text style={styles.rowLabel}>{row.label}</Text>
                  <Text style={styles.chev}>›</Text>
                </TouchableOpacity>
              ))}

              <Text style={styles.secLabel}>Social</Text>
              {SOCIAL.map(row => (
                <TouchableOpacity key={row.label} style={styles.row} onPress={() => go(row)}>
                  <Icon name={row.icon} size={20} color={PRIMARY} />
                  <Text style={styles.rowLabel}>{row.label}</Text>
                  <Text style={styles.chev}>›</Text>
                </TouchableOpacity>
              ))}

              <Text style={styles.secLabel}>Account</Text>
              {ACCOUNT.map(row => (
                <TouchableOpacity key={row.label} style={styles.row} onPress={() => go(row)}>
                  <Icon name={row.icon} size={20} color={PRIMARY} />
                  <Text style={styles.rowLabel}>{row.label}</Text>
                  <Text style={styles.chev}>›</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
          </Animated.View>
        </View>
      </Modal>
    </MenuContext.Provider>
  );
}

export function MenuHamburger() {
  const { openMenu } = useMenuDrawer();
  return (
    <TouchableOpacity onPress={openMenu} style={{ paddingLeft: 16, paddingVertical: 8 }}>
      <Icon name="menu" size={28} color="#fff" />
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  modalRoot: { flex: 1, flexDirection: 'row' },
  scrim: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.45)' },
  drawer: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: DRAWER_W,
    backgroundColor: '#fff',
    elevation: 8,
    shadowColor: '#000',
    shadowOpacity: 0.2,
    shadowRadius: 8,
  },
  drawerScroll: { paddingBottom: 40 },
  userCard: {
    backgroundColor: PRIMARY,
    padding: 20,
    minHeight: 140,
    paddingTop: 48,
  },
  avatar: { width: 60, height: 60, borderRadius: 30, marginBottom: 8 },
  displayName: { color: '#fff', fontWeight: 'bold', fontSize: 18 },
  pioneerBadge: {
    alignSelf: 'flex-start',
    backgroundColor: ACCENT,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 8,
    marginTop: 6,
  },
  pioneerText: { fontWeight: 'bold', color: '#333', fontSize: 13 },
  startPeep: { color: '#E3F2FD', marginTop: 6, fontWeight: '600' },
  points: { color: '#fff', fontSize: 14, marginTop: 8 },
  secLabel: {
    color: '#888',
    fontSize: 12,
    fontWeight: '700',
    marginLeft: 16,
    marginTop: 16,
    marginBottom: 6,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
  },
  rowLabel: { flex: 1, marginLeft: 12, fontWeight: 'bold', fontSize: 15, color: '#222' },
  chev: { fontSize: 20, color: '#999' },
});
