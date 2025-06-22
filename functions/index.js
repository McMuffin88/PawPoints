const functions = require('firebase-functions');
const admin     = require('firebase-admin');
admin.initializeApp();

// -----------------------------------------
// 1. Deine bestehende Funktion
// -----------------------------------------
exports.onTaskCompleted = functions.firestore
  .document('users/{dogId}/tasks/{taskId}/completions/{completionId}')
  .onCreate(async (snapshot, context) => {
    const { dogId, taskId } = context.params;
    const db = admin.firestore();

    // 1) Task-Daten holen
    const taskSnap = await db.doc(`users/${dogId}/tasks/${taskId}`).get();
    const title    = taskSnap.data()?.title    || '–';
    const points   = taskSnap.data()?.points   || 0;

    // 2) User-Punkte updaten
    const userRef   = db.doc(`users/${dogId}`);
    const userSnap  = await userRef.get();
    const oldPoints = userSnap.data()?.points || 0;
    const newPoints = oldPoints + points;
    await userRef.update({ points: newPoints });

    // 3) FCM-Tokens auslesen
    const tokensSnap = await userRef.collection('fcmTokens').get();
    const tokens     = tokensSnap.docs.map(d => d.id);
    if (tokens.length === 0) {
      console.log('⚠️ Keine Tokens gefunden');
      return;
    }

    // 4) Data-Payload zusammenbauen
    const now      = new Date();
    const timeStr  = now.toLocaleString('de-DE', { day:'numeric', month:'numeric', year:'numeric', hour:'2-digit', minute:'2-digit' });
    const message = {
      tokens,
      notification: {
        title: 'Aufgabe erledigt!',
        body: `"${title}" abgeschlossen. +${points} Punkte.`
      },
      data: {
        taskId,
        taskTitle: title,
        timestamp: timeStr,
        oldPoints: oldPoints.toString(),
        newPoints: newPoints.toString(),
        userId: dogId
      },
      webpush: {
        headers: { Urgency: 'high' }
      }
    };

    try {
      const resp = await admin.messaging().sendMulticast(message);
      console.log(`✅ Push an ${resp.successCount}/${tokens.length} Geräte gesendet`);
    } catch (err) {
      console.error('❌ Fehler beim Senden des Multicast-Push:', err);
    }
  });

// -----------------------------------------
// 2. Passwort zurücksetzen via Benutzername
// -----------------------------------------
exports.sendPasswordResetByUsername = functions.https.onCall(async (data, context) => {
  const username = (data.username || '').trim().toLowerCase();
  if (!username) {
    throw new functions.https.HttpsError("invalid-argument", "Kein Benutzername angegeben.");
  }

  // E-Mail suchen (case-insensitive)
  const userSnap = await admin.firestore()
    .collection('users')
    .where('username', '==', username)
    .limit(1)
    .get();

  if (userSnap.empty) {
    // Niemals verraten, ob ein Username existiert (Datenschutz)!
    return { success: true, message: "Falls ein Account existiert, wurde eine Mail versendet." };
  }

  const email = userSnap.docs[0].get('email');

  try {
    await admin.auth().generatePasswordResetLink(email);
    // (Firebase verschickt die Mail)
  } catch (e) {
    // Fehler ignorieren, immer gleiche Meldung zurückgeben!
  }

  return { success: true, message: "Falls ein Account existiert, wurde eine Mail versendet." };
});

// -----------------------------------------
// 3. Benutzername zu E-Mail (optional, z. B. für Login mit Username)
// -----------------------------------------
exports.usernameToEmail = functions.https.onCall(async (data, context) => {
  const username = (data.username || '').trim().toLowerCase();
  if (!username) {
    throw new functions.https.HttpsError("invalid-argument", "Kein Benutzername angegeben.");
  }

  const userSnap = await admin.firestore()
    .collection('users')
    .where('username', '==', username)
    .limit(1)
    .get();

  if (userSnap.empty) {
    throw new functions.https.HttpsError("not-found", "Benutzername nicht gefunden.");
  }

  return { email: userSnap.docs[0].get('email') };
});
