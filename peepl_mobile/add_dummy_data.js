const { initializeApp } = require('firebase/app');
const { getFirestore, collection, addDoc, Timestamp } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: "AIzaSyD1cbXZCQS_Bcu7kmJOcHlUZm4TxLKucJA",
  authDomain: "crowd-checker-7bd94.firebaseapp.com",
  projectId: "crowd-checker-7bd94",
  storageBucket: "crowd-checker-7bd94.firebasestorage.app",
  messagingSenderId: "651814138260",
  appId: "1:651814138260:web:ee88fe618dd5d409f8df81"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

const posts = [
  { locationName: 'Central Park', username: 'sarah_nyc', crowdingLevel: 8, imageUrl: 'https://images.unsplash.com/photo-1568515387631-8b650bbcdb90?w=800', description: 'Cozy • No wait • Noise: 3/10 • Locals • Staff: 8/10', latitude: 40.7829, longitude: -73.9654, likesCount: 12, commentsCount: 3, isVerified: false, userId: 'dummy1' },
  { locationName: 'Times Square', username: 'mike_manhattan', crowdingLevel: 10, imageUrl: 'https://images.unsplash.com/photo-1534430480872-3498386e7856?w=800', description: 'Trendy • 30m+ • Noise: 9/10 • Tourists • Staff: 5/10', latitude: 40.7580, longitude: -73.9855, likesCount: 34, commentsCount: 8, isVerified: false, userId: 'dummy2' },
  { locationName: 'Brooklyn Bridge', username: 'jen_brooklyn', crowdingLevel: 6, imageUrl: 'https://images.unsplash.com/photo-1549982429-f6a2571a9a5b?w=800', description: 'Casual • 5-10m • Noise: 5/10 • Mixed • Staff: 7/10', latitude: 40.7061, longitude: -73.9969, likesCount: 28, commentsCount: 5, isVerified: false, userId: 'dummy3' },
  { locationName: 'High Line Park', username: 'alex_chelsea', crowdingLevel: 4, imageUrl: 'https://images.unsplash.com/photo-1467269204594-9661b134dd2b?w=800', description: 'Upscale • No wait • Noise: 2/10 • Young • Staff: 9/10', latitude: 40.7480, longitude: -74.0048, likesCount: 19, commentsCount: 2, isVerified: false, userId: 'dummy4' },
  { locationName: 'Madison Square Garden', username: 'tom_midtown', crowdingLevel: 9, imageUrl: 'https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?w=800', description: 'Trendy • 30m+ • Noise: 10/10 • Mixed • Staff: 6/10', latitude: 40.7505, longitude: -73.9934, likesCount: 45, commentsCount: 11, isVerified: false, userId: 'dummy5' },
  { locationName: 'Rockefeller Center', username: 'lisa_uptown', crowdingLevel: 7, imageUrl: 'https://images.unsplash.com/photo-1534430480872-3498386e7856?w=800', description: 'Upscale • 15-20m • Noise: 6/10 • Tourists • Staff: 8/10', latitude: 40.7587, longitude: -73.9787, likesCount: 22, commentsCount: 4, isVerified: false, userId: 'dummy6' },
  { locationName: 'DUMBO Brooklyn', username: 'chris_dumbo', crowdingLevel: 5, imageUrl: 'https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800', description: 'Trendy • No wait • Noise: 4/10 • Young • Staff: 7/10', latitude: 40.7033, longitude: -73.9881, likesCount: 31, commentsCount: 6, isVerified: false, userId: 'dummy7' },
  { locationName: 'Chelsea Market', username: 'emma_chelsea', crowdingLevel: 6, imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800', description: 'Casual • 5-10m • Noise: 5/10 • Mixed • Has deals • Staff: 8/10', latitude: 40.7424, longitude: -74.0060, likesCount: 17, commentsCount: 3, isVerified: false, userId: 'dummy8' },
  { locationName: 'Bryant Park', username: 'ryan_midtown', crowdingLevel: 3, imageUrl: 'https://images.unsplash.com/photo-1575978122836-7a82b8776375?w=800', description: 'Cozy • No wait • Noise: 2/10 • Business • Staff: 9/10', latitude: 40.7536, longitude: -73.9832, likesCount: 9, commentsCount: 1, isVerified: false, userId: 'dummy9' },
  { locationName: 'Coney Island Beach', username: 'maya_brooklyn', crowdingLevel: 7, imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800', description: 'Family-friendly • No wait • Noise: 7/10 • Families • Staff: 5/10', latitude: 40.5749, longitude: -73.9857, likesCount: 38, commentsCount: 9, isVerified: false, userId: 'dummy10' },
];

async function addPosts() {
  for (const post of posts) {
    await addDoc(collection(db, 'location_posts'), {
      ...post,
      timestamp: Timestamp.now(),
    });
    console.log('Added: ' + post.locationName);
  }
  console.log('All done!');
}

addPosts();