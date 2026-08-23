import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/milestone.dart';
import 'crowd_intelligence_service.dart';
import 'growth_analytics_service.dart';
import 'notification_service.dart';
import 'venue_name_service.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String usersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

  static const int maxFileSizeBytes = 5 * 1024 * 1024;
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

  static String followDocumentId(String userId, String locationId) =>
      '${userId}_$locationId';

  Future<void> followLocation(
    String userId,
    String locationId,
    String locationName,
  ) async {
    try {
      final docId = followDocumentId(userId, locationId);
      await _firestore.collection('location_follows').doc(docId).set({
        'userId': userId,
        'locationId': locationId,
        'locationName': locationName,
        'followedAt': FieldValue.serverTimestamp(),
        'alertsEnabled': true,
        'lastAlertedAt': null,
        'lastKnownCrowdingLevel': null,
      });

      await GrowthAnalyticsService.logEvent(
        'growth_location_followed',
        {
          'userId': userId,
          'locationId': locationId,
          'locationName': locationName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[FeedService] followLocation error: $e');
      rethrow;
    }
  }

  Future<void> unfollowLocation(String userId, String locationId) async {
    try {
      final docId = followDocumentId(userId, locationId);
      final doc = await _firestore.collection('location_follows').doc(docId).get();
      final locationName = doc.data()?['locationName'] as String? ?? locationId;

      await _firestore.collection('location_follows').doc(docId).delete();

      await GrowthAnalyticsService.logEvent(
        'growth_location_unfollowed',
        {
          'userId': userId,
          'locationId': locationId,
          'locationName': locationName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[FeedService] unfollowLocation error: $e');
      rethrow;
    }
  }

  Future<bool> isLocationFollowed(String userId, String locationId) async {
    try {
      final doc = await _firestore
          .collection('location_follows')
          .doc(followDocumentId(userId, locationId))
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Stream<QuerySnapshot> getLocationFeedStream() {
    return _firestore
        .collection('location_posts')
        .where('imageUrl', isNotEqualTo: '')
        .orderBy('imageUrl')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .handleError((Object e) {
      debugPrint('[FeedService] getLocationFeedStream error: $e');
    });
  }

  Future<String> addLocationPost({
    required String userId,
    required String username,
    required String locationName,
    required double latitude,
    required double longitude,
    required int crowdingLevel,
    required File imageFile,
    String? description,
    String? vibe,
    String? waitTime,
    int? noiseLevel,
    bool hasMusic = false,
    String? demographics,
    String? dressCode,
    bool wheelchairAccessible = false,
    bool strollerFriendly = false,
    bool hasDeals = false,
    int? staffAvailability,
    int maleFemaleRatio = 50,
    int adultKidRatio = 50,
    String? ageRange,
    bool hasPets = false,
    String? venueType,
    int? aiEstimatedScore,
    bool? aiValidationPassed,
    double? aiValidationConfidence,
    String? aiDescription,
    String? crowdsourceRequestId,
    bool preserveLocationName = false,
  }) async {
    try {
      await _validateImageFile(imageFile);
      final imageUrl = await _uploadImage(imageFile, userId);

      var displayName = locationName.trim();
      String? streetAddress;

      final hasCoords = !(latitude == 0 && longitude == 0) &&
          !latitude.isNaN &&
          !longitude.isNaN;

      if (!hasCoords) {
        throw StateError('Cannot post without a GPS location');
      }

      if (preserveLocationName) {
        if (displayName.isEmpty) {
          displayName =
              await VenueNameService.resolveLabelAtPin(latitude, longitude);
        }
      } else if (VenueNameService.isWeakVenueName(displayName)) {
        displayName =
            await VenueNameService.resolveLabelAtPin(latitude, longitude);
        if (VenueNameService.looksLikeAddress(displayName)) {
          streetAddress = displayName;
        }
      } else if (VenueNameService.looksLikeAddress(displayName)) {
        streetAddress = displayName;
        final resolved =
            await VenueNameService.resolveVenueName(latitude, longitude);
        if (resolved != null && resolved.isNotEmpty) {
          displayName = resolved;
        }
      }

      final doc = <String, dynamic>{
        'userId': userId,
        'username': username,
        'locationName': displayName,
        'latitude': latitude,
        'longitude': longitude,
        'crowdingLevel': crowdingLevel,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'isVerified': false,
        'hasMusic': hasMusic,
        'wheelchairAccessible': wheelchairAccessible,
        'strollerFriendly': strollerFriendly,
        'hasDeals': hasDeals,
        'maleFemaleRatio': maleFemaleRatio.clamp(0, 100),
        'adultKidRatio': adultKidRatio.clamp(0, 100),
        'hasPets': hasPets,
      };
      if (streetAddress != null && streetAddress != displayName) {
        doc['address'] = streetAddress;
      }
      if (!VenueNameService.isWeakVenueName(displayName)) {
        doc['venueName'] = displayName;
      }
      final desc = description?.trim();
      if (desc != null && desc.isNotEmpty) doc['description'] = desc;
      final vt = venueType?.trim();
      if (vt != null && vt.isNotEmpty) doc['venueType'] = vt;
      final ar = ageRange?.trim();
      if (ar != null && ar.isNotEmpty) doc['ageRange'] = ar;
      final v = vibe?.trim();
      if (v != null && v.isNotEmpty) doc['vibe'] = v;
      final w = waitTime?.trim();
      if (w != null && w.isNotEmpty) doc['waitTime'] = w;
      if (noiseLevel != null) doc['noiseLevel'] = noiseLevel;
      final d = demographics?.trim();
      if (d != null && d.isNotEmpty) doc['demographics'] = d;
      final dress = dressCode?.trim();
      if (dress != null && dress.isNotEmpty) doc['dressCode'] = dress;
      if (staffAvailability != null) {
        doc['staffAvailability'] = staffAvailability;
      }

      final docRef = await _firestore.collection('location_posts').add(doc);

      // Fire-and-forget intelligence recording — never blocks post flow
      CrowdIntelligenceService().recordPostIntelligence(
        postId: docRef.id,
        locationName: displayName,
        latitude: latitude,
        longitude: longitude,
        crowdScore: crowdingLevel,
        userId: userId,
        aiEstimatedScore: aiEstimatedScore,
        aiValidationPassed: aiValidationPassed,
        aiValidationConfidence: aiValidationConfidence,
        aiDescription: aiDescription,
      );

      // Ensures every post path (Quick Peep, /post, /create_peep) triggers
      // notification_triggers, lastLocation, presence, and server fulfillment.
      await NotificationService.instance.onPostSubmitted(
        postId: docRef.id,
        userId: userId,
        username: username,
        locationName: displayName,
        latitude: latitude,
        longitude: longitude,
        crowdingLevel: crowdingLevel,
        crowdsourceRequestId: crowdsourceRequestId,
      );

      unawaited(
        NotificationService.instance
            .handlePostSubmission(
              userId: userId,
              locationName: displayName,
            )
            .catchError((_) {}),
      );

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create location post: ${e.toString()}');
    }
  }

  Future<String> _uploadImage(File imageFile, String userId) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref('location_images/$userId/$fileName');
    final uploadTask = ref.putFile(imageFile);
    final snapshot = await uploadTask.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _validateImageFile(File imageFile) async {
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist');
    }
    final fileSize = await imageFile.length();
    if (fileSize > maxFileSizeBytes) {
      throw Exception('Image file size cannot exceed 5MB');
    }
    final ext = imageFile.path.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw Exception('Unsupported image format');
    }
  }

  Future<void> likeLocationPost(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('location_posts').doc(postId);
      final likeRef = postRef.collection('likes').doc(userId);
      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(likeRef);
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) throw Exception('Post not found');
        if (!likeDoc.exists) {
          transaction.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
          transaction.update(postRef, {'likesCount': FieldValue.increment(1)});
        }
      });
    } catch (e) {
      debugPrint('[FeedService] likeLocationPost error: $e');
      rethrow;
    }
  }

  Future<void> unlikeLocationPost(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('location_posts').doc(postId);
      final likeRef = postRef.collection('likes').doc(userId);
      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(likeRef);
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) throw Exception('Post not found');
        if (likeDoc.exists) {
          transaction.delete(likeRef);
          transaction.update(postRef, {'likesCount': FieldValue.increment(-1)});
        }
      });
    } catch (e) {
      debugPrint('[FeedService] unlikeLocationPost error: $e');
      rethrow;
    }
  }

  Future<bool> isLocationPostLiked(String postId, String userId) async {
    try {
      final likeDoc = await _firestore
          .collection('location_posts')
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .get();
      return likeDoc.exists;
    } catch (e) {
      return false;
    }
  }

  static String locationIdFromName(String locationName) {
    final normalized =
        locationName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return normalized.length > 100 ? normalized.substring(0, 100) : normalized;
  }

  static bool isPostOwner(Map<String, dynamic> post, String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return post['userId'] == userId;
  }

  Future<void> deleteLocationPost(String postId) async {
    try {
      final postRef = _firestore.collection('location_posts').doc(postId);
      final postDoc = await postRef.get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }
      final data = postDoc.data()!;

      await _deleteSubcollection(postRef.collection('likes'));
      await _deleteSubcollection(postRef.collection('comments'));

      final imageUrl = data['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(imageUrl).delete();
        } catch (_) {
          // Best-effort storage cleanup; do not block post removal.
        }
      }

      final locationName = data['locationName'] as String?;
      if (locationName != null && locationName.trim().isNotEmpty) {
        final locationId = locationIdFromName(locationName.trim());
        if (locationId.isNotEmpty) {
          try {
            final locRef = _firestore.collection('locations').doc(locationId);
            await _firestore.runTransaction((transaction) async {
              final locDoc = await transaction.get(locRef);
              if (!locDoc.exists) return;
              final count = (locDoc.data()?['peepCount'] as num?)?.toInt() ?? 0;
              if (count > 1) {
                transaction.update(locRef, {'peepCount': FieldValue.increment(-1)});
              } else if (count == 1) {
                transaction.update(locRef, {'peepCount': 0});
              }
            });
          } catch (_) {
            // Best-effort location count cleanup.
          }
        }
      }

      await postRef.delete();
    } catch (e) {
      debugPrint('[FeedService] deleteLocationPost error: $e');
      rethrow;
    }
  }

  Future<void> _deleteSubcollection(CollectionReference<Map<String, dynamic>> col) async {
    try {
      const batchSize = 200;
      while (true) {
        final snap = await col.limit(batchSize).get();
        if (snap.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[FeedService] _deleteSubcollection error: $e');
      rethrow;
    }
  }

  /// Aggregates [location_posts] by [locationName] (same query as VenueListScreen).
  Future<List<VenueSummary>> fetchVenueSummaries({int limit = 2000}) async {
    try {
      final snap = await _firestore
          .collection('location_posts')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final byName = <String, VenueSummary>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = data['locationName'] as String? ?? '';
        if (name.isEmpty) continue;

        final existing = byName[name];
        if (existing == null) {
          byName[name] = VenueSummary.fromPost(name, data, 1);
        } else {
          byName[name] = existing.copyWith(postCount: existing.postCount + 1);
        }
      }

      final list = byName.values.toList()
        ..sort((a, b) => b.lastPosted.compareTo(a.lastPosted));
      return list;
    } catch (e) {
      debugPrint('[FeedService] fetchVenueSummaries error: $e');
      return [];
    }
  }

  /// Contribution stats for My Peepl (Phase 2).
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final snap = await _firestore
          .collection('location_posts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      var totalLikes = 0;
      final places = <String>{};
      Timestamp? firstPeepDate;
      final recentPeeps = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        totalLikes += (data['likesCount'] as num?)?.toInt() ?? 0;

        final name = data['locationName'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          places.add(name.trim());
        }

        final ts = data['timestamp'];
        if (ts is Timestamp) {
          if (firstPeepDate == null || ts.compareTo(firstPeepDate!) < 0) {
            firstPeepDate = ts;
          }
        }

        if (recentPeeps.length < 5) {
          recentPeeps.add({
            'locationName': data['locationName'] as String? ?? '',
            'crowdingLevel': (data['crowdingLevel'] as num?)?.toInt() ?? 0,
            'timestamp': data['timestamp'],
            'likesCount': (data['likesCount'] as num?)?.toInt() ?? 0,
          });
        }
      }

      if (firstPeepDate == null && snap.docs.isNotEmpty) {
        for (final doc in snap.docs.reversed) {
          final ts = doc.data()['timestamp'];
          if (ts is Timestamp) {
            firstPeepDate = ts;
            break;
          }
        }
      }

      return {
        'totalPeeps': snap.docs.length,
        'totalPlaces': places.length,
        'totalLikes': totalLikes,
        'firstPeepDate': firstPeepDate,
        'recentPeeps': recentPeeps,
      };
    } catch (e) {
      debugPrint('[FeedService] getUserStats error: $e');
      return {
        'totalPeeps': 0,
        'totalPlaces': 0,
        'totalLikes': 0,
        'firstPeepDate': null,
        'recentPeeps': <Map<String, dynamic>>[],
      };
    }
  }

  /// Distinct users who posted at [locationName] within [window] (Phase 3).
  Future<int> getVenueContributorCount(
    String locationName, [
    Duration window = const Duration(hours: 24),
  ]) async {
    if (locationName.trim().isEmpty) return 0;

    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(window));
      final snap = await _firestore
          .collection('location_posts')
          .where('locationName', isEqualTo: locationName)
          .where('timestamp', isGreaterThan: cutoff)
          .get();

      final userIds = <String>{};
      for (final doc in snap.docs) {
        final uid = doc.data()['userId'] as String?;
        if (uid != null && uid.isNotEmpty) userIds.add(uid);
      }
      return userIds.length;
    } catch (e) {
      debugPrint('[FeedService] getVenueContributorCount error: $e');
      return 0;
    }
  }

  /// Returns newly earned milestone IDs and persists them on the user doc (Phase 4).
  Future<List<String>> checkMilestones(String userId) async {
    try {
      final stats = await getUserStats(userId);
      final totalPeeps = stats['totalPeeps'] as int? ?? 0;
      final totalPlaces = stats['totalPlaces'] as int? ?? 0;

      final userRef = _firestore.collection(usersCollection).doc(userId);
      final userSnap = await userRef.get();
      final earned = List<String>.from(
        (userSnap.data()?['earnedMilestones'] as List<dynamic>? ?? [])
            .map((e) => e.toString()),
      );

      final newlyEarned = <String>[];

      void tryEarn(String id, bool condition) {
        if (condition && !earned.contains(id) && !newlyEarned.contains(id)) {
          newlyEarned.add(id);
        }
      }

      tryEarn(Milestone.firstPeep, totalPeeps >= 1);
      tryEarn(Milestone.fivePlaces, totalPlaces >= 5);
      tryEarn(Milestone.tenPeeps, totalPeeps >= 10);
      tryEarn(Milestone.twentyFivePeeps, totalPeeps >= 25);

      if (!earned.contains(Milestone.pioneer) &&
          !newlyEarned.contains(Milestone.pioneer)) {
        final recentSnap = await _firestore
            .collection('location_posts')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (recentSnap.docs.isNotEmpty) {
          final locationName =
              recentSnap.docs.first.data()['locationName'] as String? ?? '';
          if (locationName.isNotEmpty) {
            final firstSnap = await _firestore
                .collection('location_posts')
                .where('locationName', isEqualTo: locationName)
                .orderBy('timestamp', descending: false)
                .limit(1)
                .get();

            if (firstSnap.docs.isNotEmpty &&
                firstSnap.docs.first.data()['userId'] == userId) {
              newlyEarned.add(Milestone.pioneer);
            }
          }
        }
      }

      if (newlyEarned.isNotEmpty) {
        await userRef.set(
          {'earnedMilestones': FieldValue.arrayUnion(newlyEarned)},
          SetOptions(merge: true),
        );
      }

      return newlyEarned;
    } catch (e) {
      debugPrint('[FeedService] checkMilestones error: $e');
      return [];
    }
  }

  /// Stats for the current calendar week (Monday through now).
  Future<Map<String, dynamic>> getWeeklyRecap(String userId) async {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _recapForRange(userId, weekStart, now);
  }

  /// Stats for the current calendar month.
  Future<Map<String, dynamic>> getMonthlyRecap(String userId) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return _recapForRange(userId, monthStart, now);
  }

  Future<Map<String, dynamic>> _recapForRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snap = await _firestore
          .collection('location_posts')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .get();

      var peepCount = 0;
      var impactCount = 0;
      final places = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['timestamp'];
        if (ts is Timestamp && ts.toDate().isAfter(end)) continue;

        peepCount++;
        impactCount += (data['helpedCount'] as num?)?.toInt() ?? 0;

        final name = data['locationName'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          places.add(name.trim());
        }
      }

      return {
        'peepCount': peepCount,
        'placeCount': places.length,
        'impactCount': impactCount,
      };
    } catch (e) {
      debugPrint('[FeedService] _recapForRange error: $e');
      return {
        'peepCount': 0,
        'placeCount': 0,
        'impactCount': 0,
      };
    }
  }

  /// Increment [helpedCount] when another user views a Peep (Phase 5).
  Future<void> recordPeepView(String postId, String viewerUserId) async {
    try {
      if (postId.isEmpty || viewerUserId.isEmpty) return;

      final postRef = _firestore.collection('location_posts').doc(postId);
      final postSnap = await postRef.get();
      if (!postSnap.exists) return;

      final authorId = postSnap.data()?['userId'] as String?;
      if (authorId == null || authorId == viewerUserId) return;

      await postRef.update({'helpedCount': FieldValue.increment(1)});
    } catch (_) {}
  }
}

