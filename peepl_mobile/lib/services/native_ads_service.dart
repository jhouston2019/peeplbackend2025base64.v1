import 'package:cloud_firestore/cloud_firestore.dart';

class NativeAdsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getAdsForFeed({
    String? userLocation,
    int limit = 10,
  }) async {
    try {
      Query query = _firestore
          .collection('native_ads')
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: Timestamp.now());

      final snapshot = await query
          .orderBy('endDate')
          .orderBy('priority', descending: true)
          .limit(limit)
          .get();

      List<Map<String, dynamic>> ads = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        ads.add({'id': doc.id, ...data});
      }
      return ads;
    } catch (e) {
      print('Error fetching ads: $e');
      return [];
    }
  }
}