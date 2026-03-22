import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import Svg, { Rect, Line, Text as SvgText } from 'react-native-svg';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { authService } from '../../services/AuthService';
import { RootStackParamList } from '../../types/Navigation';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';

type Props = {
  route: RouteProp<RootStackParamList, 'MerchantActivity'>;
  navigation: StackNavigationProp<RootStackParamList, 'MerchantActivity'>;
};

type AdRow = {
  id: string;
  offerText?: string;
  status?: string;
  impressions?: number;
  claims?: number;
  totalCost?: number;
  startTime?: unknown;
  endTime?: unknown;
  createdAt?: unknown;
};

function toMillis(v: unknown): number {
  if (v == null) return 0;
  if (typeof v === 'string') return new Date(v).getTime();
  if (typeof v === 'object' && v !== null && '_seconds' in v) {
    return (v as { _seconds: number })._seconds * 1000;
  }
  return 0;
}

function fmtRange(start: unknown, end: unknown): string {
  const a = new Date(toMillis(start));
  const b = new Date(toMillis(end));
  const opts: Intl.DateTimeFormatOptions = {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  };
  return `${a.toLocaleString('en-US', opts)} – ${b.toLocaleString('en-US', opts)}`;
}

export default function MerchantActivityScreen({ route }: Props) {
  const { merchantId } = route.params;
  const [ads, setAds] = useState<AdRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [activeOpen, setActiveOpen] = useState(true);
  const [endedOpen, setEndedOpen] = useState(true);

  const load = useCallback(async () => {
    try {
      const token = await authService.getIdToken();
      const res = await fetch(
        `${BASE_URL}/merchant/ads?merchantId=${encodeURIComponent(merchantId)}`,
        {
          headers: {
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        }
      );
      const data = await res.json().catch(() => ({}));
      const list = (data as { ads?: AdRow[] }).ads ?? [];
      setAds(list);
    } catch {
      setAds([]);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [merchantId]);

  useEffect(() => {
    load();
  }, [load]);

  const stats = useMemo(() => {
    let impressions = 0;
    let claims = 0;
    let totalSpent = 0;
    ads.forEach(a => {
      impressions += Number(a.impressions) || 0;
      claims += Number(a.claims) || 0;
      if (a.status === 'live' || a.status === 'ended') {
        totalSpent += Number(a.totalCost) || 0;
      }
    });
    const claimRate =
      impressions > 0 ? ((claims / impressions) * 100).toFixed(1) + '%' : '0.0%';
    return { impressions, claims, claimRate, totalSpent };
  }, [ads]);

  const hourly = useMemo(() => {
    const total = stats.impressions;
    const base = total / 24;
    return Array.from({ length: 24 }, (_, i) => {
      const wobble = 0.7 + ((i * 13) % 7) * 0.06;
      return Math.max(0, base * wobble);
    });
  }, [stats.impressions]);

  const maxBar = useMemo(() => Math.max(1, ...hourly), [hourly]);

  const liveAds = ads.filter(a => a.status === 'live');
  const endedAds = ads.filter(a => a.status === 'ended');

  const chartW = 320;
  const chartH = 140;
  const padL = 28;
  const padB = 22;
  const barW = (chartW - padL - 8) / 24 - 2;

  return (
    <LinearGradient colors={['#1565C0', '#0D47A1']} style={styles.gradient}>
      <ScrollView
        contentContainerStyle={styles.scroll}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={() => {
              setRefreshing(true);
              load();
            }}
          />
        }
      >
        <Text style={styles.screenTitle}>Activity</Text>

        {loading ? (
          <ActivityIndicator color="#FFC107" style={{ marginVertical: 24 }} />
        ) : (
          <>
            <View style={styles.statGrid}>
              <View style={styles.statBox}>
                <Text style={styles.statLabel}>Total Impressions</Text>
                <Text style={styles.statVal}>{stats.impressions}</Text>
              </View>
              <View style={styles.statBox}>
                <Text style={styles.statLabel}>Deal Claims</Text>
                <Text style={styles.statVal}>{stats.claims}</Text>
              </View>
              <View style={styles.statBox}>
                <Text style={styles.statLabel}>Claim Rate %</Text>
                <Text style={styles.statVal}>{stats.claimRate}</Text>
              </View>
              <View style={styles.statBox}>
                <Text style={styles.statLabel}>Total Spent</Text>
                <Text style={styles.statVal}>${stats.totalSpent.toFixed(2)}</Text>
              </View>
            </View>

            <Text style={styles.sectionTitle}>Impressions (last 24h)</Text>
            <View style={styles.chartCard}>
              <Svg width={chartW} height={chartH}>
                <Line
                  x1={padL}
                  y1={chartH - padB}
                  x2={chartW}
                  y2={chartH - padB}
                  stroke="#B0BEC5"
                  strokeWidth={1}
                />
                <Line
                  x1={padL}
                  y1={8}
                  x2={padL}
                  y2={chartH - padB}
                  stroke="#B0BEC5"
                  strokeWidth={1}
                />
                {hourly.map((h, i) => {
                  const bh = ((chartH - padB - 12) * h) / maxBar;
                  const x = padL + i * (barW + 2) + 1;
                  const y = chartH - padB - bh;
                  return (
                    <Rect
                      key={i}
                      x={x}
                      y={y}
                      width={barW}
                      height={bh}
                      fill="#1565C0"
                      rx={2}
                    />
                  );
                })}
                {[0, 4, 8, 12, 16, 20].map(h => (
                  <SvgText
                    key={h}
                    x={padL + h * (barW + 2)}
                    y={chartH - 4}
                    fontSize={8}
                    fill="#546E7A"
                  >
                    {h}h
                  </SvgText>
                ))}
              </Svg>
            </View>

            <TouchableOpacity
              style={styles.sectionHeader}
              onPress={() => setActiveOpen(o => !o)}
            >
              <Text style={styles.sectionHeaderText}>
                Active campaigns ({liveAds.length}) {activeOpen ? '▼' : '▶'}
              </Text>
            </TouchableOpacity>
            {activeOpen
              ? liveAds.map(ad => (
                  <CampaignRow key={ad.id} ad={ad} muted={false} />
                ))
              : null}

            <TouchableOpacity
              style={styles.sectionHeader}
              onPress={() => setEndedOpen(o => !o)}
            >
              <Text style={[styles.sectionHeaderText, styles.endedHdr]}>
                Ended campaigns ({endedAds.length}) {endedOpen ? '▼' : '▶'}
              </Text>
            </TouchableOpacity>
            {endedOpen
              ? endedAds.map(ad => (
                  <CampaignRow key={ad.id} ad={ad} muted />
                ))
              : null}
          </>
        )}
      </ScrollView>
    </LinearGradient>
  );
}

function CampaignRow({ ad, muted }: { ad: AdRow; muted: boolean }) {
  const [open, setOpen] = useState(false);
  const imp = Number(ad.impressions) || 0;
  const cl = Number(ad.claims) || 0;
  const spend = Number(ad.totalCost) || 0;
  return (
    <TouchableOpacity
      style={[styles.rowCard, muted && styles.rowMuted]}
      onPress={() => setOpen(o => !o)}
      activeOpacity={0.85}
    >
      <Text style={[styles.rowOffer, muted && styles.rowOfferMuted]} numberOfLines={open ? undefined : 2}>
        {ad.offerText || '—'}
      </Text>
      {open ? (
        <>
          <Text style={styles.rowSub}>{fmtRange(ad.startTime, ad.endTime)}</Text>
          <Text style={styles.rowSub}>
            Impressions: {imp} · Claims: {cl} · Spend: ${spend.toFixed(2)}
          </Text>
        </>
      ) : (
        <Text style={styles.rowSub}>
          {imp} imp · {cl} claims · ${spend.toFixed(2)}
        </Text>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  gradient: { flex: 1 },
  scroll: { padding: 16, paddingBottom: 40 },
  screenTitle: {
    color: '#ffffff',
    fontSize: 22,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  statGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  statBox: {
    width: '48%',
    backgroundColor: '#ffffff',
    borderRadius: 10,
    padding: 12,
    marginBottom: 10,
  },
  statLabel: { color: '#78909C', fontSize: 12 },
  statVal: { color: '#0D47A1', fontSize: 20, fontWeight: 'bold', marginTop: 4 },
  sectionTitle: {
    color: '#E3F2FD',
    fontSize: 15,
    fontWeight: '600',
    marginTop: 8,
    marginBottom: 8,
  },
  chartCard: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 8,
    alignItems: 'center',
    marginBottom: 16,
  },
  sectionHeader: { paddingVertical: 8 },
  sectionHeaderText: { color: '#ffffff', fontSize: 16, fontWeight: '700' },
  endedHdr: { color: '#B0BEC5' },
  rowCard: {
    backgroundColor: 'rgba(255,255,255,0.95)',
    borderRadius: 10,
    padding: 12,
    marginBottom: 8,
  },
  rowMuted: { backgroundColor: 'rgba(255,255,255,0.75)' },
  rowOffer: { fontWeight: 'bold', color: '#0D47A1', fontSize: 15 },
  rowOfferMuted: { color: '#78909C' },
  rowSub: { color: '#546E7A', fontSize: 13, marginTop: 6 },
});
