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

// Passwort vergessen via Benutzername ODER E-Mail: Gibt nur E-Mail (oder null) zurück
exports.sendPasswordResetByUsernameOrEmail = functions.https.onCall(async (data, context) => {
  const identifier = (data.identifier || '').trim();

  console.log("🟠 [Passwort-Reset] Funktion aufgerufen mit:", identifier);

  if (!identifier) {
    console.warn("🟡 [Passwort-Reset] Kein Identifier übergeben.");
    throw new functions.https.HttpsError('invalid-argument', 'Identifier is required.');
  }

  let emailToSendReset = null;

  // Prüfen, ob der Identifier eine gültige E-Mail-Adresse ist
  const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/;
  if (emailRegex.test(identifier)) {
    emailToSendReset = identifier;
    console.log("🔵 [Passwort-Reset] Identifier ist eine E-Mail:", emailToSendReset);
  } else {
    // Wenn kein E-Mail, als Benutzername behandeln
    try {
      const usersRef = admin.firestore().collection('users');
      const querySnapshot = await usersRef.where('benutzername', '==', identifier).limit(1).get();

      if (!querySnapshot.empty) {
        emailToSendReset = querySnapshot.docs[0].data().email;
        console.log("🟢 [Passwort-Reset] E-Mail für Benutzernamen gefunden:", emailToSendReset);
      } else {
        console.warn("🔴 [Passwort-Reset] Kein Benutzer mit diesem Benutzernamen gefunden:", identifier);
      }
    } catch (error) {
      console.error("❌ [Passwort-Reset] Fehler beim Firestore-Query:", error);
    }
  }

  // Immer gleich antworten!
  return { email: emailToSendReset ? emailToSendReset : null };
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
// 7. Einladungscode prüfen + Herrchen-Vorschau + Verknüpfungs- und Pending-Check (NEU!)
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

  // *** NEU: Prüfen ob eine Pending-Request Doggy <-> Herrchen existiert ***
  const pendingSnap = await admin.firestore()
    .collection('pendingRequests')
    .where('doggyId', '==', doggyId)
    .where('herrchenId', '==', herrchenId)
    .where('status', '==', 'pending')
    .limit(1)
    .get();

  const hasPendingRequest = !pendingSnap.empty;

  return {
    alreadyConnected, // bool
    herrchenId,
    benutzername: herrchen.benutzername ?? '',
    profileImageUrl: herrchen.profileImageUrl ?? '',
    age: herrchen.age ?? null,
    gender: normalizeGender(herrchen.gender),
    doggyCount: doggysSnap.size,
    hasPendingRequest,   // <-- NEU
  };
});

