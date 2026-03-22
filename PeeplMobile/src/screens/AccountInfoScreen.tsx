import React, { useCallback, useEffect, useLayoutEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TextInput,
  TouchableOpacity,
  Image,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { launchImageLibrary, MediaType } from 'react-native-image-picker';
import auth from '@react-native-firebase/auth';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';

type Nav = StackNavigationProp<RootStackParamList, 'AccountInfo'>;

type Props = { navigation: Nav };

type Profile = {
  firstName?: string;
  lastName?: string;
  username?: string;
  bio?: string;
  email?: string;
  phone?: string;
  profileImageUrl?: string;
  createdAt?: string;
  isVIP?: boolean;
};

function memberSinceLabel(raw?: string | { seconds?: number } | null): string {
  if (raw == null) return 'Member since —';
  let ms: number;
  if (typeof raw === 'object' && raw !== null && 'seconds' in raw && raw.seconds != null) {
    ms = Number(raw.seconds) * 1000;
  } else if (typeof raw === 'string') {
    ms = new Date(raw).getTime();
  } else {
    return 'Member since —';
  }
  if (Number.isNaN(ms)) return 'Member since —';
  const d = new Date(ms);
  return `Member since ${d.toLocaleString('en-US', { month: 'long', year: 'numeric' })}`;
}

export default function AccountInfoScreen({ navigation }: Props) {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [initial, setInitial] = useState<Profile | null>(null);
  const [fullName, setFullName] = useState('');
  const [username, setUsername] = useState('');
  const [bio, setBio] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [profileImageUrl, setProfileImageUrl] = useState<string | undefined>();

  const splitName = (name: string) => {
    const t = name.trim();
    if (!t) return { firstName: '', lastName: '' };
    const i = t.indexOf(' ');
    if (i === -1) return { firstName: t, lastName: '' };
    return { firstName: t.slice(0, i), lastName: t.slice(i + 1).trim() };
  };

  const initialFullName = useMemo(() => {
    if (!initial) return '';
    return `${initial.firstName ?? ''} ${initial.lastName ?? ''}`.trim();
  }, [initial]);

  const dirty = useMemo(() => {
    if (!initial) return false;
    return (
      fullName.trim() !== initialFullName ||
      username !== (initial.username ?? '') ||
      bio !== (initial.bio ?? '') ||
      phone !== (initial.phone ?? '') ||
      profileImageUrl !== (initial.profileImageUrl ?? '')
    );
  }, [initial, initialFullName, fullName, username, bio, phone, profileImageUrl]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const u = await authService.getCurrentUser();
      const fb = auth().currentUser;
      const p: Profile = {
        firstName: u?.firstName,
        lastName: u?.lastName,
        username: u?.username,
        bio: u?.bio,
        email: u?.email || fb?.email || '',
        phone: (u as Profile)?.phone,
        profileImageUrl: u?.profileImageUrl,
        createdAt: u?.createdAt as string | { seconds?: number } | undefined,
        isVIP: (u as Profile)?.isVIP,
      };
      setInitial(p);
      setFullName(`${p.firstName ?? ''} ${p.lastName ?? ''}`.trim());
      setUsername(p.username ?? '');
      setBio(p.bio ?? '');
      setPhone(p.phone ?? '');
      setEmail(p.email ?? '');
      setProfileImageUrl(p.profileImageUrl);
    } catch {
      setInitial({});
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const save = useCallback(async () => {
    if (!dirty || !initial) return;
    setSaving(true);
    try {
      const body: Record<string, string | undefined> = {};
      const { firstName: fn, lastName: ln } = splitName(fullName);
      if (fn !== (initial.firstName ?? '')) body.firstName = fn;
      if (ln !== (initial.lastName ?? '')) body.lastName = ln;
      if (username !== (initial.username ?? '')) body.username = username;
      if (bio !== (initial.bio ?? '')) body.bio = bio;
      if (phone !== (initial.phone ?? '')) body.phone = phone;
      if (profileImageUrl !== (initial.profileImageUrl ?? '')) body.profileImageUrl = profileImageUrl;

      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/users/profile`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify(body),
      });
      if (!res.ok) throw new Error('Save failed');
      await load();
      Alert.alert('Saved', 'Your profile was updated.');
    } catch {
      Alert.alert('Error', 'Could not save profile.');
    } finally {
      setSaving(false);
    }
  }, [dirty, initial, fullName, username, bio, phone, profileImageUrl, load]);

  useLayoutEffect(() => {
    navigation.setOptions({
      headerRight: () => (
        <TouchableOpacity onPress={save} disabled={!dirty || saving} style={{ marginRight: 16 }}>
          <Text style={{ color: dirty && !saving ? ACCENT : '#999', fontWeight: '700', fontSize: 16 }}>
            Save
          </Text>
        </TouchableOpacity>
      ),
    });
  }, [navigation, save, dirty, saving]);

  const pickPhoto = () => {
    launchImageLibrary({ mediaType: 'photo' as MediaType, quality: 0.85 }, res => {
      if (res.didCancel || res.errorMessage || !res.assets?.[0]?.uri) return;
      setProfileImageUrl(res.assets[0].uri);
    });
  };

  const sendReset = async () => {
    const em = email || auth().currentUser?.email;
    if (!em) return;
    try {
      await auth().sendPasswordResetEmail(em);
      Alert.alert('Reset email sent', 'Check your inbox for instructions.');
    } catch {
      Alert.alert('Error', 'Could not send reset email.');
    }
  };

  const deleteAccount = () => {
    Alert.alert(
      'Delete account',
      'This will permanently delete your account and data. This cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              const token = await authService.getIdToken();
              const r = await fetch(`${BASE_URL}/users/account`, {
                method: 'DELETE',
                headers: {
                  'Content-Type': 'application/json',
                  ...(token ? { Authorization: `Bearer ${token}` } : {}),
                },
              });
              if (!r.ok) throw new Error('fail');
              await authService.signOut();
            } catch {
              Alert.alert('Error', 'Could not delete account right now.');
            }
          },
        },
      ]
    );
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={ACCENT} size="large" />
      </View>
    );
  }

  const isVip = !!initial?.isVIP;

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
      <View style={styles.photoBlock}>
        <Image
          source={{ uri: profileImageUrl || 'https://via.placeholder.com/160' }}
          style={styles.avatar}
        />
        <TouchableOpacity onPress={pickPhoto}>
          <Text style={styles.changePhoto}>Change photo</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.label}>Full Name</Text>
      <TextInput
        style={styles.input}
        value={`${firstName}${firstName && lastName ? ' ' : ''}${lastName}`.trim() === '' ? '' : `${firstName}${firstName && lastName ? ' ' : ''}${lastName}`}
        onChangeText={t => {
          const parts = t.trim().split(/\s+/);
          if (parts.length <= 1) {
            setFirstName(parts[0] || '');
            setLastName('');
          } else {
            setFirstName(parts[0] || '');
            setLastName(parts.slice(1).join(' '));
          }
        }}
        placeholder="First Last"
        placeholderTextColor="#999"
      />
      <Text style={styles.hint}>First and last name (editable as one field)</Text>
      <TextInput
        style={[styles.input, { marginTop: 8 }]}
        value={firstName}
        onChangeText={setFirstName}
        placeholder="First name"
        placeholderTextColor="#999"
      />
      <TextInput
        style={styles.input}
        value={lastName}
        onChangeText={setLastName}
        placeholder="Last name"
        placeholderTextColor="#999"
      />

      <Text style={styles.label}>Username</Text>
      <TextInput
        style={styles.input}
        value={username}
        onChangeText={setUsername}
        autoCapitalize="none"
        placeholderTextColor="#999"
      />

      <Text style={styles.label}>Bio</Text>
      <TextInput
        style={[styles.input, styles.bio]}
        value={bio}
        onChangeText={t => setBio(t.slice(0, 160))}
        multiline
        maxLength={160}
        placeholderTextColor="#999"
      />
      <Text style={styles.counter}>{bio.length}/160</Text>

      <Text style={styles.label}>Email</Text>
      <TextInput style={[styles.input, styles.disabled]} value={email} editable={false} />

      <Text style={styles.label}>Phone (optional)</Text>
      <TextInput
        style={styles.input}
        value={phone}
        onChangeText={setPhone}
        keyboardType="phone-pad"
        placeholderTextColor="#999"
        placeholder="Phone number"
      />

      <Text style={styles.section}>Account</Text>
      <Text style={styles.meta}>{memberSinceLabel(initial?.createdAt as string | { seconds?: number } | undefined)}</Text>
      <View style={styles.planRow}>
        <Text style={styles.meta}>Plan: {isVip ? 'VIPeeps' : 'Free'}</Text>
        {!isVip ? (
          <TouchableOpacity onPress={() => navigation.navigate('VIPeeps')}>
            <Text style={styles.upgrade}>Upgrade →</Text>
          </TouchableOpacity>
        ) : null}
      </View>

      <TouchableOpacity style={styles.linkBtn} onPress={sendReset}>
        <Text style={styles.linkBtnText}>Change Password</Text>
        <Text style={styles.subtle}>Sends a Firebase password reset email</Text>
      </TouchableOpacity>

      <Text style={styles.section}>Data & Privacy</Text>
      <TouchableOpacity onPress={() => Alert.alert('Data export', 'Data export coming soon')}>
        <Text style={styles.rowLink}>Download my data</Text>
      </TouchableOpacity>
      <TouchableOpacity onPress={deleteAccount}>
        <Text style={styles.destructive}>Delete account</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  content: { padding: 16, paddingBottom: 40 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  photoBlock: { alignItems: 'center', marginBottom: 20 },
  avatar: { width: 80, height: 80, borderRadius: 40, backgroundColor: '#eee' },
  changePhoto: { color: PRIMARY, marginTop: 8, fontWeight: '600' },
  label: { fontSize: 12, color: '#888', marginBottom: 6, marginTop: 12 },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    color: '#111',
    backgroundColor: '#fff',
  },
  bio: { minHeight: 88, textAlignVertical: 'top' },
  disabled: { backgroundColor: '#f0f0f0', color: '#888' },
  counter: { alignSelf: 'flex-end', fontSize: 12, color: '#888', marginTop: 4 },
  section: { marginTop: 28, marginBottom: 10, fontSize: 15, fontWeight: '700', color: PRIMARY },
  meta: { fontSize: 14, color: '#444', marginBottom: 6 },
  planRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  upgrade: { color: ACCENT, fontWeight: '700' },
  linkBtn: { marginTop: 16, paddingVertical: 12 },
  linkBtnText: { fontSize: 16, color: PRIMARY, fontWeight: '600' },
  subtle: { fontSize: 12, color: '#888', marginTop: 4 },
  rowLink: { fontSize: 16, color: PRIMARY, paddingVertical: 10 },
  destructive: { fontSize: 16, color: '#c62828', paddingVertical: 10, marginTop: 8 },
});
