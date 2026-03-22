import React, { useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Alert,
  Platform,
  Modal,
  ActivityIndicator,
} from 'react-native';
import DateTimePicker, {
  DateTimePickerEvent,
} from '@react-native-community/datetimepicker';
import LinearGradient from 'react-native-linear-gradient';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { authService } from '../../services/AuthService';
import { RootStackParamList } from '../../types/Navigation';

const BASE_URL = __DEV__ ? 'http://localhost:3000' : 'https://your-production-api.com';

type Props = {
  route: RouteProp<RootStackParamList, 'MerchantPortal'>;
  navigation: StackNavigationProp<RootStackParamList, 'MerchantPortal'>;
};

type RateKey = 'basic' | 'standard' | 'premium';

const RATES: Record<RateKey, { label: string; sub: string; perHour: number }> = {
  basic: { label: 'Basic — $10/hr', sub: 'Standard reach', perHour: 10 },
  standard: { label: 'Standard — $25/hr', sub: '2× reach + highlighted', perHour: 25 },
  premium: { label: 'Premium — $50/hr', sub: 'Maximum reach + deal alerts', perHour: 50 },
};

function formatSlot(d: Date): string {
  const today = new Date();
  const isToday =
    d.getDate() === today.getDate() &&
    d.getMonth() === today.getMonth() &&
    d.getFullYear() === today.getFullYear();
  const time = d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
  if (isToday) return `Today at ${time}`;
  return `${d.toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  })} at ${time}`;
}

function mergeDateTime(datePart: Date, timePart: Date): Date {
  const out = new Date(datePart);
  out.setHours(timePart.getHours(), timePart.getMinutes(), timePart.getSeconds(), 0);
  return out;
}

