const functions = require("firebase-functions/v2"); // v2 API
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

exports.sendActivityNotifications = onSchedule("every 1 minutes", async () => {
  const now = admin.firestore.Timestamp.now();

  console.log(`⏰ Checking for activities to notify at ${now.toDate().toISOString()}`);

  let snapshot;
  try {
    snapshot = await db.collection("timetables")
      .where("notified", "==", false)
      .where("startTime", "<=", now)
      .get();
  } catch (err) {
    console.error("🔥 Firestore query failed. Likely missing index.", err);
    return;
  }

  if (snapshot.empty) {
    console.log("✅ No pending notifications at this time.");
    return;
  }

  const batch = db.batch();
  const tasks = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const userId = data.uid;

    tasks.push(
      (async () => {
        try {
          const userDoc = await db.collection("users").doc(userId).get();
          const user = userDoc.data();

          if (!user || !user.fcmToken) {
            console.warn(`⚠️ No FCM token for user ${userId}`);
            return;
          }

          const message = {
            token: user.fcmToken,
            notification: {
              title: "Activity Reminder",
              body: `Your activity "${data.work}" is starting now.`,
            },
            data: {
              activityId: doc.id,
            },
          };

          await messaging.send(message);
          console.log(`✅ Notification sent to ${userId} for activity ${doc.id}`);

          // mark as notified
          batch.update(doc.ref, { notified: true });
        } catch (err) {
          console.error(`❌ Failed processing user ${userId}:`, err);
        }
      })()
    );
  }

  await Promise.all(tasks);
  await batch.commit();

  console.log("🎉 All notifications sent & marked as notified.");
});
