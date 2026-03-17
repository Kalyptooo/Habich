# 📱 HabIch? – Die Anti-Panik-App

> Nie wieder das mulmige Gefühl: "Hab ich den Herd ausgemacht?"

## 🚀 APK automatisch bauen (empfohlen – kostenlos, kein PC nötig)

### Schritt 1 – GitHub-Konto erstellen
👉 https://github.com/signup (kostenlos)

### Schritt 2 – Diesen Ordner hochladen
1. Gehe zu https://github.com/new
2. Repository-Name: `habich-app`
3. Klick auf **"Create repository"**
4. Dann: **"uploading an existing file"**
5. Den kompletten Inhalt dieses ZIP-Ordners hineinziehen
6. Klick auf **"Commit changes"**

### Schritt 3 – APK herunterladen
1. Klick oben auf **"Actions"**
2. Links: **"Build HabIch? APK"** anklicken
3. Den laufenden Build anklicken (grüner Kreis = fertig)
4. Ganz unten unter **"Artifacts"**: `HabIch-release-apk` herunterladen
5. ZIP entpacken → `app-release.apk` auf dein Android-Handy kopieren

### Schritt 4 – APK installieren
1. APK auf dein Handy kopieren (z.B. per USB oder Google Drive)
2. Tippe auf die APK-Datei
3. Falls gefragt: "Unbekannte Quellen erlauben" → bestätigen
4. App installieren → fertig! 🎉

---

## 💻 Lokal bauen (optional)

```bash
# 1. Flutter installieren
sudo snap install flutter --classic   # Linux
# oder: https://flutter.dev/docs/get-started/install

# 2. Dependencies
flutter pub get

# 3. APK bauen
flutter build apk --release

# 4. APK liegt hier:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## ✨ Features

- 🍳 **Voreingestellte Checks**: Herd, Haustür, Fenster, Bügeleisen, Kaffeemaschine
- 📸 **Foto-Beweis**: Mach ein Foto vom ausgeschalteten Gerät
- 🕐 **Automatischer Zeitstempel**: Sieh genau wann das Foto gemacht wurde
- 🗑️ **Auto-Delete nach 24h**: Fotos löschen sich automatisch
- 🔒 **100% offline & lokal**: Keine Cloud, kein Internet nötig
- ➕ **Eigene Checks**: Füge beliebige eigene Panik-Ziele hinzu
- 🌙 **Dark Mode**: Automatisch je nach System-Einstellung

---

## 📁 Projektstruktur

```
habich/
├── lib/
│   └── main.dart          # Komplette App-Logik
├── android/               # Android-spezifische Dateien
├── .github/
│   └── workflows/
│       └── build-apk.yml  # Automatischer APK-Build
└── pubspec.yaml           # Dependencies
```