export default function MerchantPortalScreen({ route, navigation }: Props) {
  const { merchant } = route.params;
  const [step, setStep] = useState(1);
  const [offerText, setOfferText] = useState('');
  const [startDate, setStartDate] = useState(() => {
    const d = new Date();
    d.setHours(20, 0, 0, 0);
    return d;
  });
  const [endDate, setEndDate] = useState(() => {
    const d = new Date();
    d.setHours(22, 0, 0, 0);
    return d;
  });
  const [rateType, setRateType] = useState<RateKey | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const [iosPick, setIosPick] = useState<'start' | 'end' | null>(null);
  const [androidPick, setAndroidPick] = useState<
    | null
    | { which: 'start' | 'end'; phase: 'date' | 'time'; datePart?: Date }
  >(null);

  const hours = useMemo(() => {
    const h = (endDate.getTime() - startDate.getTime()) / 3600000;
    return h;
  }, [startDate, endDate]);

  const totalCost = useMemo(() => {
    if (!rateType) return 0;
    return parseFloat((hours * RATES[rateType].perHour).toFixed(2));
  }, [hours, rateType]);

  const openStart = () => {
    if (Platform.OS === 'ios') setIosPick('start');
    else setAndroidPick({ which: 'start', phase: 'date' });
  };

  const openEnd = () => {
    if (Platform.OS === 'ios') setIosPick('end');
    else setAndroidPick({ which: 'end', phase: 'date' });
  };

  const onAndroidChange = (event: DateTimePickerEvent, selected?: Date) => {
    if (event.type === 'dismissed') {
      setAndroidPick(null);
      return;
    }
    if (!androidPick || !selected) return;
    if (androidPick.phase === 'date') {
      const base =
        androidPick.which === 'start' ? startDate : endDate;
      const merged = mergeDateTime(selected, base);
      if (androidPick.which === 'start') setStartDate(merged);
      else setEndDate(merged);
      setAndroidPick({ which: androidPick.which, phase: 'time', datePart: merged });
      return;
    }
    const datePart = androidPick.datePart ?? (androidPick.which === 'start' ? startDate : endDate);
    const merged = mergeDateTime(datePart, selected);
    if (androidPick.which === 'start') setStartDate(merged);
    else setEndDate(merged);
    setAndroidPick(null);
  };

  const onIosChange = (_: unknown, selected?: Date) => {
    if (!selected || !iosPick) return;
    if (iosPick === 'start') setStartDate(selected);
    else setEndDate(selected);
  };

  const onNext1 = () => {
    if (!offerText.trim()) {
      Alert.alert('Offer', 'Please write your offer.');
      return;
    }
    setStep(2);
  };

  const onNext2 = () => {
    if (hours <= 0) {
      Alert.alert('Time', 'End time must be after start time.');
      return;
    }
    if (!rateType) {
      Alert.alert('Rate', 'Please select a rate.');
      return;
    }
    setStep(3);
  };

  const onSubmit = async () => {
    if (!rateType || !merchant.id) return;
    setSubmitting(true);
    try {
      const token = await authService.getIdToken();
      const res = await fetch(`${BASE_URL}/merchant/ads`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          merchantId: merchant.id,
          offerText: offerText.trim(),
          startTime: startDate.toISOString(),
          endTime: endDate.toISOString(),
          rateType,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        Alert.alert('Ad', (data as { error?: string }).error || 'Could not submit');
        return;
      }
      Alert.alert('Your ad is live!');
      setStep(1);
      setOfferText('');
      setRateType(null);
    } catch {
      Alert.alert('Ad', 'Network error');
    } finally {
      setSubmitting(false);
    }
  };

  const biz = merchant.businessName || 'Business';
  const num = merchant.merchantNumber || '';

  const pickerValue =
    iosPick === 'start' || androidPick?.which === 'start' ? startDate : endDate;

  return (
    <LinearGradient colors={['#1565C0', '#0D47A1']} style={styles.gradient}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <View style={styles.headerCard}>
          <Text style={styles.bizName}>{biz}</Text>
          <Text style={styles.merchantNum}>{num}</Text>
          <View style={styles.statusRow}>
            <Text style={styles.statusDot}>●</Text>
            <Text style={styles.statusText}>Active</Text>
          </View>
          <View style={styles.portalLinks}>
            <TouchableOpacity
              onPress={() => navigation.navigate('MerchantActivity', { merchantId: merchant.id })}
            >
              <Text style={styles.link}>Activity</Text>
            </TouchableOpacity>
            <Text style={styles.linkSep}>|</Text>
            <TouchableOpacity onPress={() => navigation.navigate('MerchantAccountInfo', { merchant })}>
              <Text style={styles.link}>Account</Text>
            </TouchableOpacity>
          </View>
        </View>

        <Text style={styles.stepInd}>Step {step} of 3</Text>

        {step === 1 ? (
          <View style={styles.card}>
            <Text style={styles.labelBold}>Write your offer</Text>
            <TextInput
              style={styles.offerInput}
              multiline
              maxLength={40}
              placeholder="e.g. '50% off all cocktails tonight'"
              placeholderTextColor="#90A4AE"
              value={offerText}
              onChangeText={setOfferText}
            />
            <Text style={styles.counter}>{offerText.length} / 40</Text>
            <TouchableOpacity style={styles.goldBtn} onPress={onNext1}>
              <Text style={styles.goldBtnText}>Next →</Text>
            </TouchableOpacity>
          </View>
        ) : null}

        {step === 2 ? (
          <View style={styles.card}>
            <Text style={styles.labelBold}>Start time</Text>
            <TouchableOpacity style={styles.timeField} onPress={openStart}>
              <Text style={styles.timeFieldText}>{formatSlot(startDate)}</Text>
            </TouchableOpacity>

            <Text style={[styles.labelBold, styles.mt]}>End time</Text>
            <TouchableOpacity style={styles.timeField} onPress={openEnd}>
              <Text style={styles.timeFieldText}>{formatSlot(endDate)}</Text>
            </TouchableOpacity>

            <Text style={[styles.labelBold, styles.mt]}>Rate</Text>
            {(Object.keys(RATES) as RateKey[]).map(key => {
              const sel = rateType === key;
              return (
                <TouchableOpacity
                  key={key}
                  style={[styles.rateCard, sel && styles.rateCardSel]}
                  onPress={() => setRateType(key)}
                >
                  <Text style={styles.rateTitle}>{RATES[key].label}</Text>
                  <Text style={styles.rateSub}>{RATES[key].sub}</Text>
                </TouchableOpacity>
              );
            })}

            <TouchableOpacity style={styles.goldBtn} onPress={onNext2}>
              <Text style={styles.goldBtnText}>Next →</Text>
            </TouchableOpacity>
          </View>
        ) : null}

        {step === 3 ? (
          <View style={styles.card}>
            <Text style={styles.reviewTitle}>Review your ad</Text>
            <View style={styles.summary}>
              <Text style={styles.sumLine}>{offerText}</Text>
              <Text style={styles.sumMuted}>
                {formatSlot(startDate)} → {formatSlot(endDate)}
              </Text>
              <Text style={styles.sumMuted}>
                Rate: {rateType ? RATES[rateType].label : ''}
              </Text>
              <Text style={styles.sumMuted}>Duration: {hours.toFixed(2)} hr</Text>
              <Text style={styles.sumTotal}>Total: ${totalCost.toFixed(2)}</Text>
            </View>
            <TouchableOpacity
              style={styles.goldBtn}
              onPress={onSubmit}
              disabled={submitting}
            >
              {submitting ? (
                <ActivityIndicator color="#000" />
              ) : (
                <Text style={styles.goldBtnText}>Submit Ad</Text>
              )}
            </TouchableOpacity>
          </View>
        ) : null}

        {Platform.OS === 'ios' && iosPick ? (
          <Modal transparent animationType="slide" visible>
            <View style={styles.modalBackdrop}>
              <View style={styles.modalInner}>
                <DateTimePicker
                  value={pickerValue}
                  mode="datetime"
                  display="spinner"
                  onChange={onIosChange}
                />
                <TouchableOpacity
                  style={styles.goldBtn}
                  onPress={() => setIosPick(null)}
                >
                  <Text style={styles.goldBtnText}>Done</Text>
                </TouchableOpacity>
              </View>
            </View>
          </Modal>
        ) : null}

        {Platform.OS === 'android' && androidPick ? (
          <DateTimePicker
            value={
              androidPick.phase === 'date'
                ? pickerValue
                : androidPick.datePart ?? pickerValue
            }
            mode={androidPick.phase === 'date' ? 'date' : 'time'}
            display="default"
            onChange={onAndroidChange}
          />
        ) : null}
      </ScrollView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  gradient: { flex: 1 },
  scroll: { padding: 16, paddingBottom: 40 },
  headerCard: {
    backgroundColor: 'rgba(255,255,255,0.95)',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
  },
  bizName: { fontSize: 18, fontWeight: 'bold', color: '#0D47A1' },
  merchantNum: { fontSize: 13, color: '#78909C', marginTop: 4 },
  statusRow: { flexDirection: 'row', alignItems: 'center', marginTop: 8 },
  statusDot: { color: '#4CAF50', fontSize: 14, marginRight: 6 },
  statusText: { color: '#37474F', fontSize: 14 },
  portalLinks: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 12,
    justifyContent: 'center',
  },
  link: { color: '#1565C0', fontSize: 14, fontWeight: '600' },
  linkSep: { color: '#B0BEC5', marginHorizontal: 10 },
  stepInd: { color: '#E3F2FD', fontSize: 13, marginBottom: 8 },
  card: {
    backgroundColor: 'rgba(255,255,255,0.95)',
    borderRadius: 12,
    padding: 16,
  },
  labelBold: { fontWeight: 'bold', fontSize: 16, color: '#0D47A1' },
  offerInput: {
    minHeight: 80,
    borderWidth: 1,
    borderColor: '#CFD8DC',
    borderRadius: 8,
    padding: 12,
    marginTop: 8,
    color: '#263238',
  },
  counter: { alignSelf: 'flex-end', color: '#78909C', marginTop: 4, fontSize: 13 },
  goldBtn: {
    backgroundColor: '#FFC107',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 16,
  },
  goldBtnText: { color: '#000000', fontSize: 17, fontWeight: '700' },
  timeField: {
    backgroundColor: '#ffffff',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#CFD8DC',
    padding: 14,
    marginTop: 8,
  },
  timeFieldText: { fontSize: 16, color: '#263238' },
  mt: { marginTop: 16 },
  rateCard: {
    borderWidth: 2,
    borderColor: '#ECEFF1',
    borderRadius: 10,
    padding: 12,
    marginTop: 8,
    backgroundColor: '#fff',
  },
  rateCardSel: { borderColor: '#1565C0', backgroundColor: '#E3F2FD' },
  rateTitle: { fontWeight: '700', color: '#0D47A1' },
  rateSub: { color: '#546E7A', fontSize: 13, marginTop: 4 },
  reviewTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#0D47A1',
    marginBottom: 12,
  },
  summary: { marginBottom: 8 },
  sumLine: { fontSize: 16, fontWeight: '600', color: '#263238' },
  sumMuted: { color: '#546E7A', marginTop: 6, fontSize: 14 },
  sumTotal: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#0D47A1',
    marginTop: 12,
  },
  modalBackdrop: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0,0,0,0.4)',
  },
  modalInner: {
    backgroundColor: '#fff',
    padding: 16,
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
  },
});
