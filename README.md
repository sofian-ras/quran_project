# Quran Flutter App

A mobile app for reading the Holy Quran with **Hafs & Warsh scripts**, developed with **Flutter** and **Dart**.

---

## 📝 Features

* Read the Quran in **Hafs** and **Warsh** scripts.
* Display of **page numbers**, **hizb**, and **juzz** in real time.
* **Reverse page navigation** (from page 604 to 1).
* Quick **Surah selection** with Arabic and French names.
* Uses classic Quran **fonts** for an authentic reading experience.
* Works completely **offline**, no internet required.

---

## 💻 Project Structure

```
lib/          -> Main Flutter code (main.dart, hizb_juzz.dart, surah_name.dart)
assets/       -> Mushaf images, fonts, and database
android/      -> Android build files
pubspec.yaml  -> Dependencies and assets
```

**Optional / Development-only directories** (not needed for release / Play Store build):

```
.vscode/
.idea/
build/
windows/
macos/
linux/
web/
test/
.dart_tool/
```

---

## 🚀 Getting Started

1. Clone the repo:

```bash
git clone <your-repo-url>
cd quran
```

2. Install dependencies:

```bash
flutter pub get
```

3. Run on an Android device or emulator:

```bash
flutter run
```

---

## 📂 Assets

* `assets/mushaf/hafs` → Hafs Mushaf images
* `assets/mushaf/warsh` → Warsh Mushaf images
* `assets/data/quran_data.json` → Surah/page mapping
* `assets/data/ayahinfo_1120.db` → Quran metadata
* `assets/fonts/` → Custom Quran fonts

---

## 🛠️ Tools

* Flutter 3.13+
* Dart 3+
* Android Studio or VS Code

---

## 🤝 Contributing

Contributions are welcome! Please open an issue or submit a pull request for:

* Bug fixes
* UI improvements
* Adding features or fonts

---

## 📜 License

*(Add your license here, e.g., MIT, Apache 2.0, etc.)*

---

💡 **Tip:** You can also add screenshots in your GitHub README for clarity:

```markdown
![Hafs view](assets/screenshots/hafs.png)
![Warsh view](assets/screenshots/warsh.png)
```