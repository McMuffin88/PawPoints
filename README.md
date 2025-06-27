# PawPoints

## Zusammenfassung

**PawPoints** ist die App für die Human Pupplay-/Dogplay-Community. Sie richtet sich an Erwachsene (18+), die in exklusiven Rollen als „Herrchen“ (Handler) oder „Doggy“ (Pup) spielerische, konsensuelle Beziehungen ausleben möchten.  
Die App bietet Aufgabenmanagement, Belohnungen, optionale Bestrafungen, Levelsystem und viele Möglichkeiten zur Individualisierung – alles diskret, sicher und rollenspezifisch.

---

## Zielgruppe & Abgrenzung

- **Ausschließlich für Erwachsene (18+)**
- **Human Pupplay/Dogplay, BDSM- und Fetisch-Community**
- Keine App für Tierpflege, keine echten Tiere!
- Fokus: **Konsens, Diskretion, Datenschutz**
- Jede Person entscheidet sich beim Onboarding für **eine Rolle** (Herrchen oder Doggy)

---

## Features

### Rollen & Onboarding

- **Exklusive Rollenwahl:** Direkt beim ersten Start entscheidet sich die Nutzer*in für „Herrchen“ oder „Doggy“. Die Rolle kann nachträglich nur durch kompletten Reset gewechselt werden.
- **Verbindung:**  
  - **Doggy:** Verbindet sich per Einladungscode/QR mit einem Herrchen  
  - **Herrchen:** Erstellt Einladungscodes, sieht und verwaltet alle eigenen Doggys (mit Level, Status, Historie)
  - **Status:** Verbindung kann jederzeit getrennt werden (mit Bestätigungsdialog)

---

### Aufgaben & Punktesystem

- **Herrchen:** Erstellt, vergibt und verwaltet Aufgaben, Belohnungen, Bestrafungen pro Doggy  
  - Aufgaben mit Titel, Beschreibung, ggf. Deadline und Punktewert  
  - Aufgaben werden Doggys zugewiesen, Historie und Status im Blick  
- **Doggy:**  
  - Sieht zugewiesene Aufgaben, kann sie als „erledigt“ markieren (Dialog/Bestätigung)  
  - Sammelt Punkte für jede erledigte Aufgabe (Punkteübersicht permanent sichtbar)  
  - Kann Punkte im Shop gegen Belohnungen eintauschen  
  - Sieht Bestrafungen **nicht**, außer sie werden explizit zugewiesen

---

### Shop-System

- **Tabs für Aufgaben, Belohnungen, Bestrafungen** (nur Herrchen sieht alle Tabs, Doggy sieht nur Belohnungen)
- **Shop-Items** mit Name, Beschreibung, Punktewert, optionalem Bild/Tag
- **Belohnungen:** Dinge, die sich Doggys „kaufen“ oder verdienen können
- **Bestrafungen:** Nur für Herrchen sichtbar und steuerbar, erscheinen beim Doggy nur, wenn aktiv zugewiesen
- **Premium:** Shop-Items können als „Bark“, „Knochen“, „Leckerli“ dargestellt oder ausgegeben werden

---

### Berechtigungstypen für Doggys

Herrchen kann jedem Doggy gezielt Rechte geben oder entziehen:

| Berechtigung                             | Beschreibung                                                                                   |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------- |
| **Eigene Aufgaben anlegen**               | Doggy darf neue Aufgaben selbst erstellen                                                      |
| **Eigene Aufgaben bearbeiten**            | Doggy kann eigene Aufgaben im Nachhinein bearbeiten                                            |
| **Eigene Aufgaben löschen**               | Doggy kann selbst angelegte Aufgaben löschen                                                   |
| **Eigene Belohnungen anlegen**            | Doggy kann eigene Vorschläge für Belohnungen einreichen                                        |
| **Eigene Belohnungen bearbeiten**         | Doggy kann selbst vorgeschlagene Belohnungen verändern                                         |
| **Eigene Belohnungen löschen**            | Doggy kann eigene Belohnungen löschen                                                          |
| **Eigene Bestrafungen anlegen**           | Doggy kann eigene Vorschläge für Bestrafungen machen                                           |
| **Eigene Bestrafungen bearbeiten**        | Doggy kann eigene Bestrafungsvorschläge verändern                                              |
| **Eigene Bestrafungen löschen**           | Doggy kann eigene Bestrafungen löschen                                                         |
| **Regeln ändern**                         | Doggy darf gemeinsame Regeln der Beziehung bearbeiten                                          |
| **Notizen ändern**                        | Doggy kann Notizen anpassen (z. B. für Aufgaben, Sessions)                                     |
| **Historie bearbeiten**                   | Doggy darf Verlauf (Aufgaben, Belohnungen etc.) bearbeiten                                    |

**Standard:** Fast alle Rechte sind aus Sicherheitsgründen zunächst deaktiviert.

---

### Profil & Sicherheit

