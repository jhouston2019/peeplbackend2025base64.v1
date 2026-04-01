import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int maxFileSizeBytes = 5 * 1024 * 1024;
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

  Stream<QuerySnapshot> getLocationFeedStream() {
    return _firestore
        .collection('location_posts')
        .where('imageUrl', isNotEqualTo: '')
        .orderBy('imageUrl')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> addLocationPost({
    required String userId,
    required String username,
    required String locationName,
    required double latitude,
    required double longitude,
    required int crowdingLevel,
    required File imageFile,
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
  }) async {
    try {
      await _validateImageFile(imageFile);
      final imageUrl = await _uploadImage(imageFile, userId);

      final doc = <String, dynamic>{
        'userId': userId,
        'username': username,
        'locationName': locationName,
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

      await _firestore.collection('location_posts').add(doc);
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
  }

  Future<void> unlikeLocationPost(String postId, String userId) async {
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
}