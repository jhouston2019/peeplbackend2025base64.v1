import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Switch,
  TouchableOpacity,
  Alert,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';

const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';

const KEYS = {
  venueEntry: 'settings:venueEntryAlerts',
  favVenue: 'settings:favVenueAlerts',
  deals: 'settings:dealAlerts',
  follower: 'settings:followerActivity',
};

type Nav = StackNavigationProp<RootStackParamList, 'Settings'>;

type Props = { navigation: Nav };

export default function SettingsScreen({ navigation }: Props) {
  const [venueEntry, setVenueEntry] = useState(true);
  const [favVenue, setFavVenue] = useState(true);
  const [deals, setDeals] = useState(true);
  const [follower, setFollower] = useState(true);
  const [locationSharing, setLocationSharing] = useState(true);
  const [publicProfile, setPublicProfile] = useState(true);

  const load = useCallback(async () => {
    const [a, b, c, d] = await Promise.all([
      AsyncStorage.getItem(KEYS.venueEntry),
      AsyncStorage.getItem(KEYS.favVenue),
      AsyncStorage.getItem(KEYS.deals),
      AsyncStorage.getItem(KEYS.follower),
    ]);
    if (a != null) setVenueEntry(a === '1');
    if (b != null) setFavVenue(b === '1');
    if (c != null) setDeals(c === '1');
    if (d != null) setFollower(d === '1');

    try {
      const u = await authService.getCurrentUser();
      if (u?.preferences) {
        setLocationSharing(u.preferences.locationSharing !== false);
        setPublicProfile(u.preferences.publicProfile !== false);
      }
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const persistToggle = async (key: string, val: boolean, setter: (v: boolean) => void) => {
    setter(val);
    await AsyncStorage.setItem(key, val ? '1' : '0');
  };

  const persistPrivacy = async (field: 'locationSharing' | 'publicProfile', val: boolean) => {
    if (field === 'locationSharing') setLocationSharing(val);
    else setPublicProfile(val);
    try {
      const cur = await authService.getCurrentUser();
      const loc = field === 'locationSharing' ? val : locationSharing;
      const pub = field === 'publicProfile' ? val : publicProfile;
      await authService.updateProfile({
        preferences: {
          notifications: cur?.preferences?.notifications ?? true,
          locationSharing: loc,
          publicProfile: pub,
        },
      } as Parameters<typeof authService.updateProfile>[0]);
    } catch {
      /* ignore */
    }
  };

  const logout = () => {
    Alert.alert('Log out', 'Are you sure you want to log out?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Log out',
        style: 'destructive',
        onPress: async () => {
          await authService.signOut();
        },
      },
    ]);
  };

  const row = (
    label: string,
    value: boolean,
    onValueChange: (v: boolean) => void
  ) => (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Switch
        value={value}
        onValueChange={onValueChange}
        trackColor={{ false: '#ccc', true: '#90CAF9' }}
        thumbColor={value ? PRIMARY : '#f4f3f4'}
      />
    </View>
  );

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.section}>Notifications</Text>
      {row('Venue entry alerts', venueEntry, v => persistToggle(KEYS.venueEntry, v, setVenueEntry))}
      {row('Favorited venue alerts', favVenue, v => persistToggle(KEYS.favVenue, v, setFavVenue))}
      {row('Deal alerts', deals, v => persistToggle(KEYS.deals, v, setDeals))}
      {row('Follower activity', follower, v => persistToggle(KEYS.follower, v, setFollower))}

      <Text style={styles.section}>Privacy</Text>
      {row('Location sharing', locationSharing, v => persistPrivacy('locationSharing', v))}
      {row('Public profile', publicProfile, v => persistPrivacy('publicProfile', v))}

      <Text style={styles.section}>Account</Text>
      <TouchableOpacity
        style={styles.linkRow}
        onPress={() => navigation.navigate('AccountInfo')}
      >
        <Text style={styles.linkLabel}>Account Info</Text>
        <Icon name="chevron-right" size={22} color="#999" />
      </TouchableOpacity>
      <TouchableOpacity
        style={styles.linkRow}
        onPress={() => navigation.navigate('VIPeeps')}
      >
        <Text style={styles.linkLabel}>VIPeeps</Text>
        <Icon name="chevron-right" size={22} color="#999" />
      </TouchableOpacity>
      <TouchableOpacity
        style={styles.linkRow}
        onPress={() => navigation.navigate('MyPeeps')}
      >
        <Text style={styles.linkLabel}>My Peeps</Text>
        <Icon name="chevron-right" size={22} color="#999" />
      </TouchableOpacity>
      <TouchableOpacity
        style={styles.linkRow}
        onPress={() => Alert.alert('Support', 'Support: support@peepl.app')}
      >
        <Text style={styles.linkLabel}>Help & Support</Text>
        <Icon name="chevron-right" size={22} color="#999" />
      </TouchableOpacity>
      <TouchableOpacity style={styles.linkRow} onPress={logout}>
        <Text style={[styles.linkLabel, { color: '#c62828' }]}>Log Out</Text>
        <Icon name="chevron-right" size={22} color="#999" />
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  content: { paddingBottom: 40 },
  section: {
    marginTop: 20,
    marginBottom: 8,
    marginHorizontal: 16,
    fontSize: 13,
    fontWeight: '700',
    color: '#888',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: '#eee',
  },
  rowLabel: { flex: 1, fontSize: 16, color: '#222' },
  linkRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: '#eee',
  },
  linkLabel: { fontSize: 16, fontWeight: '600', color: '#222' },
});
