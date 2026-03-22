import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Image,
  ImageBackground,
  TouchableOpacity,
  TextInput,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';

type Props = {
  route: RouteProp<RootStackParamList, 'PeepDetail'>;
  navigation: StackNavigationProp<RootStackParamList, 'PeepDetail'>;
};

type PeepPayload = {
  id: string;
  userId?: string;
  crowdSize: number;
  mfRatio: number;
  akRatio: number;
  ageRanges?: string[];
  vibe?: string[];
  notes?: string;
  description?: string;
  createdAt?: string;
  imageUrl?: string;
  photoUrl?: string;
  likedByMe?: boolean;
  likeCount?: number;
  user?: {
    username: string;
    firstName?: string;
    lastName?: string;
    profileImageUrl?: string;
  };
  venue?: { name: string; id?: string };
  isPioneer?: boolean;
  likerPreview?: Array<{ userId: string; profileImageUrl?: string | null; username?: string }>;
};

type CommentRow = {
  id: string;
  text?: string;
  username?: string;
  userId?: string;
  createdAt?: string;
};

function crowdColor(size: number): string {
  if (size <= 2) return '#4CAF50';
  if (size === 3) return '#FFA726';
  return '#F44336';
}

function formatAgo(iso?: string | { seconds?: number }): string {
  if (!iso) return '';
  let ms: number;
  if (typeof iso === 'object' && iso?.seconds != null) {
    ms = Number(iso.seconds) * 1000;
  } else if (typeof iso === 'string') {
    ms = new Date(iso).getTime();
  } else {
    return '';
  }
  if (Number.isNaN(ms)) return '';
  const diff = Date.now() - ms;
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'Just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

function RatioBar({ label, value, icon }: { label: string; value: number; icon: string }) {
  const v = Math.max(0, Math.min(100, value));
  return (
    <View style={styles.gridCell}>
      <Icon name={icon} size={20} color={PRIMARY} />
      <Text style={styles.gridLabel}>{label}</Text>
      <View style={styles.barTrack}>
        <View style={[styles.barFill, { width: `${v}%`, backgroundColor: PRIMARY }]} />
      </View>
      <Text style={styles.gridValue}>{Math.round(v)}%</Text>
    </View>
  );
}

export default function PeepDetailScreen({ route, navigation }: Props) {
  const { peepId } = route.params;
  const [peep, setPeep] = useState<PeepPayload | null>(null);
  const [loading, setLoading] = useState(true);
  const [comments, setComments] = useState<CommentRow[]>([]);
  const [commentText, setCommentText] = useState('');
  const [posting, setPosting] = useState(false);
  const [liked, setLiked] = useState(false);

  const loadPeep = useCallback(async () => {
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/peeps/${peepId}`, {
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) {
        setPeep(null);
        return;
      }
      const data = (await res.json()) as PeepPayload;
      setPeep(data);
      setLiked(!!data.likedByMe);
    } catch {
      setPeep(null);
    } finally {
      setLoading(false);
    }
  }, [peepId]);

  const loadComments = useCallback(async () => {
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/peeps/${peepId}/comments`, {
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) return;
      const data = await res.json();
      const list = (data.comments || []) as CommentRow[];
      setComments(list);
    } catch {
      setComments([]);
    }
  }, [peepId]);

  useEffect(() => {
    loadPeep();
    loadComments();
  }, [loadPeep, loadComments]);

  const toggleLike = async () => {
    const next = !liked;
    setLiked(next);
    try {
      const token = await authService.getIdToken();
      await fetch(`${BASE_URL}/peeps/${peepId}/like`, {
        method: next ? 'POST' : 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      await loadPeep();
    } catch {
      setLiked(!next);
    }
  };

  const postComment = async () => {
    const t = commentText.trim();
    if (!t) return;
    setPosting(true);
    try {
      const token = await authService.getIdToken();
      await fetch(`${BASE_URL}/peeps/${peepId}/comments`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ text: t }),
      });
      setCommentText('');
      await loadComments();
    } finally {
      setPosting(false);
    }
  };

  if (loading || !peep) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color={ACCENT} />
      </View>
    );
  }

  const photo = peep.photoUrl || peep.imageUrl;
  const notes = peep.notes || peep.description || '';
  const vibes = peep.vibe || [];
  const crowd = peep.crowdSize ?? 3;

  return (
    <KeyboardAvoidingView
      style={styles.flex}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={88}
    >
      <ScrollView style={styles.flex} contentContainerStyle={styles.scrollContent}>
        <View style={styles.heroWrap}>
          <ImageBackground
            source={{ uri: photo || 'https://via.placeholder.com/800x480' }}
            style={styles.hero}
            imageStyle={styles.heroImg}
          >
            <LinearGradient colors={['transparent', 'rgba(0,0,0,0.88)']} style={styles.heroGrad}>
              <View style={styles.heroBottom}>
                <Text style={styles.venueTitle}>{peep.venue?.name || 'Venue'}</Text>
                <View style={styles.heroRow}>
                  <View style={[styles.crowdPill, { backgroundColor: crowdColor(crowd) }]}>
                    <View style={styles.crowdDotSm} />
                    <Text style={styles.crowdPillText}>{crowd}</Text>
                  </View>
                  <Text style={styles.timeStamp}>
                    {formatAgo(peep.createdAt as string | { seconds?: number } | undefined)}
                  </Text>
                </View>
              </View>
            </LinearGradient>
          </ImageBackground>
        </View>

        <TouchableOpacity
          style={styles.reporter}
          onPress={() => {
            const uid = peep.userId;
            if (uid) navigation.push('UserProfile', { userId: uid });
          }}
        >
          <Image
            source={{
              uri: peep.user?.profileImageUrl || 'https://via.placeholder.com/80',
            }}
            style={styles.avatar}
          />
          <View style={{ flex: 1 }}>
            <Text style={styles.userName}>
              {peep.user?.username || 'User'}{' '}
              {peep.isPioneer ? <Text style={styles.star}>⭐</Text> : null}
            </Text>
          </View>
        </TouchableOpacity>

        <View style={styles.grid}>
          <View style={styles.gridCell}>
            <Icon name="people" size={20} color={PRIMARY} />
            <Text style={styles.gridLabel}>Crowd size</Text>
            <Text style={styles.gridValue}>{crowd} / 5</Text>
          </View>
          <RatioBar label="M / F" value={peep.mfRatio ?? 50} icon="wc" />
          <RatioBar label="A / K" value={peep.akRatio ?? 50} icon="groups" />
          <View style={styles.gridCell}>
            <Icon name="cake" size={20} color={PRIMARY} />
            <Text style={styles.gridLabel}>Age ranges</Text>
            <Text style={styles.gridValue}>{(peep.ageRanges || []).join(', ') || '—'}</Text>
          </View>
        </View>

        {vibes.length > 0 ? (
          <View style={styles.vibeWrap}>
            {vibes.map(v => (
              <View key={v} style={styles.chip}>
                <Text style={styles.chipText}>{v}</Text>
              </View>
            ))}
          </View>
        ) : null}

        {notes ? <Text style={styles.notes}>{notes}</Text> : null}

        <View style={styles.actions}>
          <TouchableOpacity style={styles.actionBtn} onPress={toggleLike}>
            <Icon name={liked ? 'favorite' : 'favorite-border'} size={26} color={liked ? '#E91E63' : PRIMARY} />
            <Text style={styles.actionLabel}>Like</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.actionBtn} onPress={() => {}}>
            <Icon name="chat-bubble-outline" size={26} color={PRIMARY} />
            <Text style={styles.actionLabel}>Comment</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.actionBtn}
            onPress={() => navigation.navigate('Share', { peepId })}
          >
            <Icon name="share" size={26} color={PRIMARY} />
            <Text style={styles.actionLabel}>Share</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.actionBtn}
            onPress={() => navigation.navigate('Report', { peepId })}
          >
            <Icon name="flag" size={26} color={PRIMARY} />
            <Text style={styles.actionLabel}>Report</Text>
          </TouchableOpacity>
        </View>

        {(peep.likerPreview || []).length > 0 ? (
          <TouchableOpacity
            style={styles.likersRow}
            onPress={() => navigation.navigate('Likers', { peepId })}
          >
            {(peep.likerPreview || []).slice(0, 5).map(l => (
              <Image
                key={l.userId}
                source={{ uri: l.profileImageUrl || 'https://via.placeholder.com/40' }}
                style={styles.likerAv}
              />
            ))}
          </TouchableOpacity>
        ) : null}

        <Text style={styles.sectionTitle}>Comments</Text>
        {comments.map(item => (
          <View key={item.id} style={styles.commentRow}>
            <Image
              source={{ uri: 'https://via.placeholder.com/40' }}
              style={styles.cAvatar}
            />
            <View style={{ flex: 1 }}>
              <Text style={styles.cUser}>{item.username || 'User'}</Text>
              <Text style={styles.cText}>{item.text}</Text>
              <Text style={styles.cTime}>
                {formatAgo(item.createdAt as string | { seconds?: number } | undefined)}
              </Text>
            </View>
          </View>
        ))}
      </ScrollView>

      <View style={styles.inputRow}>
        <TextInput
          style={styles.input}
          placeholder="Write a comment..."
          placeholderTextColor="#999"
          value={commentText}
          onChangeText={setCommentText}
        />
        <TouchableOpacity style={styles.postBtn} onPress={postComment} disabled={posting}>
          <Text style={styles.postBtnText}>Post</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: '#fff' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  scrollContent: { paddingBottom: 24 },
  heroWrap: { width: '100%' },
  hero: { width: '100%', height: 240, justifyContent: 'flex-end' },
  heroImg: {},
  heroGrad: { flex: 1, justifyContent: 'flex-end', padding: 16 },
  heroBottom: {},
  venueTitle: { color: '#fff', fontWeight: 'bold', fontSize: 24 },
  heroRow: { flexDirection: 'row', alignItems: 'center', marginTop: 8 },
  crowdPill: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 16,
  },
  crowdDotSm: { width: 8, height: 8, borderRadius: 4, backgroundColor: '#fff', marginRight: 6 },
  crowdPillText: { color: '#fff', fontWeight: 'bold' },
  timeStamp: { color: '#fff', fontSize: 12, fontStyle: 'italic', marginLeft: 12 },
  reporter: { flexDirection: 'row', alignItems: 'center', padding: 16 },
  avatar: { width: 40, height: 40, borderRadius: 20, marginRight: 12 },
  userName: { fontWeight: 'bold', fontSize: 16 },
  star: { fontSize: 16 },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    paddingHorizontal: 12,
    justifyContent: 'space-between',
  },
  gridCell: {
    width: '48%',
    backgroundColor: '#f5f5f5',
    borderRadius: 10,
    padding: 10,
    marginBottom: 10,
  },
  gridLabel: { fontSize: 12, color: '#555', marginTop: 4 },
  gridValue: { fontSize: 14, fontWeight: '600', color: '#222', marginTop: 4 },
  barTrack: {
    height: 8,
    backgroundColor: '#e0e0e0',
    borderRadius: 4,
    marginTop: 6,
    overflow: 'hidden',
  },
  barFill: { height: 8, borderRadius: 4 },
  vibeWrap: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 16, marginTop: 8 },
  chip: {
    borderWidth: 1,
    borderColor: ACCENT,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 6,
    margin: 4,
  },
  chipText: { color: PRIMARY, fontWeight: '600' },
  notes: { paddingHorizontal: 16, marginTop: 12, fontSize: 15, color: '#333' },
  actions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-around',
    paddingVertical: 16,
  },
  actionBtn: { alignItems: 'center', minWidth: 72 },
  actionLabel: { marginTop: 4, color: PRIMARY, fontWeight: '600' },
  likersRow: { flexDirection: 'row', paddingHorizontal: 16, marginBottom: 8 },
  likerAv: {
    width: 36,
    height: 36,
    borderRadius: 18,
    marginRight: -8,
    borderWidth: 2,
    borderColor: '#fff',
  },
  sectionTitle: { fontWeight: 'bold', fontSize: 16, paddingHorizontal: 16, marginBottom: 8 },
  commentRow: { flexDirection: 'row', paddingHorizontal: 16, paddingVertical: 10 },
  cAvatar: { width: 36, height: 36, borderRadius: 18, marginRight: 10 },
  cUser: { fontWeight: 'bold' },
  cText: { color: '#333', marginTop: 2 },
  cTime: { color: '#888', fontSize: 11, marginTop: 4 },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 10,
    borderTopWidth: 1,
    borderColor: '#eee',
    backgroundColor: '#fafafa',
  },
  input: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginRight: 8,
    color: '#222',
  },
  postBtn: { backgroundColor: PRIMARY, paddingHorizontal: 16, paddingVertical: 10, borderRadius: 8 },
  postBtnText: { color: '#fff', fontWeight: 'bold' },
});
