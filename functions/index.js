const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

// ---- Gmail config (stockée via firebase functions:config:set ...)
const gmailEmail = functions.config().gmail?.email;
const gmailPass = functions.config().gmail?.pass;

if (!gmailEmail || !gmailPass) {
  console.warn(
    "Gmail config missing. Run:\n" +
      'firebase functions:config:set gmail.email="..." gmail.pass="..."'
  );
}

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: { user: gmailEmail, pass: gmailPass },
});

// ---- Helpers
function normalizeEmails(list) {
  if (!Array.isArray(list)) return [];
  const cleaned = list
    .map((x) => String(x || "").trim().toLowerCase())
    .filter((x) => x.includes("@"));
  // dedupe
  return [...new Set(cleaned)];
}

async function resolveRecipients(templateId) {
  // 1) read template recipientEmails
  try {
    const tplSnap = await db.collection("check_templates").doc(templateId).get();
    const tpl = tplSnap.exists ? tplSnap.data() : null;

    const tplEmails = normalizeEmails(tpl?.recipientEmails);
    if (tplEmails.length) return tplEmails;
  } catch (e) {
    console.warn("resolveRecipients tpl read failed:", e);
  }

  // 2) fallback settings/email.defaultRecipients
  try {
    const settingsSnap = await db.collection("settings").doc("email").get();
    const settings = settingsSnap.exists ? settingsSnap.data() : null;

    const defaults = normalizeEmails(settings?.defaultRecipients);
    return defaults;
  } catch (e) {
    console.warn("resolveRecipients settings read failed:", e);
  }

  return [];
}

function formatAnswers(answers) {
  // answers can contain strings / numbers / booleans / arrays / objects (grid)
  const lines = [];
  if (!answers || typeof answers !== "object") return "Aucune réponse.";

  for (const [key, value] of Object.entries(answers)) {
    let vStr = "";
    if (value === null || value === undefined) vStr = "";
    else if (Array.isArray(value)) vStr = value.join(", ");
    else if (typeof value === "object") {
      // grid-like object
      const inner = [];
      for (const [rk, rv] of Object.entries(value)) {
        inner.push(`- ${rk}: ${rv}`);
      }
      vStr = inner.join("\n");
    } else vStr = String(value);

    lines.push(`${key}:\n${vStr}\n`);
  }

  return lines.join("\n");
}

// ---- Trigger: when a submission is created
exports.onCheckSubmissionCreate = functions
  .region("europe-west1")
  .firestore.document("check_submissions/{docId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const docRef = snap.ref;

    // Safety: avoid double send
    if (data.emailStatus === "sent" || data.emailedAt) {
      return null;
    }

    const templateId = String(data.templateId || "").trim();
    const templateTitle = String(data.templateTitle || templateId || "Vérif véhicule");
    const createdByEmail = String(data.createdByEmail || "").trim();
    const answers = data.answers || {};

    if (!templateId) {
      await docRef.update({
        emailStatus: "error",
        emailError: "Missing templateId",
        emailUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    const recipients = await resolveRecipients(templateId);

    if (!recipients.length) {
      await docRef.update({
        emailStatus: "error",
        emailError: "No recipients configured (recipientEmails / defaultRecipients).",
        emailUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    // Build email
    const now = new Date();
    const subject = `Vérif ${templateTitle} - ${now.toLocaleDateString("fr-FR")}`;

    const body =
      `Soumission vérif: ${templateTitle}\n` +
      `Date: ${now.toLocaleString("fr-FR")}\n` +
      (createdByEmail ? `Rempli par: ${createdByEmail}\n` : "") +
      `\n--- Réponses ---\n\n` +
      formatAnswers(answers);

    try {
      await transporter.sendMail({
        from: gmailEmail,
        to: recipients.join(","),
        subject,
        text: body,
      });

      await docRef.update({
        emailStatus: "sent",
        emailedAt: admin.firestore.FieldValue.serverTimestamp(),
        emailRecipients: recipients,
        emailUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      console.error("sendMail failed:", e);
      await docRef.update({
        emailStatus: "error",
        emailError: String(e?.message || e),
        emailUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }
  });
// ---- Trigger: notification push when a news post is created
exports.sendNewsNotification = functions
  .region("europe-west1")
  .firestore.document("news_posts/{postId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};

    const title = String(data.title || "Nouvelle info CIS");
    const body = String(data.body || data.content || "Une nouvelle actualité a été publiée.");

    // IMPORTANT: tous les téléphones doivent être abonnés à ce topic côté Flutter
    const message = {
      topic: "cisonesse",
      notification: {
        title,
        body,
      },
      // Optionnel: data pour ouvrir une page spécifique au clic
      data: {
        type: "news_post",
        postId: context.params.postId,
      },
      android: {
        priority: "high",
      },
    };

    try {
      await admin.messaging().send(message);
      return null;
    } catch (e) {
      console.error("FCM send failed:", e);
      return null;
    }
  });
// ---- Trigger: notification push when a planning event is created
exports.sendPlanningNotification = functions
  .region("europe-west1")
  .firestore.document("events/{eventId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};

    const title = String(data.title || "Nouvel événement planning");

    // start/end sont des Timestamps Firestore
    let when = "";
    try {
      const start = data.start?.toDate ? data.start.toDate() : null;
      if (start) {
        when = start.toLocaleString("fr-FR");
      }
    } catch (_) {}

    const body = when ? `Début : ${when}` : "Un nouvel événement a été ajouté.";

    const message = {
      topic: "cisonesse",
      notification: {
        title: `Agenda : ${title}`,
        body,
      },
      data: {
        type: "event",
        eventId: context.params.eventId,
      },
      android: { priority: "high" },
    };

    try {
      await admin.messaging().send(message);
      return null;
    } catch (e) {
      console.error("FCM planning send failed:", e);
      return null;
    }
  });