import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  Image,
  Alert,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import Slider from '@react-native-community/slider';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { launchImageLibrary, ImagePickerResponse, MediaType } from 'react-native-image-picker';
import { StackNavigationProp } from '@react-navigation/stack';
import { RouteProp } from '@react-navigation/native';
import { RootStackParamList } from '../types/Navigation';
import { Venue } from '../types/Venue';
import { CreatePeepData } from '../types/Peep';
import { ApiService } from '../services/ApiService';

interface CreatePeepScreenProps {
  route: RouteProp<RootStackParamList, 'CreatePeep'>;
  navigation: StackNavigationProp<RootStackParamList, 'CreatePeep'>;
}

const AGE_RANGE_OPTIONS = ['0-10', '10-14', '14-18', '19-24', '25-30', '31-40', '41-50', '51-60', '61-70', '71-80', '80+'];
const VIBE_OPTIONS = ['Chill', 'Laid Back', 'Casual', 'Rowdy', 'Dancing', 'Groovy', 'Formal', 'Sexy', 'Sports Fans', 'Families', 'Grungy', 'Business'];
const CROWD_SIZE_LABELS = ['Empty', 'Light', 'Moderate', 'Busy', 'Packed'];

function buildVenueFromIds(venueId: string, venueName: string): Venue {
  return {
    id: venueId,
    name: venueName,
    address: '',
    latitude: 0,
    longitude: 0,
    category: '',
    createdBy: '',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    isActive: true,
    peepCount: 0,
    averageRating: 0,
    totalRatings: 0,
  };
}