// -----------------------------------------
// 8. Zentrale Pending-Request: Doggy → Herrchen (Doggy schickt Anfrage) MIT COOLDOWN
// -----------------------------------------
// -----------------------------------------
// 8. Zentrale Pending-Request: Doggy → Herrchen (Doggy schickt Anfrage) MIT COOLDOWN & KOMPLETTER ANTWORT
// -----------------------------------------
exports.createPendingRequest = functions.https.onCall(async (data, context) => {
  try {
    const doggyId = context.auth?.uid;
    const code = (data.code || '').trim();
    console.log('[createPendingRequest] Eingeloggt:', doggyId, 'Code:', code);

    if (!doggyId) throw new functions.https.HttpsError('unauthenticated', 'Nicht eingeloggt.');
    if (!code) throw new functions.https.HttpsError('invalid-argument', 'Kein Einladungscode übergeben.');

    // Herrchen suchen
    const herrchenSnap = await admin.firestore()
      .collection('users')
      .where('einladungscode', '==', code)
      .limit(1)
      .get();
    console.log('[createPendingRequest] Herrchen gefunden?', !herrchenSnap.empty);

    if (herrchenSnap.empty) throw new functions.https.HttpsError('not-found', 'Herrchen nicht gefunden.');
    const herrchenDoc = herrchenSnap.docs[0];
    const herrchenId = herrchenDoc.id;
    const herrchenData = herrchenDoc.data() || {};

    // COOLDOWN prüfen
    const lastRejectedSnap = await admin.firestore().collection('pendingRequests')
      .where('doggyId', '==', doggyId)
      .where('herrchenId', '==', herrchenId)
      .where('status', '==', 'rejected')
      .orderBy('decidedAt', 'desc')
      .limit(1)
      .get();
    console.log('[createPendingRequest] lastRejectedSnap size:', lastRejectedSnap.size);

    if (!lastRejectedSnap.empty) {
      const lastRejected = lastRejectedSnap.docs[0].data();
      const cooldownDays = 7;
      const now = Date.now();
      const rejectedAt = lastRejected.decidedAt?.toDate?.().getTime?.();
      console.log('[createPendingRequest] cooldownCheck:', { rejectedAt, now, diff: now - rejectedAt });
      if (rejectedAt && ((now - rejectedAt) < cooldownDays * 24 * 60 * 60 * 1000)) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `Du kannst frühestens ${cooldownDays} Tage nach Ablehnung eine neue Anfrage an dieses Herrchen stellen.`
        );
      }
    }

    // Prüfen, ob schon eine offene Anfrage zwischen diesen beiden läuft:
    const requestId = `${doggyId}_${herrchenId}`;
    const pendingRef = admin.firestore().collection('pendingRequests').doc(requestId);
    if ((await pendingRef.get()).exists) {
      console.warn('[createPendingRequest] Anfrage läuft bereits!');
      throw new functions.https.HttpsError('already-exists', 'Es läuft bereits eine Anfrage zwischen dir und diesem Herrchen.');
    }

    // Premium-Status laden
    const doggySnap = await admin.firestore().collection('users').doc(doggyId).get();
    const doggyData = doggySnap.data() || {};
    const isDoggyPremium = !!(doggyData.premium && doggyData.premium.doggy);
    const isHerrchenPremium = !!(herrchenData.premium && herrchenData.premium.herrchen);

    // Limite prüfen: Free-User dürfen nur EINE offene Anfrage / Verbindung haben!
    const doggyPending = await admin.firestore().collection('pendingRequests')
      .where('doggyId', '==', doggyId)
      .where('status', '==', 'pending')
      .get();
    const doggyConnections = await admin.firestore().collection('users').doc(doggyId)
      .collection('assignedHerrchen').get();
    console.log('[createPendingRequest] isDoggyPremium:', isDoggyPremium, 'pending:', doggyPending.size, 'connections:', doggyConnections.size);

    if (!isDoggyPremium && (doggyPending.size > 0 || doggyConnections.size > 0)) {
      throw new functions.https.HttpsError('resource-exhausted', 'Nur ein Herrchen erlaubt (Upgrade auf Premium für mehrere Anfragen/Verbindungen möglich)');
    }

    // Limite prüfen: Herrchen-Seite
    const herrchenPending = await admin.firestore().collection('pendingRequests')
      .where('herrchenId', '==', herrchenId)
      .where('status', '==', 'pending')
      .get();
    const herrchenConnections = await admin.firestore().collection('users').doc(herrchenId)
      .collection('doggys').get();
    console.log('[createPendingRequest] isHerrchenPremium:', isHerrchenPremium, 'pending:', herrchenPending.size, 'connections:', herrchenConnections.size);

    if (!isHerrchenPremium && (herrchenPending.size > 0 || herrchenConnections.size > 0)) {
      throw new functions.https.HttpsError('resource-exhausted', 'Dieses Herrchen kann nur eine Doggy-Anfrage/Verbindung haben (Premium nötig für mehr)');
    }

    // Anfrage anlegen!
await pendingRef.set({
  doggyId,
  herrchenId,
  doggyName: doggyData.benutzername ?? 'Unbekannt',
  doggyAvatarUrl: doggyData.profileImageUrl ?? '',
  herrchenName: herrchenData.benutzername ?? 'Unbekannt',
  herrchenAvatarUrl: herrchenData.profileImageUrl ?? '',
  requestedAt: admin.firestore.FieldValue.serverTimestamp(),
  status: 'pending',
});
    console.log('[createPendingRequest] Anfrage angelegt:', requestId);

    // Herrchen-Infos für den Client zurückgeben:
    return {
      success: true,
      herrchen: {
        herrchenId,
        benutzername: herrchenData.benutzername ?? 'Unbekannt',
        profileImageUrl: herrchenData.profileImageUrl ?? null,
        age: herrchenData.age ?? null,
        gender: herrchenData.gender ?? null
      }
    };
  } catch (e) {
    console.error('[createPendingRequest] Fehler:', e);
    throw new functions.https.HttpsError(e.code || 'internal', e.message || e.toString());
  }
});



