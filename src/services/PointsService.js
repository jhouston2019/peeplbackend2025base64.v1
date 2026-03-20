const admin = require('firebase-admin');

const POINTS_RULES = {
  PEEP_CREATED: 10,
  PIONEER_DISCOVERY: 50,
  LIKE_RECEIVED: 2,
  PEEP_WITH_PHOTO: 15,
  PEEP_FULLY_COMPLETE: 20,
};

async function awardPoints(userId, reason, amount) {
  const db = admin.firestore();
  const userRef = db.collection('users').doc(userId);
  const pointsLogRef = db.collection('points').doc();
  
  await db.runTransaction(async (transaction) => {
    transaction.update(userRef, {
      points: admin.firestore.FieldValue.increment(amount),
    });
    transaction.set(pointsLogRef, {
      userId,
      reason,
      amount,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

module.exports = { awardPoints, POINTS_RULES };
