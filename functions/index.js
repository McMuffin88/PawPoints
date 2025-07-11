const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// -----------------------------------------
// 1. Task Completion Push Notification
// -----------------------------------------
exports.onTaskCompleted = functions.firestore
  .document('users/{dogId}/tasks/{taskId}/completions/{completionId}')
  .onCreate(async (snapshot, context) => {
    const { dogId, taskId } = context.params;
    const db = admin.firestore();

    // 1) Task-Daten holen
    const taskSnap = await db.doc(`users/${dogId}/tasks/${taskId}`).get();
    const title = taskSnap.data()?.title || '–';
    const points = taskSnap.data()?.points || 0;

    // 2) User-Punkte updaten
    const userRef = db.doc(`users/${dogId}`);
    const userSnap = await userRef.get();
    const oldPoints = userSnap.data()?.points || 0;
    const newPoints = oldPoints + points;
    await userRef.update({ points: newPoints });

    // 3) FCM-Tokens auslesen
    const tokensSnap = await userRef.collection('fcmTokens').get();
    const tokens = tokensSnap.docs.map(d => d.id);
    if (tokens.length === 0) {
      console.log('⚠️ Keine Tokens gefunden');
      return;
    }

    // 4) Data-Payload zusammenbauen
    const now = new Date();
    const timeStr = now.toLocaleString('de-DE', {
      day: 'numeric',
      month: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
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

// ANGEPASST: Passwort zurücksetzen via Benutzername ODER E-Mail
exports.sendPasswordResetByUsernameOrEmail = functions.https.onCall(async (data, context) => {
  const identifier = (data.identifier || '').trim(); // Kann Benutzername oder E-Mail sein

  if (!identifier) {
    throw new functions.https.HttpsError('invalid-argument', 'Identifier is required.');
  }

  let emailToSendReset = null;

  // 1. Prüfen, ob der Identifier eine gültige E-Mail-Adresse ist
  const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/;
  if (emailRegex.test(identifier)) {
    emailToSendReset = identifier; // Es ist eine E-Mail
  } else {
    // 2. Wenn es keine E-Mail ist, versuchen wir, es als Benutzernamen zu behandeln
    // Suchen Sie in Ihrer Firestore-Datenbank nach dem Benutzer mit diesem Benutzernamen
    try {
      const usersRef = admin.firestore().collection('users');
      // Verwenden Sie 'benutzername' wie in Ihrem Firestore-Schema
      const querySnapshot = await usersRef.where('benutzername', '==', identifier).limit(1).get();

      if (!querySnapshot.empty) {
        emailToSendReset = querySnapshot.docs[0].data().email;
      }
    } catch (error) {
      console.error("Error fetching user by username for password reset:", error);
      // Ignoriere diesen Fehler für den Benutzer, um keine Informationen preiszugeben
    }
  }

  // Wichtig: Geben Sie IMMER die gleiche Nachricht zurück,
  // unabhängig davon, ob die E-Mail gefunden wurde oder nicht,
  // um Benutzer-Enumeration zu verhindern.
  if (emailToSendReset) {
    try {
      await admin.auth().sendPasswordResetEmail(emailToSendReset);
      console.log(`Password reset email sent (or attempted) for identifier: ${identifier}`);
    } catch (error) {
      // Wenn das Senden der E-Mail fehlschlägt (z.B. ungültige E-Mail-Adresse bei Firebase Auth),
      // protokollieren Sie es serverseitig, aber geben Sie dem Benutzer immer noch die generische Nachricht.
      console.error(`Failed to send password reset email for ${emailToSendReset}:`, error);
    }
  } else {
    // Wenn keine E-Mail gefunden wurde (weder direkte E-Mail noch über Benutzername),
    // protokollieren Sie dies, aber geben Sie dem Benutzer die generische Nachricht.
    console.log(`No email found for identifier: ${identifier}. Still sending generic success message.`);
  }

  // Diese Nachricht wird IMMER an den Client gesendet, um User-Enumeration zu verhindern.
  return { message: 'Wenn ein Account mit dieser Eingabe existiert, wurde eine E-Mail zum Zurücksetzen des Passworts gesendet.' };
});

// -----------------------------------------
// 3. Benutzername zu E-Mail (optional, z. B. für Login mit Username)
// -----------------------------------------
exports.usernameToEmail = functions.https.onCall(async (data, context) => {
  const username = (data.username || '').trim(); // kein toLowerCase!

  if (!username) {
    throw new functions.https.HttpsError("invalid-argument", "Kein Benutzername angegeben.");
  }

  const userSnap = await admin.firestore()
    .collection('users')
    .where('benutzername', '==', username) // exakte Suche auf Feld "benutzername"
    .limit(1)
    .get();

  if (userSnap.empty) {
    throw new functions.https.HttpsError("not-found", "Benutzername nicht gefunden.");
  }

  return { email: userSnap.docs[0].get('email') };
});

// -----------------------------------------
// 4. Versionsprüfung
// -----------------------------------------

exports.checkAppVersion = functions.https.onCall(async (data, context) => {
  const currentVersion = data.currentVersion || "0.0.0";

  let requiredVersion = "0.0.0"; // Standardwert
  let updateUrl = "https://example.com/your-app-store-link"; // Standard-Update-URL

  try {
    // Lade die Versionsinformation aus dem Dokument 'meta/version'
    const versionDocRef = admin.firestore().collection('meta').doc('version');
    const versionDoc = await versionDocRef.get();

    if (versionDoc.exists) {
      const versionData = versionDoc.data();
      // Verwende das Feld 'version' aus Ihrem Firestore-Dokument für die erforderliche Version
      requiredVersion = versionData.version || "0.0.0";
      // Verwende das Feld 'downloadUrl' aus Ihrem Firestore-Dokument für die Update-URL
      updateUrl = versionData.downloadUrl || updateUrl;
    } else {
      console.warn("Firestore-Dokument 'meta/version' nicht gefunden. Verwende Standardwerte.");
    }
  } catch (error) {
    console.error("Fehler beim Laden der Versionsinformation aus Firestore:", error);
    // Bei einem Fehler werden die Standardwerte beibehalten oder du könntest einen Fehler werfen
  }

  function versionToNums(v) {
    return v.split('.').map(x => parseInt(x));
  }

  const cv = versionToNums(currentVersion);
  const rv = versionToNums(requiredVersion);

  let outdated = false;
  for (let i = 0; i < Math.max(cv.length, rv.length); i++) {
    const c = cv[i] || 0;
    const r = rv[i] || 0;
    if (c < r) {
      outdated = true;
      break;
    } else if (c > r) {
      // Wenn die aktuelle Version HÖHER ist, ist kein Update nötig
      outdated = false;
      break;
    }
    // Wenn c == r, gehe zur nächsten Versionsnummer
  }

  return {
    requiredVersion, // Die Version, die vom Backend als aktuellste angesehen wird
    updateUrl: outdated ? updateUrl : null,
    outdated // Boolean, ob die aktuelle App-Version veraltet ist
  };
});

// -----------------------------------------
// 5. Profilanforderungen laden
// -----------------------------------------
exports.getProfileRequirements = functions.https.onCall(async (data, context) => {
  const doc = await admin.firestore().collection('config').doc('profile_requirements').get();

  if (!doc.exists) {
    return {
      requiredFields: ['benutzername', 'vorname', 'nachname', 'geburtsdatum', 'gender', 'roles'],
      infoMessage: 'Ab Version 1.0.0 werden diese Daten für eine bessere Nutzererfahrung benötigt.'
    };
  }

  const profileData = doc.data();
  return {
    requiredFields: profileData.requiredFields || [],
    infoMessage: profileData.infoMessage || ''
  };
});

// -----------------------------------------
// 6. Einladungscode prüfen/erstellen (NEU!)
// -----------------------------------------
exports.checkOrCreateInviteCode = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Nicht eingeloggt.');

  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  const user = userDoc.data() || {};

  // Prüfe, ob ein gültiger Code existiert
  const code = user.einladungscode;
  const erstelltAm = user.code_erstellt_am ? user.code_erstellt_am.toDate() : null;
  let nochGueltig = false;
  if (code && erstelltAm) {
    const vierWochen = 28 * 24 * 60 * 60 * 1000; // 28 Tage in ms
    nochGueltig = (Date.now() - erstelltAm.getTime()) < vierWochen;
  }

  if (code && nochGueltig) {
    return { code, erstelltAm: user.code_erstellt_am };
  }

  // Neuen Code generieren (6-stellig, nur Buchstaben/Zahlen)
  const newCode = Math.random().toString(36).substr(2, 6).toUpperCase();
  const now = admin.firestore.Timestamp.now();

  await userRef.set({
    einladungscode: newCode,
    code_erstellt_am: now
  }, { merge: true });

  return { code: newCode, erstelltAm: now };
});

// -----------------------------------------
// 7. Einladungscode prüfen + Herrchen-Vorschau + Verknüpfungs-Check
// -----------------------------------------
exports.checkInviteCodeAndPreview = functions.https.onCall(async (data, context) => {
  function normalizeGender(gender) {
    if (!gender) return null;
    const lower = ('' + gender).toLowerCase();
    if (['male', 'männlich'].includes(lower)) return 'male';
    if (['female', 'weiblich'].includes(lower)) return 'female';
    if (['diverse', 'divers'].includes(lower)) return 'diverse';
    return null;
  }

  const code = (data.code || '').trim();
  const doggyId = context.auth?.uid;

  if (!code) throw new functions.https.HttpsError('invalid-argument', 'Kein Code angegeben.');
  if (!doggyId) throw new functions.https.HttpsError('unauthenticated', 'Nicht eingeloggt.');

  // Suche Herrchen-User mit diesem Einladungscode
  const herrchenSnap = await admin.firestore()
    .collection('users')
    .where('einladungscode', '==', code)
    .limit(1)
    .get();

  if (herrchenSnap.empty) throw new functions.https.HttpsError('not-found', 'Einladungscode ungültig oder abgelaufen.');

  const herrchenDoc = herrchenSnap.docs[0];
  const herrchenId = herrchenDoc.id;
  const herrchen = herrchenDoc.data();

  // Gültigkeit prüfen
  const createdAt = herrchen.code_erstellt_am?.toDate?.();
  if (!createdAt) throw new functions.https.HttpsError('failed-precondition', 'Kein gültiges Erstellungsdatum gespeichert.');
  const expiresAt = new Date(createdAt.getTime() + 28 * 24 * 60 * 60 * 1000);
  if (Date.now() > expiresAt.getTime()) throw new functions.https.HttpsError('failed-precondition', 'Einladungscode abgelaufen.');

  // Prüfen, ob das Doggy schon beim Herrchen hängt
  const doggyDoc = await herrchenDoc.ref.collection('doggys').doc(doggyId).get();
  const alreadyConnected = doggyDoc.exists;

  // Herrchen-Vorschau aufbauen
  const doggysSnap = await herrchenDoc.ref.collection('doggys').get();

  return {
    alreadyConnected, // bool
    herrchenId,
    benutzername: herrchen.benutzername ?? '',
    profileImageUrl: herrchen.profileImageUrl ?? '',
    age: herrchen.age ?? null,
    gender: normalizeGender(herrchen.gender),
    doggyCount: doggysSnap.size,
  };
});

// -----------------------------------------
// 8. Verbindungsanfrage: Doggy → Herrchen (Doggy schickt Anfrage)
// -----------------------------------------
exports.requestConnectionToHerrchen = functions.https.onCall(async (data, context) => {
  const doggyId = context.auth?.uid;
  const code = (data.code || '').trim();

  if (!doggyId) throw new functions.https.HttpsError('unauthenticated', 'Nicht eingeloggt.');
  if (!code) throw new functions.https.HttpsError('invalid-argument', 'Kein Einladungscode übergeben.');

  // Herrchen suchen
  const herrchenSnap = await admin.firestore()
    .collection('users')
    .where('einladungscode', '==', code)
    .limit(1)
    .get();

  if (herrchenSnap.empty) throw new functions.https.HttpsError('not-found', 'Herrchen nicht gefunden.');
  const herrchenDoc = herrchenSnap.docs[0];
  const herrchenId = herrchenDoc.id;

  // Prüfe, ob schon eine offene Anfrage existiert:
  const requestRef = admin.firestore()
    .collection('users').doc(herrchenId)
    .collection('pendingDoggyRequests')
    .doc(doggyId);

  if ((await requestRef.get()).exists) {
    throw new functions.https.HttpsError('already-exists', 'Anfrage läuft bereits.');
  }

  // Anfrage speichern, JETZT MIT herrchenId!
  await requestRef.set({
    doggyId,
    herrchenId, // <<<<<<<<<<< HINZUGEFÜGT
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'pending',
  });

  // (Optional: Benachrichtigung an Herrchen senden)

  return { success: true };
});


// -----------------------------------------
// 9. Herrchen bestätigt oder lehnt Doggy-Anfrage ab
// -----------------------------------------
exports.respondToDoggyRequest = functions.https.onCall(async (data, context) => {
  const herrchenId = context.auth?.uid;
  const doggyId = data.doggyId;
  const accepted = data.accepted; // true = akzeptieren, false = ablehnen

  if (!herrchenId) throw new functions.https.HttpsError('unauthenticated', 'Nicht eingeloggt.');
  if (!doggyId) throw new functions.https.HttpsError('invalid-argument', 'Kein Doggy angegeben.');

  const requestRef = admin.firestore()
    .collection('users').doc(herrchenId)
    .collection('pendingDoggyRequests')
    .doc(doggyId);

  const reqDoc = await requestRef.get();
  if (!reqDoc.exists) throw new functions.https.HttpsError('not-found', 'Anfrage nicht gefunden.');

  if (accepted) {
    // Verbindung herstellen:
    await admin.firestore()
      .collection('users')
      .doc(herrchenId)
      .collection('doggys')
      .doc(doggyId)
      .set({
        uid: doggyId,
        verbundenAm: admin.firestore.FieldValue.serverTimestamp(),
      });

    await admin.firestore()
      .collection('users')
      .doc(doggyId)
      .collection('assignedHerrchen')
      .doc(herrchenId)
      .set({
        name: reqDoc.data().benutzername ?? 'Unbekannt', // Passe ggf. an!
        status: 'aktiv',
        connectedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Anfrage auf "accepted" setzen
    await requestRef.update({ status: 'accepted', decidedAt: admin.firestore.FieldValue.serverTimestamp() });
  } else {
    await requestRef.update({ status: 'rejected', decidedAt: admin.firestore.FieldValue.serverTimestamp() });
  }

  return { success: true };
});