/// Venue row aggregated from location_posts (shared with venue list / compare).
class VenueSummary {
  final String locationName;
  final String? venueType;
  final int currentCrowd;
  final int postCount;
  final DateTime lastPosted;
  final double? latitude;
  final double? longitude;

  const VenueSummary({
    required this.locationName,
    required this.venueType,
    required this.currentCrowd,
    required this.postCount,
    required this.lastPosted,
    required this.latitude,
    required this.longitude,
  });

  factory VenueSummary.fromPost(
    String name,
    Map<String, dynamic> data,
    int count,
  ) {
    DateTime lastPosted = DateTime.fromMillisecondsSinceEpoch(0);
    final ts = data['timestamp'];
    if (ts is Timestamp) {
      lastPosted = ts.toDate();
    } else if (ts is DateTime) {
      lastPosted = ts;
    }

    return VenueSummary(
      locationName: name,
      venueType: data['venueType'] as String?,
      currentCrowd: (data['crowdingLevel'] as num?)?.toInt() ?? 0,
      postCount: count,
      lastPosted: lastPosted,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  VenueSummary copyWith({int? postCount}) {
    return VenueSummary(
      locationName: locationName,
      venueType: venueType,
      currentCrowd: currentCrowd,
      postCount: postCount ?? this.postCount,
      lastPosted: lastPosted,
      latitude: latitude,
      longitude: longitude,
    );
  }
}