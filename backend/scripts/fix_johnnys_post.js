const admin = require('firebase-admin');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function fixJohnnysPost() {
  await db.collection('location_posts').doc('eEmx7qTKFgeiW8uUT7Ea').update({
    locationName: "Johnny's New York Style Pizza",
    venueName: "Johnny's New York Style Pizza",
    address: '114 Jesse Jewell Pkwy SE, Gainesville',
  });
  console.log("Updated Noodle Bowl post → Johnny's New York Style Pizza");
  process.exit(0);
}

fixJohnnysPost().catch((err) => {
  console.error(err);
  process.exit(1);
});
