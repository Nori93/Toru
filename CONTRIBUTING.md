# Contributing to Toru

Thank you for considering contributing to Toru! This document provides guidelines and instructions for contributing.

## 🎯 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce**
- **Expected vs actual behavior**
- **Screenshots** (if applicable)
- **Environment details** (OS, Flutter version, device)

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- **Clear use case**
- **Expected behavior**
- **Why this would be useful**
- **Possible implementation approach**

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Follow the code style** (see below)
4. **Write tests** for new functionality
5. **Update documentation** as needed
6. **Commit with clear messages**
7. **Push to your fork**
8. **Open a Pull Request**

## 📝 Code Style Guidelines

### Dart/Flutter

Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style):

```dart
// Good
class MyWidget extends StatelessWidget {
  final String title;
  
  const MyWidget({
    super.key,
    required this.title,
  });
  
  @override
  Widget build(BuildContext context) {
    return Text(title);
  }
}

// Bad
class myWidget extends StatelessWidget {
  String title;
  myWidget(this.title);
  Widget build(context) => Text(title);
}
```

### Formatting

Use `dart format`:

```bash
dart format lib/ test/
```

### Linting

Fix all lint warnings:

```bash
flutter analyze
```

## 🧪 Testing

### Running Tests

```bash
# All tests
flutter test

# Specific test
flutter test test/services/ai_service_test.dart

# With coverage
flutter test --coverage
```

### Writing Tests

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MyService', () {
    late MyService service;
    
    setUp(() {
      service = MyService();
    });
    
    test('does something correctly', () {
      expect(service.doSomething(), isTrue);
    });
  });
}
```

## 📚 Documentation

- Update README.md for user-facing changes
- Update inline documentation for code changes
- Add examples for new features
- Update architecture docs if structure changes

## 🏗️ Architecture Guidelines

### MVVM Pattern

```dart
// ViewModel - handles business logic
class MyViewModel extends ChangeNotifier {
  final MyService _service;
  
  Future<void> doSomething() async {
    final result = await _service.process();
    notifyListeners();
  }
}

// Screen - handles UI only
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<MyViewModel>(
      builder: (context, viewModel, child) {
        return Text('Result: ${viewModel.result}');
      },
    );
  }
}
```

### Service Layer

```dart
// Service - handles external dependencies
class MyService {
  final Database _db;
  
  Future<Data> fetchData() async {
    return await _db.query('SELECT * FROM table');
  }
}
```

## 🔄 Git Workflow

### Branch Naming

- `feature/feature-name` - New features
- `fix/bug-description` - Bug fixes
- `docs/update-readme` - Documentation
- `refactor/improve-code` - Code improvements

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add voice input support
fix: resolve notification timing issue
docs: update installation instructions
refactor: improve AI service performance
test: add integration tests for chat
```

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
```

## 🚀 Development Setup

### Prerequisites

```bash
# Install Flutter
# See: https://flutter.dev/docs/get-started/install

# Verify installation
flutter doctor

# Get dependencies
cd toru_app
flutter pub get
```

### Running the App

```bash
# Android
flutter run -d android

# Windows
flutter run -d windows

# With hot reload enabled
flutter run --hot
```

## 📱 Platform-Specific Contributions

### Android

- Test on multiple devices/emulators
- Check API level compatibility (min SDK 24)
- Verify permissions work correctly

### Windows

- Test on Windows 10/11
- Check file path handling
- Verify native integrations

## 🤖 AI/ML Contributions

### Model Integration

- Test with multiple model sizes
- Benchmark performance
- Document memory requirements
- Provide quantization options

### Testing AI Features

- Test with various prompts
- Check context management
- Verify memory usage
- Test offline functionality

## 🔐 Security Guidelines

- Never commit API keys or secrets
- Encrypt sensitive data
- Validate user input
- Follow security best practices
- Report security issues privately

## ❓ Questions?

- Open a discussion on GitHub
- Check existing issues and PRs
- Read the documentation
- Ask in pull request comments

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🙏 Thank You!

Your contributions make Toru better for everyone. We appreciate your time and effort!

---

**Happy Contributing! 🎉**
