# Toru - Cross-Platform AI Assistant

A powerful offline AI assistant that runs on Android and Windows, featuring local LLM capabilities, memory management, smart reminders, and optional cloud synchronization.

## 📁 Repository Structure

This repository contains two main components:

### 1. **Python Backend** (Root Directory)
Legacy Python-based AI assistant using Ollama for local inference.
- `brain.py` - Core AI logic
- `voice.py` - Voice synthesis
- `avatar.py` - Avatar display
- Docker setup for microservices

### 2. **Flutter Mobile/Desktop App** (`toru_app/`)
**NEW**: Cross-platform application for Android and Windows.

🎯 **Recommended**: Use the Flutter app for the full cross-platform experience!

## 🚀 Quick Start

### Flutter App (Recommended)

```bash
cd toru_app
flutter pub get
flutter run
```

See [toru_app/README.md](toru_app/README.md) for complete documentation.

### Python Backend (Legacy)

```bash
pip install -r requirements.txt
python main.py
```

## 🌟 Key Features

### Flutter App Features
✅ **Fully Offline** - Works without internet connection  
✅ **Local AI** - On-device LLM using llama.cpp  
✅ **Cross-Platform** - Android + Windows from single codebase  
✅ **Smart Reminders** - Recurring alarms and notifications  
✅ **Memory System** - Store and recall information  
✅ **Optional Sync** - Cloud backup when online  
✅ **Clean Architecture** - MVVM pattern, easy to maintain  

### Python Backend Features
- Ollama integration for LLM inference
- Text-to-speech with Piper
- Visual avatar with mouth sync
- Docker microservices architecture

## 📱 Platforms Supported

| Platform | Flutter App | Python Backend |
|----------|-------------|----------------|
| Android  | ✅ Yes      | ❌ No          |
| Windows  | ✅ Yes      | ✅ Yes         |
| Linux    | 🚧 Planned  | ✅ Yes         |
| iOS      | 🚧 Planned  | ❌ No          |
| macOS    | 🚧 Planned  | ✅ Yes         |

## 🏗️ Architecture

### Flutter App Architecture

```
Presentation Layer (UI)
    ↓
ViewModels (State Management)
    ↓
Domain Layer (Business Logic)
    ↓
Data Layer (Repositories)
    ↓
Services (AI, Database, Sync, Notifications)
```

**Key Services:**
- **AIService**: Local LLM inference with llama.cpp
- **DatabaseService**: SQLite for local storage
- **NotificationService**: Local alarms and reminders
- **SyncService**: Optional cloud synchronization

### Python Backend Architecture

```
Gateway → AI Brain → Ollama LLM
       ↓
    TTS Service → Piper
       ↓
    Avatar Display
```

## 🤖 AI Models

### Flutter App
- **Recommended**: Phi-3-mini (lightweight, efficient)
- **Alternatives**: Mistral 7B, Llama 2 7B
- **Format**: GGUF (quantized for mobile)
- **Size**: 2-4 GB recommended for mobile

### Python Backend
- Uses Ollama models
- Default: reefer/erphermesl3
- Any Ollama-compatible model works

## 📊 Comparison

| Feature | Flutter App | Python Backend |
|---------|-------------|----------------|
| Mobile Support | ✅ | ❌ |
| Desktop Support | ✅ | ✅ |
| Offline AI | ✅ | ✅ |
| Memory System | ✅ | Basic |
| Reminders | ✅ | ❌ |
| Cloud Sync | ✅ | ❌ |
| Voice Input | 🚧 | ✅ |
| Avatar | ❌ | ✅ |

## 🛠️ Development Setup

### Flutter App Setup

1. **Install Flutter**
   ```bash
   # Download from https://flutter.dev
   flutter doctor
   ```

2. **Clone and Setup**
   ```bash
   git clone https://github.com/Nori93/Toru.git
   cd Toru/toru_app
   flutter pub get
   ```

3. **Run**
   ```bash
   flutter run -d android  # For Android
   flutter run -d windows  # For Windows
   ```

### Python Backend Setup

1. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

2. **Install Ollama**
   ```bash
   # Download from https://ollama.ai
   ollama pull reefer/erphermesl3
   ```

3. **Run**
   ```bash
   python main.py
   ```

## 📚 Documentation

- **Flutter App**: [toru_app/README.md](toru_app/README.md)
- **Architecture**: [toru_app/docs/ARCHITECTURE.md](toru_app/docs/ARCHITECTURE.md)
- **API Reference**: [toru_app/docs/API.md](toru_app/docs/API.md)

## 🎯 Roadmap

### Flutter App
- [ ] iOS support
- [ ] Voice input implementation
- [ ] Offline maps download
- [ ] Widget support
- [ ] Model selection UI

### Python Backend
- [ ] Web interface
- [ ] Multi-user support
- [ ] Plugin system

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- llama.cpp for enabling local LLM inference
- Ollama for inspiration and model hosting
- Community contributors

## 📞 Contact

- GitHub Issues: [Report a bug](https://github.com/Nori93/Toru/issues)
- Discussions: [Join the discussion](https://github.com/Nori93/Toru/discussions)

---

**Choose your path:**
- 📱 **Mobile/Desktop User?** → Use the Flutter app in `toru_app/`
- 🖥️ **Desktop Power User?** → Try the Python backend
- 👨‍💻 **Developer?** → Contribute to either or both!

*Made with ❤️ for the AI enthusiast community*
