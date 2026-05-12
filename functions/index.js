const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Callable: upload social post image. Only social workers (Firestore users/{uid}.role).
 * Server uploads to Storage so client never needs write permission.
 */
exports.uploadSocialPostImage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = context.auth.uid;
  const postId = data.postId;
  const imageBase64 = data.imageBase64;
  if (!postId || typeof postId !== "string" || !imageBase64 || typeof imageBase64 !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "postId and imageBase64 required.");
  }

  const userSnap = await admin.firestore().collection("users").doc(uid).get();
  const role = userSnap.exists && userSnap.data() && userSnap.data().role;
  if (role !== "socialWorker") {
    throw new functions.https.HttpsError("permission-denied", "Only social workers can upload post images.");
  }

  const buffer = Buffer.from(imageBase64, "base64");
  const path = `socialPosts/${postId}.jpg`;
  const bucket = admin.storage().bucket();
  const file = bucket.file(path);
  await file.save(buffer, { contentType: "image/jpeg", metadata: { cacheControl: "public, max-age=31536000" } });
  const [url] = await file.getSignedUrl({ action: "read", expires: "03-01-2500" });
  return { downloadURL: url };
});

/**
 * When a user document is created or updated in users/{userId}, set the same
 * role as a custom claim (optional; used if client upload is enabled).
 */
exports.syncUserRoleClaim = functions.firestore
  .document("users/{userId}")
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    const data = change.after.exists ? change.after.data() : null;
    const role = data && typeof data.role === "string" ? data.role : null;

    try {
      if (role) {
        await admin.auth().setCustomUserClaims(userId, { role });
        functions.logger.info("Set custom claim role=" + role + " for uid=" + userId);
      } else {
        await admin.auth().setCustomUserClaims(userId, { role: null });
        functions.logger.info("Cleared role claim for uid=" + userId);
      }
    } catch (err) {
      functions.logger.error("syncUserRoleClaim failed for " + userId, err);
      throw err;
    }
  });
