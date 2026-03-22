import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  FlatList,
  Share,
  Alert,
  Platform,
  PermissionsAndroid,
  RefreshControl,
} from 'react-native';
import Clipboard from '@react-native-clipboard/clipboard';
import auth from '@react-native-firebase/auth';
import AsyncStorage from '@react-native-async-storage/async-storage';
const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';

const INVITED_PREFIX = 'inviteSent:';

type ContactRow = {
  id: string;
  name: string;
  phone?: string;
  email?: string;
};

export default function InviteScreen() {
  const uid = auth().currentUser?.uid || 'user';
  const inviteLink = `https://peepl.app/invite/${uid}`;
  const [contacts, setContacts] = useState<ContactRow[]>([]);
  const [permDenied, setPermDenied] = useState(false);
  const [invited, setInvited] = useState<Record<string, boolean>>({});
  const [refreshing, setRefreshing] = useState(false);

  const loadInvited = useCallback(async () => {
    const keys = await AsyncStorage.getAllKeys();
    const pref = keys.filter(k => k.startsWith(INVITED_PREFIX));
    const next: Record<string, boolean> = {};
    await Promise.all(
      pref.map(async k => {
        const v = await AsyncStorage.getItem(k);
        if (v === '1') next[k.replace(INVITED_PREFIX, '')] = true;
      })
    );
    setInvited(next);
  }, []);

  useEffect(() => {
    loadInvited();
  }, [loadInvited]);

  const requestContactsPermission = async (): Promise<boolean> => {
    if (Platform.OS === 'android') {
      const g = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.READ_CONTACTS
      );
      return g === PermissionsAndroid.RESULTS.GRANTED;
    }
    try {
      const Contacts = require('react-native-contacts').default;
      const p = await Contacts.requestPermission();
      return p === 'authorized' || p === 'granted';
    } catch {
      return false;
    }
  };

  const loadContacts = async () => {
    const ok = await requestContactsPermission();
    if (!ok) {
      setPermDenied(true);
      setContacts([]);
      return;
    }
    setPermDenied(false);
    try {
      const Contacts = require('react-native-contacts').default;
      const list = await Contacts.getAll();
      const rows: ContactRow[] = list.map(
        (c: {
          recordID: string;
          givenName?: string;
          familyName?: string;
          phoneNumbers?: Array<{ number?: string }>;
          emailAddresses?: Array<{ email?: string }>;
        }) => ({
          id: c.recordID,
          name: [c.givenName, c.familyName].filter(Boolean).join(' ') || 'Contact',
          phone: c.phoneNumbers?.[0]?.number,
          email: c.emailAddresses?.[0]?.email,
        })
      );
      setContacts(rows);
    } catch (e) {
      Alert.alert('Contacts', 'Could not load contacts.');
      setContacts([]);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadContacts();
    setRefreshing(false);
  };

  const inviteContact = async (row: ContactRow) => {
    const key = row.phone || row.email || row.id;
    const msg = `Join me on Peepl — know before you go! ${inviteLink}`;
    try {
      if (Platform.OS === 'ios' && row.phone) {
        const { Linking } = require('react-native');
        const phone = row.phone.replace(/[^\d+]/g, '');
        await Linking.openURL(
          `sms:${phone}&body=${encodeURIComponent(msg)}`
        );
      } else {
        await Share.share({ message: msg });
      }
      await AsyncStorage.setItem(`${INVITED_PREFIX}${key}`, '1');
      setInvited(s => ({ ...s, [key]: true }));
    } catch {
      Alert.alert('Invite', 'Could not open SMS or share.');
    }
  };

  const copyLink = () => {
    Clipboard.setString(inviteLink);
    Alert.alert('Copied', 'Invite link copied to clipboard.');
  };

  const shareLink = async () => {
    await Share.share({
      message: `Join me on Peepl — know before you go! ${inviteLink}`,
    });
  };

  return (
    <View style={styles.container}>
      <Text style={styles.section}>Your invite link</Text>
      <Text selectable style={styles.link}>
        {inviteLink}
      </Text>
      <View style={styles.rowBtns}>
        <TouchableOpacity style={styles.btn} onPress={copyLink}>
          <Text style={styles.btnText}>Copy</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.btn, styles.btnGold]} onPress={shareLink}>
          <Text style={[styles.btnText, styles.btnTextDark]}>Share</Text>
        </TouchableOpacity>
      </View>

      <TouchableOpacity style={styles.loadBtn} onPress={loadContacts}>
        <Text style={styles.loadBtnText}>Load contacts</Text>
      </TouchableOpacity>
      {permDenied ? (
        <Text style={styles.denied}>
          Contacts permission was denied. You can enable it in system settings to invite friends.
        </Text>
      ) : null}

      <FlatList
        data={contacts}
        keyExtractor={c => c.id}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={ACCENT} />
        }
        renderItem={({ item }) => {
          const key = item.phone || item.email || item.id;
          const done = !!invited[key];
          return (
            <View style={styles.cRow}>
              <View style={{ flex: 1 }}>
                <Text style={styles.cName}>{item.name}</Text>
                <Text style={styles.cMeta}>{item.phone || item.email || ''}</Text>
              </View>
              <TouchableOpacity
                style={[styles.invBtn, done && styles.invDone]}
                onPress={() => !done && inviteContact(item)}
                disabled={done}
              >
                <Text style={done ? styles.invDoneText : styles.invText}>
                  {done ? 'Invited ✓' : 'Invite'}
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
  container: { flex: 1, backgroundColor: '#fff', padding: 16 },
  section: { fontWeight: 'bold', fontSize: 16, color: PRIMARY, marginBottom: 8 },
  link: { fontSize: 14, color: '#333', marginBottom: 12 },
  rowBtns: { flexDirection: 'row', gap: 12, marginBottom: 20 },
  btn: {
    flex: 1,
    backgroundColor: PRIMARY,
    padding: 14,
    borderRadius: 10,
    alignItems: 'center',
  },
  btnGold: { backgroundColor: ACCENT },
  btnText: { color: '#fff', fontWeight: 'bold' },
  btnTextDark: { color: '#333' },
  loadBtn: {
    alignSelf: 'flex-start',
    backgroundColor: '#E3F2FD',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
    marginBottom: 12,
  },
  loadBtnText: { color: PRIMARY, fontWeight: '600' },
  denied: { color: '#c62828', marginBottom: 12, fontSize: 13 },
  cRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: '#eee',
  },
  cName: { fontWeight: '600', fontSize: 15 },
  cMeta: { color: '#888', fontSize: 13, marginTop: 2 },
  invBtn: {
    backgroundColor: PRIMARY,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
  },
  invDone: { backgroundColor: '#ccc' },
  invText: { color: '#fff', fontWeight: '600' },
  invDoneText: { color: '#666', fontWeight: '600' },
});
