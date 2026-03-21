import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  ImageBackground,
  ActivityIndicator,
  ScrollView,
  Modal,
  Dimensions,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { DealClaimedDeal } from '../types/Navigation';
import { locationService } from '../services/LocationService';
import { authService } from '../services/AuthService';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';

type DealsNavigation = StackNavigationProp<RootStackParamList, 'Deals'>;

export interface MerchantFeedDeal {
  id: string;
  adId: string;
  merchantName: string;
  offerText: string;
  imageUrl?: string;
  distance?: number;
  category?: string;
  endsAt?: string;
}

interface DealsScreenProps {
  navigation: DealsNavigation;
}

const FILTERS = ['All', 'Food', 'Drinks', 'Services', 'Events'] as const;
type FilterKey = (typeof FILTERS)[number];

function formatCountdown(ms: number): string {
  if (ms <= 0) return '00:00:00';
  const totalSec = Math.floor(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

export default function DealsScreen({ navigation }: DealsScreenProps) {
  const [deals, setDeals] = useState<MerchantFeedDeal[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<FilterKey>('All');
  const [now, setNow] = useState(Date.now());
  const [confirmDeal, setConfirmDeal] = useState<MerchantFeedDeal | null>(null);

  const loadDeals = useCallback(async () => {
    setLoading(true);
    try {
      const loc = await locationService.getCurrentLocation();
      if (!loc) {
        setDeals([]);
        return;
      }
      const token = await authService.getIdToken();
      const url = `${BASE_URL}/merchant/feed?lat=${loc.latitude}&lng=${loc.longitude}`;
      const res = await fetch(url, {
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      });
      if (!res.ok) {
        setDeals([]);
        return;
      }
      const data = await res.json();
      const list: MerchantFeedDeal[] = Array.isArray(data)
        ? data
        : data.deals || data.items || [];
      setDeals(list);
    } catch {
      setDeals([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadDeals();
  }, [loadDeals]);

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  const filteredDeals = useMemo(() => {
    if (filter === 'All') return deals;
    return deals.filter(d => {
      const c = (d.category || '').toLowerCase();
      return c.includes(filter.toLowerCase());
    });
  }, [deals, filter]);

  const openClaimFlow = (deal: MerchantFeedDeal) => {
    setConfirmDeal(deal);
  };

  const confirmClaim = () => {
    if (!confirmDeal) return;
    const d = confirmDeal;
    setConfirmDeal(null);
    const payload: DealClaimedDeal = {
      merchantName: d.merchantName,
      offerText: d.offerText,
      expiresAt: d.endsAt || new Date(Date.now() + 3600000).toISOString(),
      venueImageUrl: d.imageUrl || 'https://via.placeholder.com/800x400',
      adId: d.adId || d.id,
    };
    navigation.navigate('DealClaimed', { deal: payload });
  };

  const renderDeal = ({ item }: { item: MerchantFeedDeal }) => {
    const end = item.endsAt ? new Date(item.endsAt).getTime() : now + 3600000;
    const remaining = end - now;
    const countdown = formatCountdown(remaining);

    return (
      <TouchableOpacity
        style={styles.cardWrap}
        activeOpacity={0.9}
        onPress={() => {}}
      >
        <ImageBackground
          source={{ uri: item.imageUrl || 'https://via.placeholder.com/800x400' }}
          style={styles.cardBg}
          imageStyle={styles.cardImage}
        >
          <Text style={styles.timerTop}>Ends in {countdown}</Text>
          <LinearGradient
            colors={['transparent', 'rgba(0,0,0,0.85)']}
            style={styles.scrim}
          >
            <View style={styles.cardBottom}>
              <View style={styles.cardTextCol}>
                <Text style={styles.merchantName}>{item.merchantName}</Text>
                <Text style={styles.offerText}>{item.offerText}</Text>
                <Text style={styles.distance}>
                  {item.distance != null ? `${item.distance.toFixed(1)} mi away` : 'Nearby'}
                </Text>
              </View>
              <TouchableOpacity
                style={styles.claimBtn}
                onPress={() => openClaimFlow(item)}
                activeOpacity={0.85}
              >
                <Text style={styles.claimBtnText}>Claim</Text>
              </TouchableOpacity>
            </View>
          </LinearGradient>
        </ImageBackground>
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerRow}>
        <Text style={styles.headerTitle}>Deals</Text>
        <TouchableOpacity onPress={() => navigation.navigate('MerchantSignIn')}>
          <Text style={styles.advertise}>Advertise</Text>
        </TouchableOpacity>
      </View>

      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.chipsRow}
      >
        {FILTERS.map(f => (
          <TouchableOpacity
            key={f}
            style={[styles.chip, filter === f ? styles.chipActive : styles.chipInactive]}
            onPress={() => setFilter(f)}
          >
            <Text style={[styles.chipText, filter === f ? styles.chipTextActive : styles.chipTextInactive]}>
              {f}
            </Text>
          </TouchableOpacity>
        ))}
      </ScrollView>

      {loading ? (
        <View style={styles.centered}>
          <ActivityIndicator size="large" color="#FFC107" />
        </View>
      ) : filteredDeals.length === 0 ? (
        <View style={styles.centered}>
          <Text style={styles.empty}>No deals near you right now</Text>
        </View>
      ) : (
        <FlatList
          data={filteredDeals}
          keyExtractor={item => item.id || item.adId}
          renderItem={renderDeal}
          contentContainerStyle={styles.listPad}
        />
      )}

      <Modal visible={!!confirmDeal} transparent animationType="fade">
        <View style={styles.modalBackdrop}>
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>Claim this deal?</Text>
            <Text style={styles.modalBody}>{confirmDeal?.offerText}</Text>
            <View style={styles.modalActions}>
              <TouchableOpacity style={styles.modalCancel} onPress={() => setConfirmDeal(null)}>
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.modalOk} onPress={confirmClaim}>
                <Text style={styles.modalOkText}>Confirm</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const { width: W } = Dimensions.get('window');

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1565C0',
    paddingTop: 12,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    marginBottom: 12,
  },
  headerTitle: {
    color: '#FFFFFF',
    fontSize: 28,
    fontWeight: 'bold',
  },
  advertise: {
    color: '#FFC107',
    fontSize: 16,
    fontWeight: '600',
  },
  chipsRow: {
    paddingHorizontal: 12,
    paddingBottom: 12,
    flexDirection: 'row',
    alignItems: 'center',
  },
  chip: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
    marginRight: 8,
  },
  chipActive: {
    backgroundColor: '#FFC107',
  },
  chipInactive: {
    backgroundColor: '#B0BEC5',
  },
  chipText: {
    fontSize: 14,
    fontWeight: '600',
  },
  chipTextActive: {
    color: '#000000',
  },
  chipTextInactive: {
    color: '#37474F',
  },
  listPad: {
    paddingHorizontal: 12,
    paddingBottom: 24,
  },
  cardWrap: {
    width: W - 24,
    alignSelf: 'center',
    marginBottom: 16,
    borderRadius: 12,
    overflow: 'hidden',
  },
  cardBg: {
    height: 200,
    width: '100%',
    justifyContent: 'flex-end',
    position: 'relative',
  },
  cardImage: {
    borderRadius: 12,
  },
  scrim: {
    flex: 1,
    justifyContent: 'flex-end',
    padding: 12,
  },
  timerTop: {
    position: 'absolute',
    top: 10,
    right: 10,
    zIndex: 2,
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
    backgroundColor: 'rgba(0,0,0,0.35)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
  },
  cardBottom: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
  },
  cardTextCol: {
    flex: 1,
    marginRight: 8,
  },
  merchantName: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
  },
  offerText: {
    color: '#FFFFFF',
    fontSize: 14,
    marginTop: 4,
  },
  distance: {
    color: '#FFFFFF',
    fontSize: 12,
    marginTop: 4,
  },
  claimBtn: {
    backgroundColor: '#FFC107',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
  },
  claimBtnText: {
    color: '#000000',
    fontWeight: 'bold',
    fontSize: 14,
  },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  empty: {
    color: '#FFFFFF',
    fontSize: 16,
    textAlign: 'center',
  },
  modalBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    padding: 24,
  },
  modalCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 20,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1565C0',
    marginBottom: 8,
  },
  modalBody: {
    fontSize: 15,
    color: '#333',
    marginBottom: 16,
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
  },
  modalCancel: {
    paddingVertical: 10,
    paddingHorizontal: 16,
    marginRight: 12,
  },
  modalCancelText: {
    color: '#666',
    fontSize: 16,
  },
  modalOk: {
    backgroundColor: '#1565C0',
    paddingVertical: 10,
    paddingHorizontal: 20,
    borderRadius: 8,
  },
  modalOkText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    fontSize: 16,
  },
});
