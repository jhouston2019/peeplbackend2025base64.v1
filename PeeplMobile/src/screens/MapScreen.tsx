import React, { useEffect, useRef, useState, useCallback, useMemo } from 'react';
import {
  View,
  StyleSheet,
  TouchableOpacity,
  Text,
  Alert,
  Dimensions,
  Animated,
  Image,
} from 'react-native';
import MapView, { Marker, Region, Circle, Callout, PROVIDER_GOOGLE } from 'react-native-maps';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { locationService } from '../services/LocationService';
import { Venue } from '../types/Venue';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';
const { width, height } = Dimensions.get('window');

type MapNav = StackNavigationProp<RootStackParamList, 'Map'>;

interface MapScreenProps {
  navigation: MapNav;
}

type VenueWithCrowd = Venue & { crowdSize?: number };

interface MerchantAd {
  id: string;
  adId?: string;
  venueId?: string;
  merchantName?: string;
  offerText: string;
  latitude?: number;
  longitude?: number;
  imageUrl?: string;
}

type FilterMode = 'all' | 'deals' | 'near';

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function heatColor(crowd: number): string {
  if (crowd <= 2) return 'rgba(76,175,80,0.3)';
  if (crowd === 3) return 'rgba(255,167,38,0.3)';
  return 'rgba(244,67,54,0.3)';
}

function pinColor(crowd: number): string {
  if (crowd <= 2) return '#4CAF50';
  if (crowd === 3) return '#FFA726';
  return '#F44336';
}

