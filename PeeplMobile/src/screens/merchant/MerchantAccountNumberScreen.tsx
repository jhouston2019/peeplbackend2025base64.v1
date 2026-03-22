import React, { useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Share,
  ScrollView,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import KeepAwake from 'react-native-keep-awake';
import { CommonActions } from '@react-navigation/native';
import { RouteProp } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { MerchantDoc, RootStackParamList } from '../../types/Navigation';

type Props = {
  route: RouteProp<RootStackParamList, 'MerchantAccountNumber'>;
  navigation: StackNavigationProp<RootStackParamList, 'MerchantAccountNumber'>;
};

export default function MerchantAccountNumberScreen({ route, navigation }: Props) {
  const {
    merchantId,
    merchantNumber,
    businessName,
    address,
    city,
    category,
    contactName,
    email,
    phone,
  } = route.params;

  useEffect(() => {
    const KA = KeepAwake as unknown as { activate?: () => void };
    KA.activate?.();
    return () => {
      const KA2 = KeepAwake as unknown as { deactivate?: () => void };
      KA2.deactivate?.();
    };
  }, []);

  const goPortal = () => {
    const merchant: MerchantDoc = {
      id: merchantId,
      merchantNumber,
      businessName,
      address,
      city,
      category,
      contactName,
      email,
      phone,
      isActive: true,
    };
    navigation.dispatch(
      CommonActions.reset({
        index: 1,
        routes: [{ name: 'MainTabs' }, { name: 'MerchantPortal', params: { merchant } }],
      })
    );
  };

  const onShare = () => {
    Share.share({ message: `My Peepl Merchant # is ${merchantNumber}` });
  };

  return (
    <LinearGradient colors={['#1565C0', '#0D47A1']} style={styles.gradient}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={styles.emoji}>🎉</Text>
        <Text style={styles.title}>{"You're live on Peepl!"}</Text>

        <View style={styles.numberBox}>
          <Text style={styles.number}>{merchantNumber}</Text>
        </View>

        <Text style={styles.instruction}>
          {"This is your Merchant #. You'll need it to sign in to your portal."}
        </Text>

        <TouchableOpacity style={styles.goldBtn} onPress={goPortal} activeOpacity={0.85}>
          <Text style={styles.goldBtnText}>Go to Merchant Portal →</Text>
        </TouchableOpacity>

        <TouchableOpacity onPress={onShare} style={styles.linkWrap}>
          <Text style={styles.link}>Save to notes app</Text>
        </TouchableOpacity>
      </ScrollView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  gradient: { flex: 1 },
  scroll: {
    padding: 24,
    paddingTop: 48,
    alignItems: 'center',
  },
  emoji: { fontSize: 72, marginBottom: 16 },
  title: {
    color: '#ffffff',
    fontSize: 28,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 24,
  },
  numberBox: {
    borderWidth: 2,
    borderColor: '#ffffff',
    borderRadius: 16,
    paddingVertical: 20,
    paddingHorizontal: 28,
    marginBottom: 20,
  },
  number: {
    color: '#FFC107',
    fontSize: 48,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  instruction: {
    color: '#ffffff',
    fontSize: 14,
    textAlign: 'center',
    marginBottom: 32,
    lineHeight: 22,
  },
  goldBtn: {
    backgroundColor: '#FFC107',
    borderRadius: 12,
    paddingVertical: 16,
    width: '100%',
    alignItems: 'center',
  },
  goldBtnText: { color: '#000000', fontSize: 17, fontWeight: '700' },
  linkWrap: { marginTop: 20 },
  link: { color: '#ffffff', fontSize: 14, textDecorationLine: 'underline' },
});
