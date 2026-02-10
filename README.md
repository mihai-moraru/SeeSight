# SeeSight

**On-device AI vision for iOS — powered by Apple's [FastVLM](https://github.com/apple/ml-fastvlm) and Flutter.**

SeeSight is an open-source Flutter iOS app that runs a Vision-Language Model entirely on-device using Apple's MLX framework and Neural Engine. Point your camera at anything and get instant AI-powered descriptions, text recognition, object counting, and more — with zero cloud dependency.

<p align="center">
  <img src="assets/logo.png" width="120" alt="SeeSight logo" />
</p>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🎥 **Live Mode** | Continuous real-time camera analysis with adaptive frame rate |
| 📸 **Photo Mode** | Capture a single frame and analyze it |
| ⚡ **TTFT Display** | See time-to-first-token for every inference |
| 🔒 **100% On-Device** | No network calls — all processing stays on your iPhone |
| 🎨 **Glassmorphic UI** | Modern frosted-glass design with smooth animations |
| 💬 **Custom Prompts** | Quick prompt pills + editable prompt field |
| 🌓 **Theming** | Auto / Light / Dark mode |
| 📷 **Camera Selection** | Front or back camera with live switching |
| 📝 **Markdown Responses** | AI responses rendered with full Markdown support |

### Built-in Quick Prompts

- **Describe** — General scene description
- **Count** — Object counting
- **Read Text** — OCR / text recognition
- **Colors** — Dominant color detection
- **Emotion** — Facial expression analysis

---

## 📱 Requirements

