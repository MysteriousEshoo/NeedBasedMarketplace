/**
 * 📡 FCM Push Notification Cloud Function
 *
 * Triggered every time a new notification entry is CREATED at the path:
 *   notifications/{userId}/{notificationId}
 *
 * The function:
 * 1. Reads the notification data (title, body, type, data).
 * 2. Looks up the target user's FCM device tokens from fcm_tokens/{userId}/.
 * 3. Sends an FCM multicast message to ALL of the user's devices.
 *
 * Deploy:
 *   firebase deploy --only functions
 *
 * Requirements:
 *   - Firebase Blaze plan (or higher) for outbound network to FCM.
 *   - Node.js 18+ runtime.
 *   - "firebase-admin" and "firebase-functions" npm packages installed.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.database();

// ──────────────────────────────────────────────────────────────────────
// Helper: parse notification data payload for deep linking
// ──────────────────────────────────────────────────────────────────────

/**
 * Extracts structured fields from the notification's `data` string.
 * The app stores data in two formats depending on the notification type:
 *
 * 1. **Offer notifications** — pipe-delimited string:
 *    `offer_received|offerId|needId|needTitle|userId|userName|deliveryTime|price`
 *
 * 2. **Message notifications** — JSON-encoded string:
 *    `{"action":"chat_message","needId":"...","needTitle":"...","otherUserId":"...","otherUserName":"..."}`
 *
 * 3. **Seller need-match** — just a needId string.
 */
function parseDataField(rawData) {
  if (!rawData || rawData.trim().length === 0) {
    return {};
  }

  const trimmed = rawData.trim();

  // Try JSON parsing first (message notifications).
  if (trimmed.startsWith("{")) {
    try {
      const json = JSON.parse(trimmed);
      return {
        needId: json.needId || "",
        needTitle: json.needTitle || "",
        otherUserId: json.otherUserId || "",
        otherUserName: json.otherUserName || "",
        offerId: json.offerId || "",
      };
    } catch (_) {
      // Not valid JSON — fall through to pipe-delimited parsing.
    }
  }

  // Try pipe-delimited parsing (offer notifications).
  if (trimmed.includes("|")) {
    const parts = trimmed.split("|");
    return {
      needId: parts[2] || "",
      needTitle: parts[3] || "",
      otherUserId: parts[4] || "",
      otherUserName: parts[5] || "",
      offerId: parts[1] || "",
    };
  }

  // Plain string — treat as needId (need_match notifications).
  return {
    needId: trimmed,
    needTitle: "",
    otherUserId: "",
    otherUserName: "",
    offerId: "",
  };
}

function buildDataPayload(snapshotData) {
  const rawData = snapshotData.data || "";
  const parsed = parseDataField(rawData);

  return {
    type: snapshotData.type || "system",
    title: snapshotData.title || "",
    body: snapshotData.body || "",
    audience: snapshotData.audience || "",
    data: rawData,
    needId: parsed.needId || "",
    needTitle:
      parsed.needTitle || snapshotData.title || "Need",
    otherUserId: parsed.otherUserId || "",
    otherUserName: parsed.otherUserName || "",
    offerId: parsed.offerId || "",
  };
}

// ──────────────────────────────────────────────────────────────────────
// Main function: triggered on new notification writes
// ──────────────────────────────────────────────────────────────────────

exports.sendPushNotification = functions.database
  .ref("/notifications/{userId}/{notificationId}")
  .onCreate(async (snapshot, context) => {
    const { userId, notificationId } = context.params;
    const data = snapshot.val();

    if (!data) {
      functions.logger.log(
        `[FCM] Skipping empty notification ${notificationId} for user ${userId}`
      );
      return null;
    }

    const title = data.title || "";
    const body = data.body || "";
    if (!title && !body) {
      functions.logger.log(
        `[FCM] Skipping notification ${notificationId}: both title and body are empty`
      );
      return null;
    }

    // ── Look up the target user's FCM tokens ─────────────────────────
    let tokensSnapshot;
    try {
      tokensSnapshot = await db.ref(`fcm_tokens/${userId}`).get();
    } catch (err) {
      functions.logger.error(
        `[FCM] Failed to read tokens for user ${userId}:`,
        err
      );
      return null;
    }

    if (!tokensSnapshot.exists()) {
      functions.logger.log(
        `[FCM] No FCM tokens found for user ${userId} — skipping push`
      );
      return null;
    }

    const tokensData = tokensSnapshot.val();
    const tokens = Object.values(tokensData)
      .map((entry) => (entry.token ? entry.token : null))
      .filter(Boolean);

    if (tokens.length === 0) {
      functions.logger.log(
        `[FCM] No valid tokens for user ${userId} — skipping push`
      );
      return null;
    }

    functions.logger.log(
      `[FCM] Sending push to ${tokens.length} device(s) for user ${userId}`
    );

    // ── Build the FCM payload ────────────────────────────────────────
    const dataPayload = buildDataPayload(data);

    const message = {
      tokens,
      notification: {
        title,
        body,
      },
      // Data payload enables deep linking when the notification is tapped.
      data: dataPayload,
      android: {
        priority: "high",
        notification: {
          channelId: "needhub_alerts",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    // ── Send multicast ───────────────────────────────────────────────
    try {
      const response = await admin.messaging().sendEachForMulticast(message);

      functions.logger.log(
        `[FCM] Successfully sent ${response.successCount} / ${tokens.length} messages`
      );

      // Clean up invalid tokens.
      if (response.failureCount > 0) {
        const tokenEntries = Object.entries(tokensData);
        const invalidIndices = new Set();
        response.responses.forEach((resp, idx) => {
          if (
            !resp.success &&
            (resp.error.code === "messaging/invalid-registration-token" ||
              resp.error.code === "messaging/registration-token-not-registered")
          ) {
            invalidIndices.add(idx);
          }
        });

        if (invalidIndices.size > 0) {
          const tokensRef = db.ref(`fcm_tokens/${userId}`);
          tokenEntries.forEach(([key, _entry], idx) => {
            if (invalidIndices.has(idx)) {
              tokensRef.child(key).remove();
            }
          });
          functions.logger.log(
            `[FCM] Cleaned up ${invalidIndices.size} invalid token(s)`
          );
        }
      }

      return response;
    } catch (err) {
      functions.logger.error(`[FCM] Multicast send failed:`, err);
      return null;
    }
  });