// -----------------------------------------
// 9. Zentrale Pending-Request zurückziehen (Doggy storniert eigene Anfrage)
// -----------------------------------------
exports.cancelPendingRequest = functions.https.onCall(async (data, context) => {
  try {
    const doggyId = context.auth?.uid;
    const herrchenId = (data.herrchenId || '').trim();
    console.log('[cancelPendingRequest] doggyId:', doggyId, 'herrchenId:', herrchenId);

    if (!doggyId) throw new functions.https.HttpsError('unauthenticated', 'Nicht eingeloggt.');
    if (!herrchenId) throw new functions.https.HttpsError('invalid-argument', 'Kein Herrchen angegeben.');

    const requestId = `${doggyId}_${herrchenId}`;
    const pendingRef = admin.firestore().collection('pendingRequests').doc(requestId);
    const pendingDoc = await pendingRef.get();

    if (!pendingDoc.exists) {
      console.warn('[cancelPendingRequest] Anfrage nicht gefunden:', requestId);
      throw new functions.https.HttpsError('not-found', 'Anfrage nicht gefunden.');
    }

    const dataPending = pendingDoc.data();
    console.log('[cancelPendingRequest] Anfrage geladen:', dataPending);

    if (dataPending.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'Anfrage kann nicht mehr zurückgezogen werden.');
    }
    if (dataPending.doggyId !== doggyId) {
      throw new functions.https.HttpsError('permission-denied', 'Du kannst nur deine eigenen Anfragen zurückziehen.');
    }

    await pendingRef.delete();
    console.log('[cancelPendingRequest] Anfrage gelöscht:', requestId);

    return { success: true };
  } catch (e) {
    console.error('[cancelPendingRequest] Fehler:', e);
    throw new functions.https.HttpsError(e.code || 'internal', e.message || e.toString());
  }
});


