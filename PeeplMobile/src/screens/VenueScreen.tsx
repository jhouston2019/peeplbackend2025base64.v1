import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Image,
  ImageBackground,
  FlatList,
  Alert,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { RootStackParamList } from '../types/Navigation';
import { Venue } from '../types/Venue';
import { Peep } from '../types/Peep';
import { ApiService } from '../services/ApiService';

interface VenueScreenProps {
  route: RouteProp<RootStackParamList, 'Venue'>;
  navigation: NativeStackNavigationProp<RootStackParamList, 'Venue'>;
}

const CROWD_SIZE_COLORS = ['#4CAF50', '#8BC34A', '#FFC107', '#FF9800', '#F44336'];
const CROWD_SIZE_LABELS = ['Empty', 'Light', 'Moderate', 'Busy', 'Packed'];

export default function VenueScreen({ route, navigation }: VenueScreenProps) {
  const { venue } = route.params;
  const [peeps, setPeeps] = useState<Peep[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [currentCrowd, setCurrentCrowd] = useState<Peep | null>(null);

  useEffect(() => {
    loadVenuePeeps();
  }, []);

  const loadVenuePeeps = async () => {
    try {
      const response: any = await ApiService.getVenuePeeps(venue.id);
      const peepsList = response || [];
      setPeeps(peepsList);
      if (peepsList.length > 0) {
        setCurrentCrowd(peepsList[0]);
      }
    } catch (error) {
      console.error('Error loading venue peeps:', error);
      Alert.alert('Error', 'Failed to load peeps. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreatePeep = () => {
    navigation.navigate('CreatePeep', { venue });
  };

  const formatTimeAgo = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    const diffDays = Math.floor(diffHours / 24);
    return `${diffDays}d ago`;
  };

  const getCrowdColor = (size: number) => {
    return CROWD_SIZE_COLORS[size - 1] || '#999';
  };

  const getCrowdLabel = (size: number) => {
    return CROWD_SIZE_LABELS[size - 1] || 'Unknown';
  };

  const getTrendIcon = (trend: string) => {
    if (trend === 'getting_busier') return 'trending-up';
    if (trend === 'clearing_out') return 'trending-down';
    return 'trending-flat';
  };

  const renderPeepItem = ({ item: peep, index }: { item: Peep; index: number }) => (
    <View style={styles.peepCard}>
      <View style={styles.peepHeader}>
        <View style={styles.userInfo}>
          {peep.user?.profileImageUrl && (
            <Image source={{ uri: peep.user.profileImageUrl }} style={styles.avatar} />
          )}
          <View>
            <Text style={styles.userName}>
              {peep.user?.firstName} {peep.user?.lastName}
            </Text>
            <Text style={styles.userHandle}>@{peep.user?.username}</Text>
          </View>
        </View>
        <Text style={styles.peepDate}>{formatTimeAgo(peep.createdAt)}</Text>
      </View>

      <View style={styles.crowdPill} style={{ backgroundColor: getCrowdColor(peep.crowdSize) }}>
        <Text style={styles.crowdPillText}>{getCrowdLabel(peep.crowdSize)}</Text>
      </View>

      {peep.vibe.length > 0 && (
        <View style={styles.vibeContainer}>
          {peep.vibe.map((v, i) => (
            <View key={i} style={styles.vibeTag}>
              <Text style={styles.vibeTagText}>{v}</Text>
            </View>
          ))}
        </View>
      )}

      <Text style={styles.peepDescription}>{peep.description}</Text>

      {peep.imageUrl && (
        <Image source={{ uri: peep.imageUrl }} style={styles.peepImage} />
      )}

      <View style={styles.peepActions}>
        <TouchableOpacity style={styles.peepAction}>
          <Icon name="favorite-border" size={20} color="#666" />
          <Text style={styles.peepActionText}>{peep.likeCount}</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.peepAction}>
          <Icon name="chat-bubble-outline" size={20} color="#666" />
          <Text style={styles.peepActionText}>{peep.commentCount}</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  return (
    <View style={styles.container}>
      {/* Hero Image */}
      {venue.imageUrl ? (
        <ImageBackground source={{ uri: venue.imageUrl }} style={styles.heroImage}>
          <View style={styles.heroOverlay}>
            <Text style={styles.heroVenueName}>{venue.name}</Text>
          </View>
        </ImageBackground>
      ) : (
        <View style={styles.heroPlaceholder}>
          <Text style={styles.heroVenueName}>{venue.name}</Text>
        </View>
      )}

      {/* Current Crowd Card */}
      {currentCrowd && (
        <View style={styles.currentCrowdCard}>
          <View style={styles.currentCrowdHeader}>
            <Text style={styles.currentCrowdTitle}>Current Crowd</Text>
            <Text style={styles.currentCrowdTime}>{formatTimeAgo(currentCrowd.createdAt)}</Text>
          </View>
          <View style={styles.currentCrowdContent}>
            <View style={[styles.crowdSizeBadge, { backgroundColor: getCrowdColor(currentCrowd.crowdSize) }]}>
              <Text style={styles.crowdSizeBadgeText}>{getCrowdLabel(currentCrowd.crowdSize)}</Text>
            </View>
            <Icon name={getTrendIcon(currentCrowd.crowdTrend)} size={24} color="#1565C0" />
          </View>
          {currentCrowd.vibe.length > 0 && (
            <View style={styles.currentVibeContainer}>
              {currentCrowd.vibe.slice(0, 3).map((v, i) => (
                <View key={i} style={styles.currentVibeTag}>
                  <Text style={styles.currentVibeText}>{v}</Text>
                </View>
              ))}
            </View>
          )}
        </View>
      )}

      {/* Create Peep Button */}
      <View style={styles.actionButtons}>
        <TouchableOpacity style={styles.createPeepButton} onPress={handleCreatePeep}>
          <Icon name="add" size={20} color="#ffffff" />
          <Text style={styles.createPeepButtonText}>Create Peep</Text>
        </TouchableOpacity>
      </View>

      {/* Peeps Feed */}
      <View style={styles.peepsSection}>
        <Text style={styles.sectionTitle}>Recent Peeps</Text>
        
        {isLoading ? (
          <Text style={styles.loadingText}>Loading peeps...</Text>
        ) : peeps.length === 0 ? (
          <View style={styles.emptyState}>
            <Icon name="chat-bubble-outline" size={48} color="#CCCCCC" />
            <Text style={styles.emptyStateText}>No peeps yet</Text>
            <Text style={styles.emptyStateSubtext}>Be the first to share your experience!</Text>
          </View>
        ) : (
          <FlatList
            data={peeps}
            renderItem={renderPeepItem}
            keyExtractor={(item) => item.id}
            scrollEnabled={false}
          />
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  heroImage: {
    width: '100%',
    height: 250,
  },
  heroOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.4)',
    justifyContent: 'flex-end',
    padding: 20,
  },
  heroPlaceholder: {
    width: '100%',
    height: 250,
    backgroundColor: '#1565C0',
    justifyContent: 'flex-end',
    padding: 20,
  },
  heroVenueName: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#ffffff',
  },
  currentCrowdCard: {
    margin: 20,
    padding: 16,
    backgroundColor: '#F8F9FA',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  currentCrowdHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  currentCrowdTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
  },
  currentCrowdTime: {
    fontSize: 12,
    color: '#999',
  },
  currentCrowdContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  crowdSizeBadge: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  crowdSizeBadgeText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#ffffff',
  },
  currentVibeContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 12,
  },
  currentVibeTag: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: '#1565C0',
    borderRadius: 16,
  },
  currentVibeText: {
    fontSize: 12,
    color: '#ffffff',
    fontWeight: '600',
  },
  actionButtons: {
    paddingHorizontal: 20,
    marginBottom: 20,
  },
  createPeepButton: {
    backgroundColor: '#FFC107',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 14,
    borderRadius: 12,
  },
  createPeepButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
  peepsSection: {
    flex: 1,
    paddingHorizontal: 20,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 16,
  },
  loadingText: {
    textAlign: 'center',
    color: '#666',
    fontSize: 16,
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyStateText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#666',
    marginTop: 12,
  },
  emptyStateSubtext: {
    fontSize: 14,
    color: '#999',
    marginTop: 4,
  },
  peepCard: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  peepHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  userInfo: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
  },
  userName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  userHandle: {
    fontSize: 14,
    color: '#666',
  },
  peepDate: {
    fontSize: 12,
    color: '#999',
  },
  crowdPill: {
    alignSelf: 'flex-start',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    marginBottom: 8,
  },
  crowdPillText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#ffffff',
  },
  vibeContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
    marginBottom: 12,
  },
  vibeTag: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    backgroundColor: '#E3F2FD',
    borderRadius: 12,
  },
  vibeTagText: {
    fontSize: 12,
    color: '#1565C0',
    fontWeight: '500',
  },
  peepDescription: {
    fontSize: 14,
    color: '#333',
    lineHeight: 20,
    marginBottom: 12,
  },
  peepImage: {
    width: '100%',
    height: 200,
    borderRadius: 8,
    marginBottom: 12,
  },
  peepActions: {
    flexDirection: 'row',
    borderTopWidth: 1,
    borderTopColor: '#F0F0F0',
    paddingTop: 12,
  },
  peepAction: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 20,
  },
  peepActionText: {
    fontSize: 14,
    color: '#666',
    marginLeft: 4,
  },
});