- **Profilbearbeitung:** Name, Profilbild, Lieblingsfarbe (steuert Theme), PLZ/Ort, Pronomen (optional)
- **PIN-Schutz:** Optionaler Zugangsschutz (SHA256-Hash im Code)
- **Diskretmodus:**  
  - Dezente Farben, auf Wunsch anderes App-Icon  
  - Inhalte können ausgeblendet werden  
  - App fragt beim Start/Wiedereinstieg nach PIN
- **Mehrsprachigkeit:** Geplant

---

### Navigation & App-Architektur

- **Doggy (Drawer):**  
  - Profil  
  - Herrchen finden  
  - Aufgabenübersicht  
  - Shop (nur Belohnungen sichtbar)  
  - Einstellungen (Theme, PIN, Diskret)
- **Herrchen (Drawer):**  
  - Profil  
  - Meine Doggys (mit Level, QR-Einladung, Trennen)  
  - Berechtigungen (pro Doggy, granular steuerbar)  
  - Shop (Aufgaben, Belohnungen, Bestrafungen, Tabs)  
  - Premium  
  - Roadmap  
  - Tätigkeiten (z. B. Benachrichtigungen, Wochenübersicht, Verlauf)  
  - Einstellungen (PIN, Theme, Diskret, Sprache, Export)  
  - Support (FAQ, Feedback, Datenschutz)

---

## Premium-Features (aktuell & geplant)

- Exklusive Doggy-Avatare
- Premium-Themes & Hintergründe
- Frühzeitiger Zugriff auf neue Features
- Umwandlung von Punkten in Bark/Knochen/Leckerli
- Shop-Items ausblendbar machen
- Doggys können aktiv nach Herrchen suchen
- Herrchen können freie Doggys finden (Matching/Streuner-Modus)
- Mehrere Doggys pro Herrchen (Gruppenverwaltung)
- Export als PDF/CSV/JSON (Punkte, Aufgaben, Verlauf)
- Statistik- und Communityfunktionen (in Planung)
- Kalenderintegration & Push-Benachrichtigungen

---

## Shop-Kategorien & Item-Typen

| Kategorie        | Typ             | Beschreibung                                           | Sichtbarkeit           |
| ---------------- | --------------- | ------------------------------------------------------ | ---------------------- |
| **Belohnung**    | Prämie          | Alles, was Doggy sich als Anerkennung „kaufen“ kann    | Doggy + Herrchen       |
| **Bestrafung**   | Sanktion/Pflicht| Konsequenzen für Regelverstöße, Pflichtaufgaben etc.   | Nur Herrchen*          |

*Bestrafungen erscheinen beim Doggy nur, wenn sie explizit zugewiesen wurden.*

**Shop-Item Felder:**  
- Name/Titel  
- Kategorie  
- Beschreibung (optional)  
- Punktewert  
- Optional: Bild/Avatar, Tags

---

## Beispiel-User-Flows

### Doggy
1. App-Start, Rolle wählen, Profil einrichten
2. Herrchen koppeln (QR/Code)
3. Aufgaben ansehen, erledigen, Punkte sammeln
4. Shop besuchen, Belohnungen einlösen
5. Profil und Sicherheit anpassen

### Herrchen
1. App-Start, Rolle wählen, Profil einrichten
2. Doggys verbinden (QR/Code)
3. Aufgaben, Belohnungen, Bestrafungen anlegen und Doggys zuweisen
4. Berechtigungen verwalten
5. Premiumfunktionen und Auswertungen nutzen

---

## Roadmap (Stand: [aktuelles Datum])

**Bugfixes:**  
- Profilanpassung: Burgermenü ersetzen

**Nächste To-Dos:**  
- Doggy-Screen: Bestrafungen filtern, Aufgaben korrekt anzeigen
- Shop mit echten Belohnungen für Doggys füllen
- Ausklappbare Aufgabenlisten bei Doggy

**Features:**  
- ✅ Berechtigungslogik fertig
- ✅ Nachrichtenfunktion Doggy ↔ Herrchen
- ✅ Fotobeweis bei Aufgaben
- ✅ Individuelle Nachricht nach Erledigung

**Premium-Extras:**  
Siehe Liste oben.

---

## Setup & Installation

1. Flutter & Dart installieren
2. Repository klonen
3. `flutter pub get`
4. Firebase konfigurieren (`firebase_options.dart`)
5. App starten: `flutter run`

---

## Datenschutz & Hinweise

- Die App ist nur für volljährige, einvernehmlich agierende Nutzer*innen gedacht.
- Keine Weitergabe oder Anzeige sensibler Daten an Dritte.
- Entwicklung mit Fokus auf Diskretion und maximale Privatsphäre.

---

## Kontakt & Impressum

Kontakt: [deine.email@domain.com]  
Impressum: [Hier einfügen]

---

**Feedback & Feature-Wünsche:**  
Direkt via Feedback-Funktion in der App willkommen!