// -----------------------------------------
// 10. Zentrale Pending-Request beantworten (Herrchen akzeptiert oder lehnt ab) – mit Status & Zeitstempel
// -----------------------------------------
exports.respondToPendingRequest = functions.https.onCall(async (data, context) => {
  try {
    const herrchenId = context.auth?.uid;
    const doggyId = (data.doggyId || '').trim();
    const accepted = !!data.accepted;
    console.log('[respondToPendingRequest] herrchenId:', herrchenId, 'doggyId:', doggyId, 'accepted:', accepted);

    if (!herrchenId) throw new functions.https.HttpsError('unauthenticated', 'Nicht eingeloggt.');
    if (!doggyId) throw new functions.https.HttpsError('invalid-argument', 'Kein Doggy angegeben.');

    const requestId = `${doggyId}_${herrchenId}`;
    const pendingRef = admin.firestore().collection('pendingRequests').doc(requestId);
    const pendingDoc = await pendingRef.get();

    if (!pendingDoc.exists) {
      console.warn('[respondToPendingRequest] Anfrage nicht gefunden:', requestId);
      throw new functions.https.HttpsError('not-found', 'Anfrage nicht gefunden.');
    }

    const pendingData = pendingDoc.data();
    console.log('[respondToPendingRequest] Anfrage geladen:', pendingData);

    if (pendingData.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'Anfrage ist nicht mehr offen.');
    }
    if (pendingData.herrchenId !== herrchenId) {
      throw new functions.https.HttpsError('permission-denied', 'Du darfst nur Anfragen an dich selbst beantworten.');
    }

    if (accepted) {
      // Premium-Status und Limits prüfen
      const herrchenSnap = await admin.firestore().collection('users').doc(herrchenId).get();
      const herrchenData = herrchenSnap.data() || {};
      const isHerrchenPremium = !!(herrchenData.premium && herrchenData.premium.herrchen);


      const herrchenConnections = await admin.firestore().collection('users').doc(herrchenId)
        .collection('doggys').get();

      if (!isHerrchenPremium && herrchenConnections.size > 0) {
        throw new functions.https.HttpsError('resource-exhausted', 'Nur ein Doggy erlaubt (Premium für mehrere Verbindungen nötig)');
      }

      const doggySnap = await admin.firestore().collection('users').doc(doggyId).get();
      const doggyData = doggySnap.data() || {};
      const isDoggyPremium = !!(doggyData.premium && doggyData.premium.doggy);
      const doggyConnections = await admin.firestore().collection('users').doc(doggyId)
        .collection('assignedHerrchen').get();

      if (!isDoggyPremium && doggyConnections.size > 0) {
        throw new functions.https.HttpsError('resource-exhausted', 'Dieses Doggy kann nur ein Herrchen haben (Premium nötig für mehr)');
      }

      await admin.firestore()
        .collection('users')
        .doc(herrchenId)
        .collection('doggys')
        .doc(doggyId)
  .set({
    uid: doggyId,
    benutzername: doggyData.benutzername ?? 'Unbekannter Doggy',
    profileImageUrl: doggyData.profileImageUrl ?? '',
    verbundenAm: admin.firestore.FieldValue.serverTimestamp(),
  });

      await admin.firestore()
        .collection('users')
        .doc(doggyId)
        .collection('assignedHerrchen')
        .doc(herrchenId)
        .set({
          name: herrchenData.benutzername ?? 'Unbekannt',
          status: 'aktiv',
          connectedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      await pendingRef.update({ status: 'accepted', decidedAt: admin.firestore.FieldValue.serverTimestamp() });
      console.log('[respondToPendingRequest] Anfrage akzeptiert und Verbindung hergestellt!');
    } else {
      await pendingRef.update({ status: 'rejected', decidedAt: admin.firestore.FieldValue.serverTimestamp() });
      console.log('[respondToPendingRequest] Anfrage abgelehnt.');
    }

    return { success: true };
  } catch (e) {
    console.error('[respondToPendingRequest] Fehler:', e);
    throw new functions.https.HttpsError(e.code || 'internal', e.message || e.toString());
  }
});


// -----------------------------------------
// 11. Offene Pending-Request des eingeloggten Doggys abfragen (inkl. Herrchen-Infos)
// -----------------------------------------
exports.getOwnPendingRequest = functions.https.onCall(async (data, context) => {
  try {
    const doggyId = context.auth?.uid;
    if (!doggyId) throw new functions.https.HttpsError('unauthenticated', 'Nicht eingeloggt.');
    console.log('[getOwnPendingRequest] doggyId:', doggyId);

    const pendingSnap = await admin.firestore().collection('pendingRequests')
      .where('doggyId', '==', doggyId)
      .where('status', '==', 'pending')
      .limit(1)
      .get();

    console.log('[getOwnPendingRequest] pendingSnap.size:', pendingSnap.size);

    if (pendingSnap.empty) return { pendingRequest: null };

    const pendingData = pendingSnap.docs[0].data();
    const herrchenId = pendingData.herrchenId;
    const herrchenDoc = await admin.firestore().collection('users').doc(herrchenId).get();
    const herrchen = herrchenDoc.exists ? herrchenDoc.data() : {};
    console.log('[getOwnPendingRequest] Herrchen geladen:', herrchenId, herrchen.benutzername);

    const response = {
      pendingRequest: {
        herrchenId,
        herrchenName: herrchen.benutzername ?? 'Unbekannt',
        profileImageUrl: herrchen.profileImageUrl ?? null,
        age: herrchen.age ?? null,
        gender: herrchen.gender ?? null,
        requestedAt: pendingData.requestedAt,
        status: pendingData.status,
      }
    };

    console.log("[getOwnPendingRequest] Response:", response);
    return response;
  } catch (e) {
    console.error('[getOwnPendingRequest] Fehler:', e);
    throw new functions.https.HttpsError(e.code || 'internal', e.message || e.toString());
  }
});








