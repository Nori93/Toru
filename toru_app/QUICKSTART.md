# Quick Start Guide - Toru AI Assistant

Get up and running with Toru in 5 minutes!

## 📋 Prerequisites

- Flutter SDK 3.0+ ([Install Flutter](https://flutter.dev/docs/get-started/install))
- Android Studio (for Android) or Visual Studio 2022 (for Windows)
- Git

## 🚀 Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/Nori93/Toru.git
cd Toru/toru_app
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

### Step 3: Run the App

**For Android:**
```bash
flutter run -d android
```

**For Windows:**
```bash
flutter run -d windows
```

That's it! The app will run with simulated AI responses.

## 🤖 Adding Real AI (Optional)

To enable real local AI:

### Option 1: Quick Test (Simulated)

The app works out of the box with simulated AI responses for testing.

### Option 2: Real AI Integration

1. **Download a model** (choose one):
   - Phi-3-mini: ~2.3 GB (recommended for mobile)
   - Mistral 7B: ~4 GB
   - Download from [Hugging Face](https://huggingface.co/models?library=gguf)

2. **Place the model**:
   ```bash
   mkdir -p assets/models
   # Copy your .gguf file to assets/models/toru-model.gguf
   ```

3. **Follow integration guide**:
   See [docs/LLAMA_CPP_INTEGRATION.md](docs/LLAMA_CPP_INTEGRATION.md)

## 📱 First Run

When you first run the app, you'll see:

1. **Dashboard**: Overview of your day
2. **Chat**: Talk to Toru AI
3. **Memories**: Store notes and information
4. **Reminders**: Set alarms and notifications
5. **Transport**: Save and view routes

## 💡 Try These Features

### Chat with AI
1. Open the Chat tab
2. Type "Hello, who are you?"
3. See Toru's response

### Create a Reminder
1. Go to Reminders tab
2. Tap the + button
3. Set a reminder for tomorrow
4. You'll get a notification!

### Store a Memory
1. Open Memories tab
2. Tap the + button
3. Add a note about something important

## 🔧 Configuration

### Enable Cloud Sync (Optional)

Currently set to local-only mode. To enable sync:

1. Set up Firebase or Supabase
2. Update configuration in `lib/main.dart`
3. Sync will happen automatically when online

### Change Theme

The app automatically uses your system theme (light/dark).

## 🐛 Troubleshooting

### "flutter: command not found"
```bash
# Install Flutter from https://flutter.dev
# Add to PATH
export PATH="$PATH:`pwd`/flutter/bin"
```

### Build fails
```bash
# Check Flutter installation
flutter doctor

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Notifications not working
- Grant notification permissions in app settings
- For Android 13+, approve notification permission

## 📚 Next Steps

- Read the [full README](README.md)
- Check [Architecture docs](docs/ARCHITECTURE.md)
- Set up [llama.cpp](docs/LLAMA_CPP_INTEGRATION.md)
- Customize the app for your needs

## 🤝 Need Help?

- [GitHub Issues](https://github.com/Nori93/Toru/issues)
- [Documentation](docs/)
- [Contributing Guide](../CONTRIBUTING.md)

## 🎉 You're Ready!

Start chatting with Toru and explore the features. Enjoy your offline AI assistant!

---

Made with ❤️ using Flutter
