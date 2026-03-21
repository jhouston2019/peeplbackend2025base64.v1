import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  KeyboardAvoidingView,
  Platform,
  Alert,
  ScrollView,
  ActivityIndicator,
  Linking,
} from 'react-native';
import auth from '@react-native-firebase/auth';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../types/Navigation';
import { RegisterData } from '../types/User';
import { authService } from '../services/AuthService';

interface RegisterScreenProps {
  onRegister?: (userData: RegisterData) => void | Promise<void>;
  navigation: StackNavigationProp<RootStackParamList, 'Register'>;
}

const TERMS_URL = 'https://peepl.app/terms';
const PRIVACY_URL = 'https://peepl.app/privacy';

export default function RegisterScreen({ navigation }: RegisterScreenProps) {
  const [fullName, setFullName] = useState('');
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const splitFullName = (name: string): { firstName: string; lastName: string } => {
    const trimmed = name.trim();
    const parts = trimmed.split(/\s+/);
    const firstName = parts[0] || '';
    const lastName = parts.slice(1).join(' ') || '';
    return { firstName, lastName };
  };

  const handleRegister = async () => {
    if (!fullName.trim() || !username.trim() || !email.trim() || !password.trim()) {
      Alert.alert('Error', 'Please fill in all fields');
      return;
    }

    if (password.length < 6) {
      Alert.alert('Error', 'Password must be at least 6 characters');
      return;
    }

    const { firstName, lastName } = splitFullName(fullName);
    const payload: RegisterData = {
      email: email.trim(),
      password,
      username: username.trim(),
      firstName,
      lastName,
    };

    setIsLoading(true);
    try {
      const response = await authService.register(payload);

      if (response.success) {
        try {
          await auth().currentUser?.updateProfile({ displayName: fullName.trim() });
        } catch {
          // displayName is optional for confirmation screen
        }
        navigation.navigate('SignUpConfirmed' as never);
      } else {
        Alert.alert('Registration failed', response.error || 'Please try again');
      }
    } catch {
      Alert.alert('Error', 'Something went wrong. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.keyboardView}
      >
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <Text style={styles.header}>Join Peepl</Text>

          <TouchableOpacity
            style={styles.facebookButton}
            onPress={() => Alert.alert('OAuth coming soon')}
            activeOpacity={0.85}
          >
            <Text style={styles.facebookButtonText}>Sign up with Facebook</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.googleButton}
            onPress={() => Alert.alert('OAuth coming soon')}
            activeOpacity={0.85}
          >
            <Text style={styles.googleButtonText}>Sign up with Google</Text>
          </TouchableOpacity>

          <View style={styles.dividerRow}>
            <View style={styles.dividerLine} />
            <Text style={styles.dividerText}>or sign up with email</Text>
            <View style={styles.dividerLine} />
          </View>

          <TextInput
            style={styles.input}
            placeholder="Full name"
            placeholderTextColor="#757575"
            value={fullName}
            onChangeText={setFullName}
            autoCapitalize="words"
          />

          <TextInput
            style={styles.input}
            placeholder="Username"
            placeholderTextColor="#757575"
            value={username}
            onChangeText={setUsername}
            autoCapitalize="none"
            autoCorrect={false}
          />

          <TextInput
            style={styles.input}
            placeholder="Email address"
            placeholderTextColor="#757575"
            value={email}
            onChangeText={setEmail}
            keyboardType="email-address"
            autoCapitalize="none"
            autoCorrect={false}
          />

          <TextInput
            style={styles.input}
            placeholder="Password"
            placeholderTextColor="#757575"
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            autoCapitalize="none"
            autoCorrect={false}
          />

          <Text style={styles.termsText}>
            By creating an account, you agree to our{' '}
            <Text style={styles.termsLink} onPress={() => Linking.openURL(TERMS_URL)}>
              Terms of Service
            </Text>{' '}
            and{' '}
            <Text style={styles.termsLink} onPress={() => Linking.openURL(PRIVACY_URL)}>
              Privacy Policy
            </Text>
            .
          </Text>

          <TouchableOpacity
            style={[styles.createButton, isLoading && styles.createButtonDisabled]}
            onPress={handleRegister}
            disabled={isLoading}
            activeOpacity={0.85}
          >
            {isLoading ? (
              <ActivityIndicator color="#000000" />
            ) : (
              <Text style={styles.createButtonText}>Create Account</Text>
            )}
          </TouchableOpacity>

          <View style={styles.footer}>
            <Text style={styles.footerPlain}>Already have an account? </Text>
            <TouchableOpacity onPress={() => navigation.navigate('Login')}>
              <Text style={styles.footerLink}>Sign in</Text>
            </TouchableOpacity>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1565C0',
  },
  keyboardView: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: 24,
    paddingVertical: 24,
    paddingBottom: 40,
  },
  header: {
    color: '#FFFFFF',
    fontSize: 32,
    fontWeight: 'bold',
    marginBottom: 24,
    textAlign: 'center',
  },
  facebookButton: {
    backgroundColor: '#1877F2',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    marginBottom: 12,
  },
  facebookButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  googleButton: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    marginBottom: 20,
  },
  googleButtonText: {
    color: '#212121',
    fontSize: 16,
    fontWeight: '600',
  },
  dividerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 20,
  },
  dividerLine: {
    flex: 1,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.35)',
  },
  dividerText: {
    color: '#FFFFFF',
    paddingHorizontal: 10,
    fontSize: 13,
  },
  input: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    fontSize: 16,
    color: '#212121',
    marginBottom: 14,
  },
  termsText: {
    color: '#FFFFFF',
    fontSize: 12,
    textAlign: 'center',
    lineHeight: 18,
    marginBottom: 20,
    marginTop: 4,
  },
  termsLink: {
    color: '#FFC107',
    fontWeight: '600',
  },
  createButton: {
    backgroundColor: '#FFC107',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    marginBottom: 24,
  },
  createButtonDisabled: {
    opacity: 0.7,
  },
  createButtonText: {
    color: '#000000',
    fontSize: 16,
    fontWeight: 'bold',
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    flexWrap: 'wrap',
  },
  footerPlain: {
    color: '#FFFFFF',
    fontSize: 15,
  },
  footerLink: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '600',
    textDecorationLine: 'underline',
  },
});
