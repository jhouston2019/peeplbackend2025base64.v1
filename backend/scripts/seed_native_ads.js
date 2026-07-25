const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.resolve(__dirname, '../serviceAccountKey.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function seedNativeAds() {
  const batch = db.batch();

  const ads = [
    {
      id: 'test_ad_001',
      headline: 'Cotto — Gainesville',
      title: 'Cotto Restaurant',
      bodyText: 'Happy hour Mon–Fri 4–7pm. Half-price wine & apps.',
      body: 'Happy hour Mon–Fri 4–7pm.',
      subtitle: 'Half-price wine & apps.',
      imageUrl: 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&q=80',
      destinationUrl: 'https://example.com/cotto',
      isActive: true,
      endDate: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
      priority: 3,
      targetLocations: ['Gainesville', 'Atlanta', 'Hall County'],
      adContext: 'feed',
      impressions: 0,
      clicks: 0,
    },
    {
      id: 'test_ad_002',
      headline: 'NaiThai Dunwoody',
      title: 'NaiThai Restaurant',
      bodyText: 'Free appetizer with 2 entrees — this week only.',
      body: 'Free appetizer with 2 entrees.',
      subtitle: 'This week only.',
      imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&q=80',
      destinationUrl: 'https://example.com/naithai',
      isActive: true,
      endDate: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
      priority: 2,
      targetLocations: ['Dunwoody', 'Atlanta', 'Sandy Springs'],
      adContext: 'feed',
      impressions: 0,
      clicks: 0,
    },
    {
      id: 'test_ad_003',
      headline: '3 Deals Near You',
      title: 'Local Deals',
      bodyText: 'Restaurants and bars near you are offering deals right now.',
      body: 'Deals happening near you right now.',
      subtitle: 'Tap to explore.',
      imageUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800&q=80',
      destinationUrl: 'https://example.com/deals',
      isActive: true,
      endDate: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
      priority: 1,
      targetLocations: ['Gainesville', 'Atlanta', 'Dunwoody', 'Brookhaven'],
      adContext: 'feed',
      impressions: 0,
      clicks: 0,
    },
  ];

  for (const ad of ads) {
    const ref = db.collection('native_ads').doc(ad.id);
    batch.set(ref, ad);
    console.log(`Queued: ${ad.id} — ${ad.headline}`);
  }

  await batch.commit();
  console.log('\n✅ Batch committed. Verifying...\n');

  // Verification read-back
  for (const ad of ads) {
    const doc = await db.collection('native_ads').doc(ad.id).get();
    if (doc.exists) {
      const d = doc.data();
      console.log(`✅ ${ad.id}: isActive=${d.isActive}, endDate=${d.endDate.toDate().toISOString()}`);
    } else {
      console.error(`❌ ${ad.id}: NOT FOUND after commit`);
      process.exit(1);
    }
  }

  console.log('\n✅ All 3 native_ads documents verified.\n');
  process.exit(0);
}

seedNativeAds().catch((err) => {
  console.error('❌ Seed failed:', err);
  process.exit(1);
});
