import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  FlatList,
  ImageBackground,
  ActivityIndicator,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { Venue } from '../types/Venue';
import { locationService } from '../services/LocationService';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';

type Nav = StackNavigationProp<RootStackParamList, 'GetPeeps'>;

interface GetPeepsScreenProps {
  navigation: Nav;
}

const TABS = ['Near Me', 'New City', 'Specific Venue'] as const;

function toVenue(item: Record<string, unknown>): Venue {
  return {
    id: String(item.id ?? ''),
    name: String(item.name ?? 'Venue'),
    address: String(item.address ?? ''),
    latitude: Number(item.latitude ?? 0),
    longitude: Number(item.longitude ?? 0),
    category: String(item.category ?? ''),
    description: item.description ? String(item.description) : undefined,
    imageUrl: item.imageUrl ? String(item.imageUrl) : undefined,
    createdBy: String(item.createdBy ?? 'system'),
    createdAt: String(item.createdAt ?? new Date().toISOString()),
    updatedAt: String(item.updatedAt ?? new Date().toISOString()),
    isActive: item.isActive !== false,
    peepCount: Number(item.peepCount ?? 0),
    averageRating: Number(item.averageRating ?? 0),
    totalRatings: Number(item.totalRatings ?? 0),
    distance: item.distance != null ? Number(item.distance) : undefined,
    ...(item.crowdSize != null ? { crowdSize: Number(item.crowdSize) } : {}),
  } as Venue & { crowdSize?: number };
}

async function authGet(path: string): Promise<unknown> {
  const token = await authService.getIdToken();
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });
  if (!res.ok) throw new Error('Request failed');
  return res.json();
}