| Requirement | Minimum |
|-------------|---------|
| **iOS** | 18.2+ (required for MLX framework) |
| **Device** | iPhone with A14 Bionic or later (Neural Engine) |
| **Xcode** | 16.0+ |
| **Flutter** | 3.2.0+ |
| **Disk Space** | ~1 GB for the 0.5B model (see [Model Options](#-model-options)) |

---

## 🚀 Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/anthropics/seesight.git
cd seesight
```

### 2. Download a FastVLM model

```bash
chmod +x get_pretrained_model.sh
./get_pretrained_model.sh --model 0.5b    # Recommended for mobile
```

See [Model Options](#-model-options) for all available sizes.

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Add the model to Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Right-click the **Runner** folder → **Add Files to "Runner"…**
3. Select the `ios/Runner/model` folder
4. Enable **"Create folder references"** and add to the **Runner** target

### 5. Add Swift Package dependencies

In Xcode → **File → Add Package Dependencies…** and add:

| Package | URL | Version |
|---------|-----|---------|
| **mlx-swift** | `https://github.com/ml-explore/mlx-swift.git` | `0.21.2+` |
| **mlx-swift-lm** | `https://github.com/ml-explore/mlx-swift-lm.git` | `0.21.2+` |

From **mlx-swift-lm**, add the products **MLXLMCommon** and **MLXVLM** to the Runner target.

### 6. Configure build settings

In Xcode, select the **Runner** target and verify:

| Setting | Value |
|---------|-------|
| iOS Deployment Target | `18.2` |
| Swift Language Version | `5.0` |
| Build Active Architecture Only (Release) | `Yes` |

### 7. Build and run

```bash
flutter run --release
```

> **Note:** Use a physical device — the Simulator doesn't support Neural Engine acceleration.

---

## 🧠 Model Options

Three pre-exported MLX models are available from [Apple's CDN](https://github.com/apple/ml-fastvlm):

| Model | Params | Quantization | Size (approx.) | Best For |
|-------|--------|-------------|-----------------|----------|
| **0.5B** | 0.5 billion | FP16 | ~1 GB | Real-time on any device |
| **1.5B** | 1.5 billion | INT8 | ~1.5 GB | Balanced speed & accuracy |
| **7B** | 7 billion | INT4 | ~4 GB | Maximum accuracy |

Download any model with the included script:

```bash
./get_pretrained_model.sh --model 0.5b   # Small and fast
./get_pretrained_model.sh --model 1.5b   # Balanced
./get_pretrained_model.sh --model 7b     # Most accurate
```

You can also specify a custom destination:

```bash
./get_pretrained_model.sh --model 1.5b --dest /path/to/output
```

Each model zip contains:

| File | Purpose |
|------|---------|
| `config.json` | Model architecture definition |
| `model.safetensors` | LLM weights |
| `fastvithd.mlpackage/` | CoreML vision encoder |
| `tokenizer.json` + related | Tokenizer vocabulary |
| `preprocessor_config.json` | Image preprocessing config |

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────┐
│                  Flutter UI                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │HomeScreen│ │ Settings │ │  Widgets (glass,  │ │
│  │          │ │  Screen  │ │  bottom sheet,    │ │
│  │          │ │          │ │  mode toggle, …)  │ │
│  └────┬─────┘ └──────────┘ └──────────────────┘ │
│       │                                          │
│  ┌────┴────────────────────────────────────────┐ │
│  │  Riverpod Services (camera, VLM, app state) │ │
│  └────┬────────────────────────────────────────┘ │
├───────┼──────────────────────────────────────────┤
│       │  MethodChannel / EventChannel            │
├───────┼──────────────────────────────────────────┤
│  ┌────┴──────────┐  ┌────────────────────────┐   │
│  │FastVLMPlugin  │──│  FastVLMModel          │   │
│  │(bridge)       │  │  (load, generate,      │   │
│  │               │  │   stream)              │   │
│  └───────────────┘  └────────┬───────────────┘   │
│                              │                    │
│  ┌───────────────────────────┴──────────────────┐ │
│  │  FastVLM / FastViTHD (MLX + CoreML)          │ │
│  │  Apple Neural Engine                          │ │
│  └───────────────────────────────────────────────┘ │
│                  Native iOS                       │
└─────────────────────────────────────────────────┘
```

### Communication Flow

```
Camera Frame → Dart (adaptive frame skip) → MethodChannel → Swift Plugin
    → FastVLMModel → MLX Inference (Neural Engine) → Response
    → EventChannel (streaming tokens) → Dart → Markdown UI
```

### Project Structure

```
seesight/
├── lib/
│   ├── main.dart                          # App entry point + theme
│   ├── screens/
│   │   ├── home_screen.dart               # Main camera + VLM screen
│   │   └── settings_screen.dart           # Settings, about, easter egg
│   ├── services/
│   │   ├── vlm_service.dart               # VLM MethodChannel service (Riverpod)
│   │   ├── camera_service.dart            # Camera lifecycle + adaptive frame rate
│   │   ├── app_state.dart                 # App state, errors, combined providers
│   │   └── settings_service.dart          # Theme & camera preferences
│   └── widgets/
│       ├── camera_preview_widget.dart     # Full-screen camera with switch button
│       ├── response_bottom_sheet.dart     # Draggable response sheet + prompts
│       ├── glass_container.dart           # Reusable glassmorphic container
│       ├── mode_toggle.dart               # Live / Photo animated toggle
│       ├── status_indicator.dart          # Ready / Processing / Generating pill
│       └── error_dialog.dart              # Error listener + retry dialogs
├── ios/
│   └── Runner/
│       ├── AppDelegate.swift              # Plugin registration
│       ├── FastVLMPlugin.swift            # MethodChannel + EventChannel bridge
│       ├── FastVLMModel.swift             # Model loading & inference wrapper
│       └── FastVLM/                       # Core VLM (ported from Apple)
│           ├── FastVLM.swift              # Model architecture + registration
│           ├── FastVITHD.swift            # CoreML vision encoder
│           └── MediaProcessingExtensions.swift  # Image processing utils
├── test/                                  # Widget & unit tests
├── assets/                                # App icon
├── get_pretrained_model.sh                # Model download helper
├── pubspec.yaml
└── LICENSE
```

### Key Technologies

| Technology | Role |
|------------|------|
| [Flutter](https://flutter.dev/) | UI framework |
| [Riverpod 3.x](https://riverpod.dev/) | State management (`Notifier` API) |
| [MLX Swift](https://github.com/ml-explore/mlx-swift) | On-device ML for Apple Silicon |
| [FastVLM](https://github.com/apple/ml-fastvlm) | Vision-language model architecture |
| CoreML + Neural Engine | Hardware-accelerated vision encoding |

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Static analysis
flutter analyze
```

---

## 🤝 Contributing

Contributions are welcome! Here's how:

1. **Fork** the repository
2. **Create a branch:** `git checkout -b feature/my-feature`
3. **Make changes** and add tests if applicable
4. **Verify:**
   ```bash
   flutter analyze   # Zero issues required
   flutter test      # All tests passing
   ```
5. **Commit** with a clear message
6. **Open a Pull Request**

### Areas for Contribution

- 🌐 **Runtime model download** — Download models on-demand instead of bundling *(planned)*
- 🤖 **Custom model URLs** — Paste URLs for any compatible FastVLM model *(planned)*
- 🎨 **UI/UX** — Animations, accessibility, new themes
- 📊 **Performance** — Frame rate tuning, memory optimization
- 🧪 **Testing** — Widget tests, integration tests, golden tests
- 📖 **Docs** — Screenshots, tutorials, translations

---

## ⚠️ Troubleshooting

### Model not loading
- Ensure the `model` folder is added to the Xcode Runner target as a **folder reference**
- Verify the folder appears in **Build Phases → Copy Bundle Resources**
- Check your device runs iOS 18.2+

### Camera not working
- Grant camera permission when prompted
- `Info.plist` must contain `NSCameraUsageDescription`

### Build errors
- Run `cd ios && pod install && cd ..`
- Clean: `flutter clean && flutter pub get`
- Verify SPM packages (mlx-swift, mlx-swift-lm) are resolved in Xcode

### "Module not found" for MLX
- In Xcode, go to **File → Packages → Resolve Package Versions**
- Ensure both `mlx-swift` and `mlx-swift-lm` are added to the Runner target

---

## 📄 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

Files in `ios/Runner/FastVLM/` are derived from [Apple's ml-fastvlm](https://github.com/apple/ml-fastvlm) and are subject to Apple's original license (Copyright © 2025 Apple Inc.).

---

## 📚 Citation

If you use FastVLM in your research, please cite:

```bibtex
@inproceedings{fastvlm2025,
  title     = {FastVLM: Efficient Vision Encoding for Vision Language Models},
  author    = {Vasu, Pavan Kumar Anasosalu and Faghri, Fartash and Li, Chun-Liang
               and Koc, Cem and True, Nate and Antony, Albert and Santhanam, Gokul
               and Gabriel, James and Grasch, Peter and Tuzel, Oncel
               and Pouransari, Hadi},
  booktitle = {CVPR},
  year      = {2025}
}
```

---

## 🙏 Acknowledgements

- [Apple ML Research](https://github.com/apple/ml-fastvlm) — FastVLM model & architecture
- [MLX Swift](https://github.com/ml-explore/mlx-swift) — On-device ML framework
- [Flutter](https://flutter.dev/) — Cross-platform UI
- [Riverpod](https://riverpod.dev/) — Reactive state management
