# llama.cpp Integration Guide

This guide explains how to integrate llama.cpp with the Toru Flutter application for local AI inference.

## Overview

llama.cpp is a C++ library that enables running Large Language Models locally with high performance. This guide covers integration for both Android and Windows platforms.

## Prerequisites

- Flutter SDK 3.0+
- Android NDK (for Android)
- CMake (for native compilation)
- Git

## Option 1: Using llama_cpp_dart Package (Recommended)

### Installation

1. Add to `pubspec.yaml`:
```yaml
dependencies:
  llama_cpp_dart: ^0.1.0
```

2. Run:
```bash
flutter pub get
```

3. Update `ai_service.dart`:
```dart
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
      topP: 0.9,
    );
  }
}
```

## Option 2: Native Integration via FFI

### For Android

1. **Build llama.cpp for Android**:

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build-android && cd build-android

cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-24 \
  -DBUILD_SHARED_LIBS=ON

make -j4
```

2. **Copy libraries to Flutter**:

```bash
mkdir -p android/app/src/main/jniLibs/arm64-v8a
cp libllama.so android/app/src/main/jniLibs/arm64-v8a/
```

3. **Create FFI bindings**:

```dart
// lib/core/services/llama_ffi.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

class LlamaFFI {
  late DynamicLibrary _dylib;
  
  LlamaFFI() {
    if (Platform.isAndroid) {
      _dylib = DynamicLibrary.open('libllama.so');
    } else if (Platform.isWindows) {
      _dylib = DynamicLibrary.open('llama.dll');
    }
  }
  
  late final _llamaInit = _dylib
      .lookup<NativeFunction<Pointer<Void> Function(Pointer<Utf8>)>>('llama_init')
      .asFunction<Pointer<Void> Function(Pointer<Utf8>)>();
  
  late final _llamaGenerate = _dylib
      .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>)>>('llama_generate')
      .asFunction<Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>)>();
  
  Pointer<Void> initialize(String modelPath) {
    final pathPtr = modelPath.toNativeUtf8();
    final ctx = _llamaInit(pathPtr);
    malloc.free(pathPtr);
    return ctx;
  }
  
  String generate(Pointer<Void> context, String prompt) {
    final promptPtr = prompt.toNativeUtf8();
    final resultPtr = _llamaGenerate(context, promptPtr);
    final result = resultPtr.toDartString();
    malloc.free(promptPtr);
    return result;
  }
}
```

### For Windows

1. **Build llama.cpp**:

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build && cd build
cmake ..
cmake --build . --config Release
```

2. **Copy DLL**:

```bash
cp Release/llama.dll windows/runner/
```

3. Use the same FFI bindings as Android.

## Downloading Models

### Recommended Models

1. **Phi-3-mini (Recommended for mobile)**
   - Size: ~2.3 GB (Q4 quantization)
   - Performance: Excellent on mobile
   - Download: https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf

2. **Mistral 7B**
   - Size: ~4.1 GB (Q4 quantization)
   - Performance: Good for desktop
   - Download: https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF

3. **Llama 2 7B**
   - Size: ~3.8 GB (Q4 quantization)
   - Performance: Good all-around
   - Download: https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF

### Download and Setup

```bash
# Create models directory
mkdir -p assets/models

# Download model (example with wget)
wget https://huggingface.co/.../model.gguf -O assets/models/toru-model.gguf
```

### Model Placement

For production apps, place models in:
- Android: `getApplicationDocumentsDirectory()/models/`
- Windows: `getApplicationSupportDirectory()/models/`

Update `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/models/
```

## Performance Optimization

### Context Size

Smaller context = faster inference:
```dart
LlamaCpp.initialize(
  modelPath: modelPath,
  contextSize: 1024,  // Reduce for faster performance
  numThreads: 4,      // Use available CPU cores
);
```

### Quantization

Use quantized models for better performance:
- Q4_0: ~4 GB, good balance
- Q5_1: ~5 GB, better quality
- Q8_0: ~8 GB, near-original quality

### Batch Size

Process multiple prompts together:
```dart
final responses = await Future.wait([
  aiService.generateResponse(prompt1),
  aiService.generateResponse(prompt2),
]);
```

## Testing Integration

Create a test file `test/ai_service_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:toru_app/core/services/ai_service.dart';

void main() {
  group('AIService', () {
    late AIService aiService;
    
    setUp(() {
      aiService = AIService();
    });
    
    test('initializes successfully', () async {
      await aiService.initialize();
      expect(aiService.isInitialized, true);
    });
    
    test('generates response', () async {
      await aiService.initialize();
      final response = await aiService.generateResponse('Hello');
      expect(response, isNotEmpty);
    });
  });
}
```

## Troubleshooting

### Model Loading Fails

- Check file permissions
- Verify model file integrity
- Ensure sufficient storage space

### Slow Inference

- Use smaller model
- Reduce context size
- Enable GPU acceleration (if available)

### Out of Memory

- Use more aggressive quantization (Q4_0)
- Reduce context size
- Close other apps

### Android Native Library Not Found

```bash
# Verify library is in correct location
find android/app/src/main/jniLibs -name "*.so"

# Check ABI compatibility
adb shell getprop ro.product.cpu.abi
```

## Example: Complete Integration

```dart
// lib/core/services/ai_service.dart
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class AIService {
  LlamaContext? _llamaContext;
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    try {
      final modelPath = await _getModelPath();
      
      _llamaContext = await LlamaCpp.initialize(
        modelPath: modelPath,
        contextSize: 2048,
        numThreads: 4,
        useGpu: false,
      );
      
      _isInitialized = true;
      print('✅ AI Service initialized');
    } catch (e) {
      print('❌ Failed to initialize AI Service: $e');
      rethrow;
    }
  }
  
  Future<String> generateResponse(
    String prompt, {
    List<String>? context,
  }) async {
    if (!_isInitialized) {
      throw StateError('AI Service not initialized');
    }
    
    final fullPrompt = _buildPromptWithContext(prompt, context);
    
    final response = await _llamaContext!.generate(
      prompt: fullPrompt,
      maxTokens: 256,
      temperature: 0.7,
      topP: 0.9,
      repeatPenalty: 1.1,
    );
    
    return response;
  }
  
  String _buildPromptWithContext(String prompt, List<String>? context) {
    final buffer = StringBuffer();
    buffer.writeln('System: You are Toru, a helpful AI assistant.');
    
    if (context != null && context.isNotEmpty) {
      buffer.writeln('\\nContext:');
      for (var item in context) {
        buffer.writeln('- $item');
      }
    }
    
    buffer.writeln('\\nUser: $prompt');
    buffer.write('Assistant:');
    
    return buffer.toString();
  }
  
  Future<String> _getModelPath() async {
    // Implementation depends on storage strategy
    return 'path/to/model.gguf';
  }
  
  bool get isInitialized => _isInitialized;
  
  void dispose() {
    _llamaContext?.dispose();
  }
}
```

## Resources

- [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)
- [Hugging Face Models](https://huggingface.co/models?library=gguf)
- [Flutter FFI Guide](https://dart.dev/guides/libraries/c-interop)
- [Android NDK Documentation](https://developer.android.com/ndk)

## Next Steps

1. Download a model
2. Integrate llama.cpp
3. Test on device
4. Optimize performance
5. Deploy to production

Good luck with your integration! 🚀