export default function CreatePeepScreen({ route, navigation }: CreatePeepScreenProps) {
  const { venue, location, venues = [], venueId, venueName } = route.params || {};
  const initialVenue =
    venue ||
    (venueId && venueName ? buildVenueFromIds(venueId, venueName) : null);
  const [selectedVenue, setSelectedVenue] = useState<Venue | null>(initialVenue);
  const [description, setDescription] = useState('');
  const [crowdSize, setCrowdSize] = useState<1 | 2 | 3 | 4 | 5>(3);
  const [mfRatio, setMfRatio] = useState(50);
  const [akRatio, setAkRatio] = useState(100);
  const [selectedAgeRanges, setSelectedAgeRanges] = useState<string[]>([]);
  const [selectedVibes, setSelectedVibes] = useState<string[]>([]);
  const [crowdTrend, setCrowdTrend] = useState<'getting_busier' | 'steady' | 'clearing_out'>('steady');
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSelectImage = () => {
    const options = {
      mediaType: 'photo' as MediaType,
      quality: 0.8,
      maxWidth: 1000,
      maxHeight: 1000,
    };

    launchImageLibrary(options, (response: ImagePickerResponse) => {
      if (response.didCancel || response.errorMessage) {
        return;
      }

      if (response.assets && response.assets[0]) {
        setSelectedImage(response.assets[0].uri || null);
      }
    });
  };

  const handleRemoveImage = () => {
    setSelectedImage(null);
  };

  const toggleAgeRange = (range: string) => {
    setSelectedAgeRanges(prev =>
      prev.includes(range) ? prev.filter(r => r !== range) : [...prev, range]
    );
  };

  const toggleVibe = (vibe: string) => {
    setSelectedVibes(prev =>
      prev.includes(vibe) ? prev.filter(v => v !== vibe) : [...prev, vibe]
    );
  };

  const handleSubmit = async () => {
    if (!selectedVenue) {
      Alert.alert('Error', 'Please select a venue');
      return;
    }

    if (!description.trim()) {
      Alert.alert('Error', 'Please enter a description');
      return;
    }

    setIsSubmitting(true);
    try {
      const peepData: CreatePeepData = {
        venueId: selectedVenue.id,
        description: description.trim(),
        crowdSize,
        mfRatio,
        akRatio,
        ageRanges: selectedAgeRanges,
        vibe: selectedVibes,
        crowdTrend,
        latitude: location?.latitude,
        longitude: location?.longitude,
        image: selectedImage ? {
          uri: selectedImage,
          type: 'image/jpeg',
          name: 'peep_image.jpg',
        } : undefined,
      };

      const response = (await ApiService.createPeep(peepData)) as {
        isPioneer?: boolean;
        venuesPioneedCount?: number;
      };

      if (response.isPioneer) {
        navigation.navigate('PioneerCongrats', {
          venueName: selectedVenue.name,
          venuesPioneedCount: response.venuesPioneedCount ?? 1,
        });
      } else {
        Alert.alert(
          'Success',
          'Your peep has been created!',
          [
            {
              text: 'OK',
              onPress: () => navigation.goBack(),
            },
          ]
        );
      }
    } catch (error) {
      console.error('Error creating peep:', error);
      Alert.alert('Error', 'Failed to create peep. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={styles.container}
    >
      <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
        {/* Venue Selection */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Venue</Text>
          {selectedVenue ? (
            <View style={styles.selectedVenue}>
              <View style={styles.venueInfo}>
                <Text style={styles.venueName}>{selectedVenue.name}</Text>
                <Text style={styles.venueAddress}>{selectedVenue.address}</Text>
              </View>
              <TouchableOpacity
                style={styles.overrideButton}
                onPress={() => setSelectedVenue(null)}
              >
                <Text style={styles.overrideButtonText}>Override</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <View style={styles.venueList}>
              {venues.map((v) => (
                <TouchableOpacity
                  key={v.id}
                  style={styles.venueOption}
                  onPress={() => setSelectedVenue(v)}
                >
                  <View style={styles.venueOptionInfo}>
                    <Text style={styles.venueOptionName}>{v.name}</Text>
                    <Text style={styles.venueOptionAddress}>{v.address}</Text>
                  </View>
                  <Icon name="chevron-right" size={24} color="#CCCCCC" />
                </TouchableOpacity>
              ))}
            </View>
          )}
        </View>

        {/* Crowd Size */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Crowd Size</Text>
          <Slider
            style={styles.slider}
            minimumValue={1}
            maximumValue={5}
            step={1}
            value={crowdSize}
            onValueChange={(value) => setCrowdSize(value as 1 | 2 | 3 | 4 | 5)}
            minimumTrackTintColor="#1565C0"
            maximumTrackTintColor="#E0E0E0"
            thumbTintColor="#1565C0"
          />
          <Text style={styles.sliderLabel}>{CROWD_SIZE_LABELS[crowdSize - 1]}</Text>
        </View>

        {/* M/F Ratio */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>M/F Ratio</Text>
          <Slider
            style={styles.slider}
            minimumValue={0}
            maximumValue={100}
            step={5}
            value={mfRatio}
            onValueChange={setMfRatio}
            minimumTrackTintColor="#1565C0"
            maximumTrackTintColor="#E0E0E0"
            thumbTintColor="#1565C0"
          />
          <View style={styles.sliderLabels}>
            <Text style={styles.sliderLabelLeft}>All Female</Text>
            <Text style={styles.sliderLabelCenter}>{mfRatio}% Male</Text>
            <Text style={styles.sliderLabelRight}>All Male</Text>
          </View>
        </View>

        {/* Adult/Kid Ratio */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Adult/Kid Ratio</Text>
          <Slider
            style={styles.slider}
            minimumValue={0}
            maximumValue={100}
            step={5}
            value={akRatio}
            onValueChange={setAkRatio}
            minimumTrackTintColor="#1565C0"
            maximumTrackTintColor="#E0E0E0"
            thumbTintColor="#1565C0"
          />
          <View style={styles.sliderLabels}>
            <Text style={styles.sliderLabelLeft}>All Kids</Text>
            <Text style={styles.sliderLabelCenter}>{akRatio}% Adults</Text>
            <Text style={styles.sliderLabelRight}>All Adults</Text>
          </View>
        </View>

        {/* Age Ranges */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Age Ranges</Text>
          <View style={styles.chipGrid}>
            {AGE_RANGE_OPTIONS.map((range) => (
              <TouchableOpacity
                key={range}
                style={[
                  styles.chip,
                  selectedAgeRanges.includes(range) && styles.chipSelected
                ]}
                onPress={() => toggleAgeRange(range)}
              >
                <Text style={[
                  styles.chipText,
                  selectedAgeRanges.includes(range) && styles.chipTextSelected
                ]}>
                  {range}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Vibe */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Vibe</Text>
          <View style={styles.chipGrid}>
            {VIBE_OPTIONS.map((vibe) => (
              <TouchableOpacity
                key={vibe}
                style={[
                  styles.chip,
                  selectedVibes.includes(vibe) && styles.chipSelected
                ]}
                onPress={() => toggleVibe(vibe)}
              >
                <Text style={[
                  styles.chipText,
                  selectedVibes.includes(vibe) && styles.chipTextSelected
                ]}>
                  {vibe}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Crowd Trend */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Crowd Trend</Text>
          <View style={styles.segmentedControl}>
            <TouchableOpacity
              style={[
                styles.segmentButton,
                styles.segmentButtonLeft,
                crowdTrend === 'getting_busier' && styles.segmentButtonActive
              ]}
              onPress={() => setCrowdTrend('getting_busier')}
            >
              <Text style={[
                styles.segmentButtonText,
                crowdTrend === 'getting_busier' && styles.segmentButtonTextActive
              ]}>
                Getting Busier
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.segmentButton,
                crowdTrend === 'steady' && styles.segmentButtonActive
              ]}
              onPress={() => setCrowdTrend('steady')}
            >
              <Text style={[
                styles.segmentButtonText,
                crowdTrend === 'steady' && styles.segmentButtonTextActive
              ]}>
                Steady
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.segmentButton,
                styles.segmentButtonRight,
                crowdTrend === 'clearing_out' && styles.segmentButtonActive
              ]}
              onPress={() => setCrowdTrend('clearing_out')}
            >
              <Text style={[
                styles.segmentButtonText,
                crowdTrend === 'clearing_out' && styles.segmentButtonTextActive
              ]}>
                Clearing Out
              </Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Notes */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Notes (Optional)</Text>
          <TextInput
            style={styles.descriptionInput}
            placeholder="Share your experience..."
            placeholderTextColor="#999"
            value={description}
            onChangeText={setDescription}
            multiline
            numberOfLines={4}
            maxLength={280}
          />
          <Text style={styles.characterCount}>{description.length}/280</Text>
        </View>

        {/* Photo */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Photo/Video (Optional)</Text>
          {selectedImage ? (
            <View style={styles.imageContainer}>
              <Image source={{ uri: selectedImage }} style={styles.selectedImage} />
              <TouchableOpacity style={styles.removeImageButton} onPress={handleRemoveImage}>
                <Icon name="close" size={20} color="#ffffff" />
              </TouchableOpacity>
            </View>
          ) : (
            <TouchableOpacity style={styles.addImageButton} onPress={handleSelectImage}>
              <Icon name="camera-alt" size={32} color="#1565C0" />
              <Text style={styles.addImageButtonText}>Add Photo</Text>
            </TouchableOpacity>
          )}
        </View>
      </ScrollView>

      {/* Submit Button */}
      <View style={styles.submitContainer}>
        <TouchableOpacity
          style={[styles.submitButton, isSubmitting && styles.submitButtonDisabled]}
          onPress={handleSubmit}
          disabled={isSubmitting}
        >
          <Text style={styles.submitButtonText}>
            {isSubmitting ? 'Creating Peep...' : 'Create Peep'}
          </Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  scrollView: {
    flex: 1,
  },
  section: {
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  selectedVenue: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F8F9FA',
    padding: 16,
    borderRadius: 12,
  },
  venueInfo: {
    flex: 1,
  },
  venueName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  venueAddress: {
    fontSize: 14,
    color: '#666',
    marginTop: 2,
  },
  overrideButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderWidth: 1,
    borderColor: '#1565C0',
    borderRadius: 6,
  },
  overrideButtonText: {
    color: '#1565C0',
    fontSize: 14,
    fontWeight: '600',
  },
  venueList: {
    maxHeight: 200,
  },
  venueOption: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
    marginBottom: 8,
  },
  venueOptionInfo: {
    flex: 1,
  },
  venueOptionName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  venueOptionAddress: {
    fontSize: 14,
    color: '#666',
    marginTop: 2,
  },
  slider: {
    width: '100%',
    height: 40,
  },
  sliderLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1565C0',
    textAlign: 'center',
    marginTop: 8,
  },
  sliderLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 8,
  },
  sliderLabelLeft: {
    fontSize: 12,
    color: '#666',
  },
  sliderLabelCenter: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1565C0',
  },
  sliderLabelRight: {
    fontSize: 12,
    color: '#666',
  },
  chipGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  chip: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    backgroundColor: '#ffffff',
  },
  chipSelected: {
    backgroundColor: '#1565C0',
    borderColor: '#1565C0',
  },
  chipText: {
    fontSize: 14,
    color: '#666',
  },
  chipTextSelected: {
    color: '#ffffff',
    fontWeight: '600',
  },
  segmentedControl: {
    flexDirection: 'row',
    borderWidth: 1,
    borderColor: '#1565C0',
    borderRadius: 8,
    overflow: 'hidden',
  },
  segmentButton: {
    flex: 1,
    paddingVertical: 12,
    alignItems: 'center',
    backgroundColor: '#ffffff',
    borderRightWidth: 1,
    borderRightColor: '#1565C0',
  },
  segmentButtonLeft: {
    borderTopLeftRadius: 8,
    borderBottomLeftRadius: 8,
  },
  segmentButtonRight: {
    borderTopRightRadius: 8,
    borderBottomRightRadius: 8,
    borderRightWidth: 0,
  },
  segmentButtonActive: {
    backgroundColor: '#1565C0',
  },
  segmentButtonText: {
    fontSize: 14,
    color: '#1565C0',
  },
  segmentButtonTextActive: {
    color: '#ffffff',
    fontWeight: '600',
  },
  descriptionInput: {
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    color: '#333',
    textAlignVertical: 'top',
    minHeight: 100,
  },
  characterCount: {
    fontSize: 12,
    color: '#999',
    textAlign: 'right',
    marginTop: 4,
  },
  imageContainer: {
    position: 'relative',
  },
  selectedImage: {
    width: '100%',
    height: 200,
    borderRadius: 12,
  },
  removeImageButton: {
    position: 'absolute',
    top: 8,
    right: 8,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    borderRadius: 15,
    width: 30,
    height: 30,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addImageButton: {
    borderWidth: 2,
    borderColor: '#1565C0',
    borderStyle: 'dashed',
    borderRadius: 12,
    padding: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addImageButtonText: {
    color: '#1565C0',
    fontSize: 16,
    fontWeight: '600',
    marginTop: 8,
  },
  submitContainer: {
    padding: 20,
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
    backgroundColor: '#ffffff',
  },
  submitButton: {
    backgroundColor: '#FFC107',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  submitButtonDisabled: {
    backgroundColor: '#B0B0B0',
  },
  submitButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
});
