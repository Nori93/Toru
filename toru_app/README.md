# Toru - Cross-Platform Offline AI Assistant

A powerful, fully offline AI assistant application that works on both Android and Windows platforms. Built with Flutter, featuring local LLM capabilities, smart reminders, memory management, and optional cloud sync.

![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## 🌟 Features

### ✅ Core Features

- **🤖 Local AI Assistant**: Fully offline LLM using llama.cpp
- **💾 Memory System**: Store and recall notes, facts, and information
- **⏰ Smart Reminders**: Local notifications with recurring alarms
- **🗺️ Navigation**: Online maps with offline saved routes
- **☁️ Optional Cloud Sync**: Firebase/Supabase integration
- **🎯 Clean Architecture**: MVVM pattern with separation of concerns
- **🌙 Dark Mode**: Automatic theme switching
- **📱 Cross-Platform**: Single codebase for Android and Windows

### 🎁 Bonus Features

- **🎤 Voice Input**: Speech-to-text capabilities (coming soon)
- **🔍 Semantic Search**: Find relevant memories using embeddings
- **🔄 Background Processing**: AI processing in background
- **📊 Dashboard**: Today's schedule and quick actions

## 🏗️ Architecture

The application follows Clean Architecture principles with MVVM pattern:

```
toru_app/
├── lib/
│   ├── core/
│   │   ├── constants/        # App-wide constants and themes
│   │   ├── services/         # Core services (AI, Database, Notifications, Sync)
│   │   └── utils/            # Utility functions
│   ├── data/
│   │   ├── models/           # Data models
│   │   ├── repositories/     # Repository implementations
│   │   └── datasources/      # Local and remote data sources
│   ├── domain/
│   │   ├── entities/         # Business entities
│   │   ├── usecases/         # Business logic
│   │   └── repositories/     # Repository interfaces
│   └── presentation/
│       ├── screens/          # UI screens
│       ├── widgets/          # Reusable widgets
│       └── viewmodels/       # State management (MVVM)
├── android/                  # Android-specific configuration
├── windows/                  # Windows-specific configuration
└── assets/                   # Images, models, fonts
```

### 📐 Architecture Layers

1. **Presentation Layer** (`presentation/`)
   - UI components (Screens, Widgets)
   - ViewModels for state management
   - User input handling

2. **Domain Layer** (`domain/`)
   - Business entities
   - Use cases (business logic)
   - Repository interfaces

3. **Data Layer** (`data/`)
   - Repository implementations
   - Data models
   - Local database (SQLite)
   - Remote data sources

4. **Core Layer** (`core/`)
   - Services (AI, Database, Notifications, Sync)
   - Utilities and helpers
   - Constants and configuration

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.0 or higher
- Android Studio / VS Code with Flutter extensions
- For Android: Android SDK 24+
- For Windows: Visual Studio 2022 with C++ tools
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Nori93/Toru.git
   cd Toru/toru_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**

   For Android:
   ```bash
   flutter run -d android
   ```

   For Windows:
   ```bash
   flutter run -d windows
   ```

### 🤖 Local AI Setup (llama.cpp Integration)

The app is designed to use llama.cpp for offline AI inference. To integrate:

1. **Download a model**
   - Download a GGUF format model (e.g., Phi-3, Mistral, Llama)
   - Recommended: Phi-3-mini-4k-instruct (lightweight, good performance)
   - Place in `assets/models/toru-model.gguf`

2. **Add llama.cpp bindings**

   For Android:
   ```bash
   # Add llama.cpp native library to android/app/src/main/jniLibs/
   # Build llama.cpp for Android using NDK
   ```

   For Windows:
   ```bash
   # Add llama.cpp DLL to windows/runner/
   # Or use llama_cpp_dart package
   ```

3. **Update AI Service**
   
   The `AIService` in `lib/core/services/ai_service.dart` contains placeholders for llama.cpp integration. Replace the simulated inference with actual llama.cpp calls:

   ```dart
   // Example integration
   import 'package:llama_cpp_dart/llama_cpp_dart.dart';
   
   class AIService {
     LlamaContext? _llamaContext;
     
     Future<void> initialize() async {
       _llamaContext = await LlamaCpp.initialize(
         modelPath: await _getModelPath(),
         contextSize: 2048,
         numThreads: 4,
       );
     }
     
     Future<String> generateResponse(String prompt) async {
       return await _llamaContext!.generate(
         prompt: prompt,
         maxTokens: 256,
         temperature: 0.7,
       );
     }
   }
   ```

### 🔧 Configuration

#### Firebase/Supabase Setup (Optional)

1. **Firebase**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools
   
   # Login to Firebase
   firebase login
   
   # Initialize Firebase in your project
   flutterfire configure
   ```

2. **Update configuration**
   - Add `google-services.json` to `android/app/`
   - Update `lib/main.dart` to initialize Firebase

#### Notification Configuration

Notifications are pre-configured in the manifest. For custom sounds or channels, modify:
- Android: `android/app/src/main/res/raw/` for custom sounds
- iOS: Update `ios/Runner/Info.plist` if adding iOS support

## 📚 Usage Examples

### Using the AI Assistant

```dart
// Chat with the AI
final chatViewModel = context.read<ChatViewModel>();
await chatViewModel.sendMessage("Remember my doctor appointment is Monday at 10");

// The AI will automatically extract and store the information
```

### Creating Reminders

```dart
// Add a reminder
final reminderViewModel = context.read<ReminderViewModel>();
await reminderViewModel.addReminder(
  title: 'Team Meeting',
  description: 'Weekly standup',
  time: DateTime(2024, 1, 15, 10, 0),
  isRecurring: true,
  recurrencePattern: 'weekly',
  category: 'work',
);
```

### Storing Memories

```dart
// Add a memory/note
final memoryViewModel = context.read<MemoryViewModel>();
await memoryViewModel.addMemory(
  type: 'note',
  title: 'Project Idea',
  content: 'Build a cross-platform AI assistant...',
  tags: ['ideas', 'projects'],
  importance: 8,
);

// Search memories
await memoryViewModel.searchMemories('project');
```

### Syncing Data

```dart
// Configure cloud sync
final syncService = context.read<SyncService>();
syncService.configureCloudBackend(
  url: 'https://your-backend.com',
  authToken: 'your-auth-token',
);

// Sync will happen automatically when online
```

## 🗄️ Database Schema

The app uses SQLite with the following main tables:

- **chat_messages**: Conversation history
- **memories**: Notes, facts, and information
- **appointments**: Scheduled events
- **reminders**: Alarms and recurring reminders
- **saved_routes**: Navigation routes
- **sync_queue**: Offline-first sync queue

## 🎨 Customization

### Themes

Edit `lib/core/constants/app_theme.dart` to customize colors and styling:

```dart
static const Color primaryColor = Color(0xFF6366F1); // Change primary color
static const Color secondaryColor = Color(0xFF8B5CF6); // Change secondary color
```

### AI Model

Replace the default model by:
1. Downloading a different GGUF model
2. Placing it in `assets/models/`
3. Updating the model path in `ai_service.dart`

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test/
```

## 📦 Building

### Android APK

```bash
flutter build apk --release
```

### Android App Bundle

```bash
flutter build appbundle --release
```

### Windows

```bash
flutter build windows --release
```

## 🔐 Security & Privacy

- **Offline-First**: All data stored locally by default
- **Optional Sync**: Cloud sync is completely optional
- **Local AI**: No API calls required for AI functionality
- **Data Control**: Users have full control over their data
- **Encryption**: Consider adding database encryption for sensitive data

## 🐛 Troubleshooting

### Common Issues

**1. Build fails on Android**
- Ensure Android SDK is properly installed
- Check `minSdkVersion` is 24 or higher
- Run `flutter doctor` to check for issues

**2. Notifications not working**
- Grant notification permissions in app settings
- Check that notification channels are properly configured

**3. AI responses are slow**
- Use a smaller model (Phi-3-mini recommended)
- Reduce context size in AI service
- Ensure device has sufficient RAM

**4. Database errors**
- Clear app data and reinstall
- Check file permissions
- Verify SQLite installation

## 🚧 Roadmap

- [ ] iOS support
- [ ] Voice input implementation
- [ ] Offline maps download
- [ ] Widget support (Android)
- [ ] Background AI processing
- [ ] Model selection UI
- [ ] Export/import data
- [ ] End-to-end encryption

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👏 Acknowledgments

- **Flutter Team**: For the amazing cross-platform framework
- **llama.cpp**: For making local LLM inference possible
- **Ollama**: For inspiration on local AI architecture
- **Community**: For various open-source packages used

## 📞 Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Contact: [GitHub Issues](https://github.com/Nori93/Toru/issues)

## 📖 Documentation

For detailed documentation:
- [Architecture Guide](docs/ARCHITECTURE.md)
- [API Reference](docs/API.md)
- [Contributing Guide](docs/CONTRIBUTING.md)

---

**Made with ❤️ using Flutter**

*Toru - Your Offline AI Assistant*