export default function MapScreen({ navigation }: MapScreenProps) {
  const [region, setRegion] = useState<Region>({
    latitude: 37.78825,
    longitude: -122.4324,
    latitudeDelta: 0.05,
    longitudeDelta: 0.05,
  });
  const [venues, setVenues] = useState<VenueWithCrowd[]>([]);
  const [ads, setAds] = useState<MerchantAd[]>([]);
  const [userLocation, setUserLocation] = useState<{ latitude: number; longitude: number } | null>(
    null
  );
  const [filter, setFilter] = useState<FilterMode>('all');
  const [loading, setLoading] = useState(true);
  const mapRef = useRef<MapView>(null);
  const pulse = useRef(new Animated.Value(0.2)).current;

  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 0.6, duration: 1000, useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 0.2, duration: 1000, useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [pulse]);

  const loadData = useCallback(async (lat: number, lng: number) => {
    try {
      const token = await authService.getIdToken();
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
      };
      if (token) headers.Authorization = `Bearer ${token}`;

      const [vRes, aRes] = await Promise.all([
        fetch(`${BASE_URL}/search/venues/nearby?lat=${lat}&lng=${lng}&radius=5000`, { headers }),
        fetch(`${BASE_URL}/merchant/feed?lat=${lat}&lng=${lng}`, { headers }),
      ]);

      let vList: VenueWithCrowd[] = [];
      if (vRes.ok) {
        const vJson = await vRes.json();
        const raw = Array.isArray(vJson) ? vJson : vJson.venues || [];
        vList = raw.map((item: Record<string, unknown>) => ({
          ...item,
          id: String(item.id),
          name: String(item.name ?? ''),
          address: String(item.address ?? ''),
          latitude: Number(item.latitude),
          longitude: Number(item.longitude),
          category: String(item.category ?? ''),
          createdBy: String(item.createdBy ?? ''),
          createdAt: String(item.createdAt ?? ''),
          updatedAt: String(item.updatedAt ?? ''),
          isActive: true,
          peepCount: Number(item.peepCount ?? 0),
          averageRating: Number(item.averageRating ?? 0),
          totalRatings: Number(item.totalRatings ?? 0),
          crowdSize: Number(item.crowdSize ?? item.latestCrowdSize ?? 3),
        })) as VenueWithCrowd[];
      }

      let adList: MerchantAd[] = [];
      if (aRes.ok) {
        const aJson = await aRes.json();
        const raw = Array.isArray(aJson) ? aJson : aJson.deals || aJson.items || [];
        adList = raw.map((a: Record<string, unknown>) => ({
          id: String(a.id ?? a.adId),
          adId: a.adId ? String(a.adId) : String(a.id),
          venueId: a.venueId ? String(a.venueId) : undefined,
          merchantName: a.merchantName ? String(a.merchantName) : '',
          offerText: String(a.offerText ?? ''),
          latitude: a.latitude != null ? Number(a.latitude) : undefined,
          longitude: a.longitude != null ? Number(a.longitude) : undefined,
          imageUrl: a.imageUrl ? String(a.imageUrl) : undefined,
        }));
      }

      setVenues(vList);
      setAds(adList);
    } catch (e) {
      console.error(e);
    }
  }, []);

  const initializeMap = async () => {
    try {
      const location = await locationService.getCurrentLocation();
      if (location) {
        setUserLocation(location);
        const newRegion = {
          latitude: location.latitude,
          longitude: location.longitude,
          latitudeDelta: 0.02,
          longitudeDelta: 0.02,
        };
        setRegion(newRegion);
        await loadData(location.latitude, location.longitude);
      }
    } catch (error) {
      console.error('Map initialization error:', error);
      Alert.alert('Error', 'Unable to get your location.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    initializeMap();
    return () => {
      locationService.stopLocationTracking();
    };
  }, []);

  const filteredVenues = useMemo(() => {
    if (!userLocation) return venues;
    if (filter === 'near') {
      return venues.filter(
        v =>
          haversineKm(userLocation.latitude, userLocation.longitude, v.latitude, v.longitude) <= 2
      );
    }
    if (filter === 'deals') {
      const ids = new Set(
        ads.map(a => a.venueId).filter(Boolean) as string[]
      );
      return venues.filter(v => ids.has(v.id));
    }
    return venues;
  }, [venues, ads, filter, userLocation]);

  const dealMarkers = useMemo(() => {
    if (filter === 'near' && userLocation) {
      return ads.filter(
        a =>
          a.latitude != null &&
          a.longitude != null &&
          haversineKm(userLocation.latitude, userLocation.longitude, a.latitude, a.longitude) <= 2
      );
    }
    if (filter === 'deals' || filter === 'all') {
      return ads;
    }
    return [];
  }, [ads, filter, userLocation]);

  const showCrowdPins = filter !== 'deals';

  const centerOnUserLocation = async () => {
    try {
      const location = await locationService.getCurrentLocation();
      if (location && mapRef.current) {
        mapRef.current.animateToRegion(
          {
            latitude: location.latitude,
            longitude: location.longitude,
            latitudeDelta: 0.02,
            longitudeDelta: 0.02,
          },
          1000
        );
        setUserLocation(location);
      }
    } catch (error) {
      console.error(error);
    }
  };

  const handleCreatePeep = () => {
    if (userLocation) {
      navigation.navigate('CreatePeep', {
        location: userLocation,
        venues: venues,
      });
    } else {
      Alert.alert('Location Required', 'Please enable location services to create a peep.');
    }
  };

  const openVenue = (venue: Venue) => {
    navigation.navigate('Venue', { venue });
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <Text style={styles.loadingText}>Loading map...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <MapView
        ref={mapRef}
        style={styles.map}
        provider={PROVIDER_GOOGLE}
        region={region}
        onRegionChangeComplete={setRegion}
        showsUserLocation
        showsMyLocationButton={false}
      >
        {userLocation && (
          <Marker coordinate={userLocation} anchor={{ x: 0.5, y: 0.5 }} tracksViewChanges={false}>
            <Animated.View style={[styles.pulseRing, { opacity: pulse }]} />
          </Marker>
        )}

        {showCrowdPins &&
          filteredVenues.map(v => {
            const c = v.crowdSize ?? 3;
            return (
              <React.Fragment key={`crowd-${v.id}`}>
                <Circle
                  center={{ latitude: v.latitude, longitude: v.longitude }}
                  radius={100}
                  fill={heatColor(c)}
                  strokeWidth={0}
                />
                <Marker
                  coordinate={{ latitude: v.latitude, longitude: v.longitude }}
                  anchor={{ x: 0.5, y: 1 }}
                  tracksViewChanges={false}
                  onPress={() => {}}
                >
                  <View style={styles.pinColumn}>
                    <View style={[styles.crowdPin, { backgroundColor: pinColor(c) }]} />
                    <Text style={styles.pinLabel} numberOfLines={1}>
                      {v.name}
                    </Text>
                  </View>
                  <Callout onPress={() => openVenue(v)}>
                    <View style={styles.calloutBox}>
                      <Text style={styles.calloutTitle}>{v.name}</Text>
                      <Text style={styles.calloutSub}>Crowd: {c}</Text>
                      <Text style={styles.calloutLink}>View →</Text>
                    </View>
                  </Callout>
                </Marker>
              </React.Fragment>
            );
          })}

        {(filter === 'all' || filter === 'deals' || filter === 'near') &&
          dealMarkers.map(ad => {
            if (ad.latitude == null || ad.longitude == null) return null;
            return (
              <Marker
                key={`deal-${ad.id}`}
                coordinate={{ latitude: ad.latitude, longitude: ad.longitude }}
                tracksViewChanges={false}
              >
                <View style={styles.dealPin}>
                  <Text style={styles.dealStar}>⭐</Text>
                </View>
                <Callout>
                  <View style={styles.calloutBox}>
                    <Text style={styles.calloutTitle}>{ad.merchantName || 'Deal'}</Text>
                    <Text style={styles.calloutSub}>{ad.offerText}</Text>
                    <TouchableOpacity
                      onPress={() => navigation.navigate('Deals')}
                      style={styles.claimMini}
                    >
                      <Text style={styles.claimMiniText}>Claim</Text>
                    </TouchableOpacity>
                  </View>
                </Callout>
              </Marker>
            );
          })}
      </MapView>

      <View style={styles.filterRow}>
        {(['all', 'deals', 'near'] as FilterMode[]).map(key => (
          <TouchableOpacity
            key={key}
            style={[styles.filterChip, filter === key && styles.filterChipActive]}
            onPress={() => setFilter(key)}
          >
            <Text style={[styles.filterText, filter === key && styles.filterTextActive]}>
              {key === 'all' ? 'All' : key === 'deals' ? 'Deals' : 'Near me'}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <View style={styles.legend}>
        <View style={styles.legendRow}>
          <View style={[styles.legendDot, { backgroundColor: '#4CAF50' }]} />
          <Text style={styles.legendText}>Quiet</Text>
        </View>
        <View style={styles.legendRow}>
          <View style={[styles.legendDot, { backgroundColor: '#FFA726' }]} />
          <Text style={styles.legendText}>Moderate</Text>
        </View>
        <View style={styles.legendRow}>
          <View style={[styles.legendDot, { backgroundColor: '#F44336' }]} />
          <Text style={styles.legendText}>Busy</Text>
        </View>
      </View>

      <View style={styles.fabContainer}>
        <TouchableOpacity style={styles.fab} onPress={centerOnUserLocation}>
          <Icon name="my-location" size={24} color="#1565C0" />
        </TouchableOpacity>
        <TouchableOpacity style={[styles.fab, styles.createPeepFab]} onPress={handleCreatePeep}>
          <Icon name="add" size={24} color="#ffffff" />
        </TouchableOpacity>
      </View>

      <TouchableOpacity style={styles.venueListButton} onPress={() => navigation.navigate('Venues')}>
        <Icon name="list" size={20} color="#1565C0" />
        <Text style={styles.venueListButtonText}>Venues</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  map: {
    width,
    height,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1565C0',
  },
  loadingText: {
    color: '#FFFFFF',
    fontSize: 16,
  },
  pulseRing: {
    width: 72,
    height: 72,
    borderRadius: 36,
    borderWidth: 3,
    borderColor: '#1565C0',
    backgroundColor: 'transparent',
  },
  pinColumn: {
    alignItems: 'center',
  },
  crowdPin: {
    width: 18,
    height: 18,
    borderRadius: 9,
    borderWidth: 2,
    borderColor: '#FFFFFF',
  },
  pinLabel: {
    marginTop: 2,
    maxWidth: 100,
    fontSize: 10,
    color: '#000000',
    fontWeight: '600',
    backgroundColor: 'rgba(255,255,255,0.85)',
    paddingHorizontal: 4,
    borderRadius: 4,
  },
  dealPin: {
    backgroundColor: '#FFC107',
    borderRadius: 16,
    padding: 4,
    borderWidth: 1,
    borderColor: '#FFFFFF',
  },
  dealStar: {
    fontSize: 18,
  },
  calloutBox: {
    width: 180,
    padding: 8,
  },
  calloutTitle: {
    fontWeight: 'bold',
    fontSize: 14,
    marginBottom: 4,
  },
  calloutSub: {
    fontSize: 12,
    color: '#444',
    marginBottom: 6,
  },
  calloutLink: {
    color: '#1565C0',
    fontWeight: '600',
    fontSize: 13,
  },
  claimMini: {
    alignSelf: 'flex-start',
    backgroundColor: '#FFC107',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 6,
  },
  claimMiniText: {
    fontWeight: 'bold',
    fontSize: 12,
    color: '#000',
  },
  filterRow: {
    position: 'absolute',
    top: 48,
    left: 12,
    right: 12,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
  },
  filterChip: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.9)',
    marginHorizontal: 6,
  },
  filterChipActive: {
    backgroundColor: '#FFC107',
  },
  filterText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#1565C0',
  },
  filterTextActive: {
    color: '#000000',
  },
  legend: {
    position: 'absolute',
    bottom: 120,
    left: 12,
    backgroundColor: 'rgba(255,255,255,0.95)',
    padding: 10,
    borderRadius: 10,
    elevation: 3,
  },
  legendRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 2,
  },
  legendDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: 8,
  },
  legendText: {
    fontSize: 12,
    color: '#333',
  },
  fabContainer: {
    position: 'absolute',
    right: 20,
    bottom: 100,
    alignItems: 'center',
  },
  fab: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#ffffff',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
  },
  createPeepFab: {
    backgroundColor: '#1565C0',
  },
  venueListButton: {
    position: 'absolute',
    left: 20,
    bottom: 100,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#ffffff',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 25,
    elevation: 4,
  },
  venueListButtonText: {
    marginLeft: 8,
    fontSize: 16,
    fontWeight: '600',
    color: '#1565C0',
  },
});