export default function GetPeepsScreen({ navigation }: GetPeepsScreenProps) {
  const [tab, setTab] = useState(0);
  const [loading, setLoading] = useState(false);
  const [nearResults, setNearResults] = useState<Venue[]>([]);
  const [cityQuery, setCityQuery] = useState('');
  const [cityResults, setCityResults] = useState<Venue[]>([]);
  const [venueQuery, setVenueQuery] = useState('');
  const [venueResults, setVenueResults] = useState<Venue[]>([]);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const loadNearMe = useCallback(async () => {
    setLoading(true);
    try {
      const loc = await locationService.getCurrentLocation();
      if (!loc) {
        setNearResults([]);
        return;
      }
      const data = (await authGet(
        `/search/venues/nearby?lat=${loc.latitude}&lng=${loc.longitude}&radius=5000`
      )) as { venues?: unknown[] } | unknown[];
      const raw = Array.isArray(data) ? data : data.venues || [];
      setNearResults(raw.map((v: unknown) => toVenue(v as Record<string, unknown>)));
    } catch {
      setNearResults([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (tab === 0) {
      loadNearMe();
    }
  }, [tab, loadNearMe]);

  const searchCity = async () => {
    if (!cityQuery.trim()) return;
    setLoading(true);
    try {
      const data = (await authGet(
        `/search/venues/city?city=${encodeURIComponent(cityQuery.trim())}`
      )) as { venues?: unknown[] } | unknown[];
      const raw = Array.isArray(data) ? data : data.venues || [];
      setCityResults(raw.map((v: unknown) => toVenue(v as Record<string, unknown>)));
    } catch {
      setCityResults([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (tab !== 2) return;
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (!venueQuery.trim()) {
      setVenueResults([]);
      return;
    }
    debounceRef.current = setTimeout(async () => {
      setLoading(true);
      try {
        const data = (await authGet(
          `/search/venues?q=${encodeURIComponent(venueQuery.trim())}`
        )) as { venues?: unknown[] } | unknown[];
        const raw = Array.isArray(data) ? data : data.venues || [];
        setVenueResults(raw.map((v: unknown) => toVenue(v as Record<string, unknown>)));
      } catch {
        setVenueResults([]);
      } finally {
        setLoading(false);
      }
    }, 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [venueQuery, tab]);

  const crowdColor = (size: number) => {
    if (size <= 2) return '#4CAF50';
    if (size === 3) return '#FFA726';
    return '#F44336';
  };

  const renderPhotoCard = ({ item }: { item: Venue & { crowdSize?: number } }) => {
    const crowdSize = item.crowdSize ?? 3;
    return (
      <TouchableOpacity
        style={styles.photoCard}
        onPress={() => navigation.navigate('Venue', { venue: item })}
        activeOpacity={0.9}
      >
        <ImageBackground
          source={{ uri: item.imageUrl || 'https://via.placeholder.com/600x360' }}
          style={styles.photoBg}
          imageStyle={styles.photoImg}
        >
          <LinearGradient colors={['transparent', 'rgba(0,0,0,0.85)']} style={styles.photoGrad}>
            <Text style={styles.photoVenueName}>{item.name}</Text>
            <View style={styles.pillRow}>
              <View style={[styles.crowdDot, { backgroundColor: crowdColor(crowdSize) }]} />
              <Text style={styles.crowdNum}>{crowdSize}</Text>
            </View>
          </LinearGradient>
        </ImageBackground>
      </TouchableOpacity>
    );
  };

  const renderListRow = ({ item }: { item: Venue }) => (
    <TouchableOpacity
      style={styles.listRow}
      onPress={() => navigation.navigate('Venue', { venue: item })}
    >
      <View style={styles.listTextCol}>
        <Text style={styles.listName}>{item.name}</Text>
        <Text style={styles.listMeta}>
          {item.category}
          {item.distance != null ? ` · ${item.distance.toFixed(1)} mi` : ''}
        </Text>
      </View>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      <View style={styles.segment}>
        {TABS.map((label, i) => (
          <TouchableOpacity
            key={label}
            style={[styles.segBtn, tab === i && styles.segBtnActive]}
            onPress={() => setTab(i)}
          >
            <Text style={[styles.segText, tab === i && styles.segTextActive]}>{label}</Text>
          </TouchableOpacity>
        ))}
      </View>

      {tab === 0 && (
        <>
          {loading ? (
            <View style={styles.center}>
              <ActivityIndicator size="large" color="#FFC107" />
            </View>
          ) : nearResults.length === 0 ? (
            <Text style={styles.empty}>No venues found nearby</Text>
          ) : (
            <FlatList
              data={nearResults}
              keyExtractor={v => v.id}
              renderItem={renderPhotoCard}
              contentContainerStyle={styles.listPad}
            />
          )}
        </>
      )}

      {tab === 1 && (
        <FlatList
          data={cityResults}
          keyExtractor={v => v.id}
          renderItem={renderPhotoCard}
          contentContainerStyle={styles.cityPad}
          ListHeaderComponent={
            <View>
              <TextInput
                style={styles.input}
                placeholder="Enter a city"
                placeholderTextColor="#90A4AE"
                value={cityQuery}
                onChangeText={setCityQuery}
              />
              <TouchableOpacity style={styles.searchBtn} onPress={searchCity}>
                <Text style={styles.searchBtnText}>Search</Text>
              </TouchableOpacity>
              {loading ? (
                <ActivityIndicator size="large" color="#FFC107" style={{ marginVertical: 24 }} />
              ) : cityResults.length === 0 ? (
                <Text style={styles.empty}>Enter a city and tap Search</Text>
              ) : null}
            </View>
          }
        />
      )}

      {tab === 2 && (
        <View style={styles.flex1}>
          <TextInput
            style={styles.input}
            placeholder="Search venues..."
            placeholderTextColor="#90A4AE"
            value={venueQuery}
            onChangeText={setVenueQuery}
            autoCapitalize="none"
          />
          {loading ? (
            <View style={styles.center}>
              <ActivityIndicator size="large" color="#FFC107" />
            </View>
          ) : venueResults.length === 0 ? (
            <Text style={styles.empty}>Type to search venues</Text>
          ) : (
            <FlatList
              data={venueResults}
              keyExtractor={v => v.id}
              renderItem={renderListRow}
            />
          )}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1565C0',
    paddingTop: 8,
  },
  flex1: {
    flex: 1,
    paddingHorizontal: 16,
  },
  segment: {
    flexDirection: 'row',
    marginHorizontal: 12,
    marginBottom: 12,
    backgroundColor: 'rgba(255,255,255,0.15)',
    borderRadius: 8,
    padding: 4,
  },
  segBtn: {
    flex: 1,
    paddingVertical: 10,
    alignItems: 'center',
    borderRadius: 6,
  },
  segBtnActive: {
    backgroundColor: '#FFC107',
  },
  segText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontWeight: '600',
  },
  segTextActive: {
    color: '#000000',
  },
  listPad: {
    paddingHorizontal: 12,
    paddingBottom: 24,
  },
  photoCard: {
    height: 180,
    marginBottom: 12,
    borderRadius: 12,
    overflow: 'hidden',
  },
  photoBg: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  photoImg: {
    borderRadius: 12,
  },
  photoGrad: {
    padding: 14,
  },
  photoVenueName: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  pillRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  crowdDot: {
    width: 14,
    height: 14,
    borderRadius: 7,
    marginRight: 8,
  },
  crowdNum: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  cityPad: {
    padding: 16,
  },
  input: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 16,
    color: '#212121',
    marginBottom: 12,
  },
  searchBtn: {
    backgroundColor: '#FFC107',
    borderRadius: 12,
    paddingVertical: 12,
    alignItems: 'center',
    marginBottom: 16,
  },
  searchBtnText: {
    color: '#000000',
    fontWeight: 'bold',
    fontSize: 16,
  },
  listRow: {
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.2)',
  },
  listTextCol: {
    flex: 1,
  },
  listName: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
  },
  listMeta: {
    color: '#E3F2FD',
    fontSize: 14,
    marginTop: 4,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  empty: {
    color: '#FFFFFF',
    textAlign: 'center',
    marginTop: 24,
    paddingHorizontal: 24,
    fontSize: 15,
  },
});
