# FinFit

**FinFit** is a cross-platform application built with Flutter to help users manage and improve their wellness and finances. It integrates personal health tracking, nutrition, workout routines, and expense management in one place.

---

## 🌟 Features

- **Personal Dashboard:** View your daily and weekly nutrition, workouts, expenses, and income.
- **User Authentication:** Secure login and personalized data storage.
- **Health Tracking:** Track water intake, protein needs, TDEE (Total Daily Energy Expenditure), and more.
- **Expense Management:** Monitor weekly expenses, monthly income, and get reminders for upcoming bills.
- **Cross-Platform:** Runs on Windows, Linux, and Web (with Flutter support for each).

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK:** [Install Flutter](https://docs.flutter.dev/get-started/install) (ensure it’s in your PATH)
- **Dart SDK:** Comes with Flutter
- **Git:** For cloning the repository

### Clone the Repository

```bash
git clone https://github.com/alen217/FinFit.git
cd FinFit
```

---

## 🖥️ Running on Different Platforms

### 📱 Android / iOS

1. Ensure you have Android Studio or Xcode set up.
2. Run on device or emulator:

   ```bash
   flutter run
   ```

### 💻 Windows

1. Make sure you have Visual Studio (with Desktop development with C++) installed.
2. Build and run:

   ```bash
   flutter run -d windows
   ```

### 🐧 Linux

1. Install required dependencies (GTK, CMake, clang, etc.).
2. Build and run:

   ```bash
   flutter run -d linux
   ```

   > **Tip:** If you are running for the first time, you may need to enable Linux desktop support:
   > ```bash
   > flutter config --enable-linux-desktop
   > ```

### 🌐 Web

1. Make sure you have Chrome or another modern browser.
2. Run the app in your browser:

   ```bash
   flutter run -d chrome
   ```

---

## 🛠️ Build & Release

- **Build for Windows:**
  ```bash
  flutter build windows
  ```
- **Build for Linux:**
  ```bash
  flutter build linux
  ```
- **Build for Web:**
  ```bash
  flutter build web
  ```

Artifacts will be available in the `build/` directory for each platform.

---

## 📚 Documentation & Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

---

## 📝 License

Distributed under the MIT License.

---

> For help getting started with Flutter development, view the [online documentation](https://docs.flutter.dev/), which offers tutorials, samples, guidance on mobile development, and a full API reference.
