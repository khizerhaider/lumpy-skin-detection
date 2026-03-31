# Lumpy Skin Disease Detection App — Full Technical Documentation

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture Summary](#2-architecture-summary)
3. [Project Structure](#3-project-structure)
4. [Dependencies & Why They Were Chosen](#4-dependencies--why-they-were-chosen)
5. [ML Models In-Depth](#5-ml-models-in-depth)
6. [ML Pipeline — Detailed Workflow](#6-ml-pipeline--detailed-workflow)
7. [Screen-by-Screen Walkthrough](#7-screen-by-screen-walkthrough)
8. [Widgets](#8-widgets)
9. [Internationalization (i18n)](#9-internationalization-i18n)
10. [State Management](#10-state-management)
11. [Android Configuration](#11-android-configuration)
12. [Permissions](#12-permissions)
13. [Data Flow Diagram](#13-data-flow-diagram)
14. [Key Technical Decisions & Rationale](#14-key-technical-decisions--rationale)
15. [Privacy & Security](#15-privacy--security)
16. [Known Limitations & Edge Cases](#16-known-limitations--edge-cases)

---

## 1. Project Overview

**Lumpy Skin** is a Flutter mobile application that uses on-device AI to detect **Lumpy Skin Disease (LSD)** in cattle. LSD is a serious viral infection caused by the Lumpy Skin Disease Virus (LSDV), a member of the Poxviridae family. It causes significant economic damage to livestock farmers through morbidity, reduced milk/meat production, and trade restrictions.

### What the App Does

1. A farmer or veterinarian opens the app and photographs a cow (or uploads a photo from the gallery).
2. An on-device AI model locates the cow in the image.
3. A second AI model analyzes the detected cow and predicts whether it is **Lumpy (infected)** or **Normal (healthy)**.
4. The result is shown with a confidence score and a color-coded overlay drawn on the image.
5. The annotated image can be saved to the device gallery for record-keeping or sharing.

### Target Users

- Livestock farmers, especially in regions where LSD is endemic (South Asia, Africa, Middle East).
- Veterinarians conducting field assessments.
- Agricultural extension workers.

### Why This App Exists

LSD diagnosis traditionally requires an expert veterinarian and often laboratory confirmation. In rural areas these resources are unavailable or slow. This app gives farmers immediate preliminary screening using only a smartphone, with no internet connection required.

---

## 2. Architecture Summary

```
┌──────────────────────────────────────────────────────────┐
│                      Flutter App                         │
│                                                          │
│  LanguageSelectionScreen ──────→ HomeScreen              │
│                                    │                     │
│                               ImagePicker                │
│                                    │                     │
│                             PipelineService              │
│                            ┌───────┴────────┐            │
│                     DetectorService   ClassifierService  │
│                     (YOLOv8-det)      (YOLOv8-cls)       │
│                     yolo26n.tflite    best.tflite        │
│                            └───────┬────────┘            │
│                           CowHealthPrediction            │
│                                    │                     │
│                      ImagePreview + ResultCard           │
└──────────────────────────────────────────────────────────┘
```

**Pattern:** Flutter StatefulWidget + Singleton Services (no external state manager).
**ML runtime:** TensorFlow Lite (`tflite_flutter`), fully on-device.
**Languages supported:** English, Urdu (RTL).

---

## 3. Project Structure

```
lumpy_skin/
├── lib/
│   ├── main.dart                         # Entry point, theme, language routing
│   ├── l10n/
│   │   └── app_strings.dart              # All UI strings for EN + UR
│   ├── screens/
│   │   ├── home_screen.dart              # Main camera/gallery/result UI
│   │   └── language_selection_screen.dart# First-run language picker
│   ├── ml/
│   │   ├── detector_service.dart         # YOLOv8 object detection (find the cow)
│   │   ├── classifier_service.dart       # YOLOv8-cls disease classification
│   │   └── pipeline_service.dart         # Orchestrates detector → classifier → overlay
│   └── widgets/
│       ├── image_preview.dart            # Card widget: shows image or placeholder
│       └── result_card.dart              # Card widget: shows diagnosis result
├── models/
│   ├── best_float32.tflite               # Disease classifier (5.9 MB, float32)
│   ├── best_float16.tflite               # Disease classifier (3.0 MB, float16 quantized)
│   ├── metadata.yaml                     # Classifier metadata (classes, input size)
│   └── detector/
│       ├── yolo26n_float32.tflite        # Cow detector (9.9 MB, float32)
│       ├── yolo26n_float16.tflite        # Cow detector (5.2 MB, float16 quantized)
│       └── metadata (1).yaml             # Detector metadata (80 COCO classes)
├── android/
│   └── app/
│       ├── build.gradle                  # Android build config (SDK 36, Java 17)
│       └── src/main/
│           └── AndroidManifest.xml       # App name, activity, queries
├── pubspec.yaml                          # Flutter dependencies and asset declarations
├── analysis_options.yaml                 # Dart analyzer lint rules
└── README.md                             # Brief project readme
```

---

## 4. Dependencies & Why They Were Chosen

### `tflite_flutter: ^0.12.1`

**What it does:** Dart bindings for TensorFlow Lite — loads `.tflite` model files and runs inference.

**Why it was chosen:**
- The only mature, actively maintained TFLite wrapper for Flutter.
- Supports multi-threaded inference (speeds up tensor operations on multi-core chips).
- Works for both detection and classification tasks with the same API.
- Runs entirely on-device — no cloud inference needed.

**Alternative considered:** `flutter_tflite` (deprecated, not maintained).

---

### `image: ^4.7.2`

**What it does:** Pure-Dart image manipulation — decode JPEG/PNG, resize, crop, draw shapes and text.

**Why it was chosen:**
- Needed for: decoding raw bytes to pixel arrays, resizing for model input, cropping the detected cow region, drawing bounding boxes and text on the output image.
- Pure Dart means it works across all platforms without native code.
- Provides `arial24` built-in bitmap font for label rendering.

**Why not `dart:ui` or `canvas`?:** Those render to the Flutter widget tree; they cannot produce raw pixel buffers needed for TFLite input tensors.

---

### `image_picker: ^1.2.1`

**What it does:** Plugin to launch the device camera or open the photo gallery and return a file path.

**Why it was chosen:**
- Official Flutter team plugin (flutter.dev).
- Handles permission requests internally on both Android and iOS.
- Supports image compression/max dimensions before returning (reduces memory pressure).
- `maxWidth: 2048, maxHeight: 2048` limits used to cap memory usage while keeping detail.

---

### `flutter_image_gallery_saver: ^1.1.3`

**What it does:** Saves raw bytes as an image file into the device's photo gallery.

**Why it was chosen:**
- After inference, the pipeline produces annotated PNG bytes that users want to keep.
- This plugin handles the `WRITE_EXTERNAL_STORAGE` / `WRITE_MEDIA_IMAGES` permission and gallery registration natively.
- Simple API: `saveImage(bytes)` returns success/failure.

---

### `flutter_localizations` (SDK)

**What it does:** Flutter's built-in localization framework — date/number formats, text direction, locale detection.

**Why it was needed:**
- Urdu is a right-to-left (RTL) language. Flutter needs `Directionality` context to render RTL layouts correctly.
- `GlobalMaterialLocalizations` and `GlobalWidgetsLocalizations` are included to make Flutter's built-in widgets (dialogs, date pickers) respect locale.

---

## 5. ML Models In-Depth

### 5.1 Detector Model: `yolo26n_float32.tflite`

| Property | Value |
|---|---|
| Architecture | YOLOv8 nano (end-to-end export) |
| Training dataset | COCO (80 classes) |
| Input size | 640 × 640 pixels, RGB |
| Input dtype | float32, normalized to [0, 1] |
| Output | Pre-NMS detections (up to ~300 boxes) |
| Each detection | [x1, y1, x2, y2, score, classIndex] or similar layout |
| File size | 9.9 MB (float32), 5.2 MB (float16) |
| Training framework | Ultralytics 8.4.12 |
| Trained on | 2026-02-06 |

**What it does:** Given a 640×640 image, it outputs a list of bounding boxes for all objects it sees. For this app the important class is **cow (COCO class index 19)**, but the pipeline takes the largest detection regardless of class (discussed in Section 14).

**End-to-end export meaning:** Ultralytics' `end2end=true` flag bakes the NMS (Non-Maximum Suppression) step into the model graph itself. The output therefore contains only the final selected boxes — no post-processing needed.

**Coordinate systems:** Depending on export settings, coordinates may be:
- Absolute pixel coordinates in 640×640 space, or
- Normalized [0, 1] coordinates.
The service auto-detects which format is used.

---

### 5.2 Classifier Model: `best_float32.tflite`

| Property | Value |
|---|---|
| Architecture | YOLOv8 nano classification (YOLOv8-cls) |
| Training dataset | Custom LSD dataset from Kaggle (`lumpyv2/dataset_cls`) |
| Input size | 224 × 224 pixels, RGB |
| Input dtype | float32, normalized to [0, 1] |
| Output | 2-element probability vector: [P(lumpy), P(normal)] |
| Classes | 0 = lumpy, 1 = normal |
| File size | 5.9 MB (float32), 3.0 MB (float16) |
| Training framework | Ultralytics 8.4.12 |
| Trained on | 2026-02-06 |

**What it does:** Takes a 224×224 crop of a cow and outputs two probabilities that sum to 1.0 (after softmax). The higher probability determines the label.

**Why 224×224?:** Standard size for image classification models. YOLOv8-cls was trained with this resolution. Smaller than the detector (640) because classification needs less spatial context.

---

## 6. ML Pipeline — Detailed Workflow

This is the heart of the application. The full inference pipeline is orchestrated by `PipelineService` in [lib/ml/pipeline_service.dart](lib/ml/pipeline_service.dart).

### Step 1 — Image Ingestion

```
User taps Camera/Gallery button
    → ImagePicker returns an XFile (file path)
    → Read all bytes: Uint8List imageBytes = await File(path).readAsBytes()
    → Pass bytes to PipelineService.analyzeImage(imageBytes)
```

**Why bytes instead of file path?:** The `image` package decodes from bytes. Isolates cannot receive file handles, only serializable data, so bytes work across isolate boundaries too.

---

### Step 2 — Image Decoding

```dart
img.Image? originalImage = img.decodeImage(imageBytes);
```

`img.decodeImage` auto-detects format (JPEG, PNG, etc.) and returns a full pixel buffer (`img.Image`) where each pixel is accessible as ARGB integers.

**Why this step?:** TFLite needs floating-point pixel values in a specific tensor shape. Raw JPEG bytes cannot be fed directly — they must be decoded to pixel arrays first.

---

### Step 3 — Cow Detection (`DetectorService`)

**File:** [lib/ml/detector_service.dart](lib/ml/detector_service.dart)

#### 3a. Model Loading (lazy, singleton)

```dart
static DetectorService? _instance;
static Future<DetectorService> get instance async { ... }
```

The interpreter is created once and reused. TFLite model loading from assets takes ~200–500ms; doing it on every inference would be unacceptable.

#### 3b. Image Preprocessing

```
originalImage (any size)
    → img.copyResize to 640×640 (stretch resize, not letterbox)
    → Convert to float tensor: shape [1, 640, 640, 3]
    → Normalize each channel: pixel / 255.0
```

**Why stretch resize instead of letterbox?:** Letterbox (preserving aspect ratio with padding) is more accurate but adds complexity in mapping coordinates back. Stretch resize is simpler; the coordinate inverse mapping is just a scale factor per axis.

**Why float32 [0,1]?:** YOLO models are trained with pixel values normalized to [0, 1]. Feeding [0, 255] values would produce garbage outputs because the model never saw that input distribution.

**Tensor shape [1, 640, 640, 3]:**
- `1` — batch size (we process one image at a time)
- `640, 640` — spatial dimensions
- `3` — RGB channels

#### 3c. Inference

```dart
interpreter.run(inputTensor, outputTensor);
```

TFLite runs the model graph. With `numThreads: 2`, it can parallelize tensor operations across 2 CPU cores.

#### 3d. Output Parsing — The Most Complex Part

The YOLOv8 TFLite export can produce outputs in different layouts depending on the export configuration. The service tries four layouts in order:

| Layout Name | Format |
|---|---|
| `xyxyScoreClass` | x1, y1, x2, y2, score, classIndex |
| `xyxyClassScore` | x1, y1, x2, y2, classIndex, score |
| `xywhScoreClass` | xCenter, yCenter, width, height, score, classIndex |
| `xywhClassScore` | xCenter, yCenter, width, height, classIndex, score |

For each layout, it filters boxes with `score > 0.25` (confidence threshold). If no boxes pass this threshold, it falls back to `score > 0.05` and picks the box with the best `area × score` product.

**Why try multiple layouts?:** TFLite exports from different versions of Ultralytics can have different output orderings. This defensive parsing ensures the app works with model variants without requiring a specific export flag.

**Coordinate normalization detection:**
```dart
bool isNormalized = (x1.abs() <= 1.5 && y1.abs() <= 1.5);
```
If coordinates are all close to [0,1] they're normalized; otherwise they're pixel-space (640 range). This handles both export modes.

**Mapping back to original image:**
```dart
double scaleX = originalWidth / 640.0;
double scaleY = originalHeight / 640.0;
DetectionBox box = DetectionBox(
  x: x1 * scaleX,
  y: y1 * scaleY,
  width: (x2 - x1) * scaleX,
  height: (y2 - y1) * scaleY,
  ...
);
```

#### 3e. Selecting the Best Detection

```dart
// Sort by area descending, return largest
boxes.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
return boxes.first;
```

The largest detection is chosen because in a typical cattle photo, the cow fills most of the frame. This is a practical heuristic — if a cow and a person are both in frame, the cow is usually larger.

**What if no cow is detected?**

```dart
if (box == null) {
  return CowHealthPrediction(noDetection: true, processedImageBytes: originalBytes);
}
```

The pipeline short-circuits and returns a `noDetection=true` result. The UI then shows the "No cow detected" card.

---

### Step 4 — Crop the Detected Region

```dart
img.Image crop = img.copyCrop(
  originalImage,
  x: box.x.toInt(),
  y: box.y.toInt(),
  width: box.width.toInt(),
  height: box.height.toInt(),
);
```

The exact pixel region of the detected cow is extracted. This crop is then fed to the classifier — not the full image.

**Why crop before classifying?:**
- The classifier was trained on isolated cow images (from `dataset_cls`), not full scenes.
- Classifying the full image would confuse the model with irrelevant background pixels (sky, grass, other animals).
- Cropping mirrors the training distribution and yields much more accurate results.

---

### Step 5 — Disease Classification (`ClassifierService`)

**File:** [lib/ml/classifier_service.dart](lib/ml/classifier_service.dart)

#### 5a. Image Preprocessing

```
crop (arbitrary size, from detector output)
    → Square center crop (preserves aspect ratio)
    → img.copyResizeCropSquare(crop, size: 224)
    → Convert to float tensor: shape [1, 224, 224, 3]
    → Normalize: pixel / 255.0
```

**Why square center crop instead of stretch?:**
The classifier was trained with Ultralytics' default center-crop preprocessing. Stretch-resizing a cow to 224×224 would distort proportions (a 1000×400 panoramic cow would look squashed). Center crop maintains the natural appearance. This matters because the model learns features like skin lesion proportions.

#### 5b. Softmax Handling

The model may or may not include softmax in its graph depending on export settings. Applying softmax twice degrades confidence (e.g., 0.99 → 0.73). The service detects this:

```dart
bool looksLikeProbabilities =
    rawOutputs.every((v) => v >= 0 && v <= 1.0) &&
    (rawOutputs.reduce((a, b) => a + b) - 1.0).abs() < 0.05;

if (!looksLikeProbabilities) {
  outputs = _softmax(rawOutputs);
} else {
  outputs = rawOutputs; // already softmaxed
}
```

**Why this heuristic works:** True logits (pre-softmax) can be any real number and rarely sum to exactly 1. Probabilities are always in [0,1] and sum to 1 by definition.

**Numerically stable softmax:**
```dart
List<double> _softmax(List<double> logits) {
  double maxVal = logits.reduce(math.max);
  List<double> exps = logits.map((x) => math.exp(x - maxVal)).toList();
  double sum = exps.reduce((a, b) => a + b);
  return exps.map((e) => e / sum).toList();
}
```
Subtracting the max before `exp` prevents floating-point overflow (e.g., `exp(1000)` = infinity).

#### 5c. Result

```
outputs = [0.923, 0.077]
           P(lumpy)  P(normal)

label = "Lumpy"
confidence = 0.923
```

---

### Step 6 — Overlay Drawing (in Isolate)

**File:** [lib/ml/pipeline_service.dart](lib/ml/pipeline_service.dart)

Drawing runs in a Dart `Isolate` to avoid blocking the UI thread:

```dart
Uint8List overlaidBytes = await compute(_drawOverlayInIsolate, overlayParams);
```

**What gets drawn:**

1. **Red bounding box** (4px thick) around the detected cow region:
   ```
   Color: RGB(255, 59, 48)  — iOS system red
   ```

2. **Label text** above the bounding box:
   ```
   Format: "Lumpy 92.3%" or "Normal 87.2%"
   Font: arial24 (built-in bitmap font)
   Text color: RGB(30, 142, 90)  — app green
   Background: semi-transparent white rectangle for readability
   ```

3. **Output:** Re-encoded as PNG bytes.

**Why draw in an isolate?:**
- Drawing involves iterating over thousands of pixels (for box borders and text).
- PNG encoding compresses the full image — can take 100–300ms on mobile.
- Running this on the main isolate would freeze the Flutter UI thread, causing visible jank.
- `compute()` sends the params to a background isolate and awaits the result asynchronously.

---

### Step 7 — Return Result to UI

```dart
return CowHealthPrediction(
  processedImageBytes: overlaidBytes, // PNG with bounding box + label
  label: result.label,                // "Lumpy" or "Normal"
  confidence: result.confidence,      // 0.0 – 1.0
  statusText: result.label == "Lumpy" ? "Infected" : "Healthy",
  noDetection: false,
);
```

---

## 7. Screen-by-Screen Walkthrough

### 7.1 Language Selection Screen

**File:** [lib/screens/language_selection_screen.dart](lib/screens/language_selection_screen.dart)

**When shown:** On first launch (no language stored in app state).

**Layout:**
```
[Translation icon]
"Choose Your Language"
"اپنی زبان منتخب کریں"

[ English ]   (filled button)
[   اردو  ]   (outlined button)
```

**What happens on selection:**
```dart
widget.onLanguageSelected(AppLanguage.english); // or .urdu
```
This callback bubbles up to `CowHealthScannerApp` in `main.dart`, which calls `setState` to:
1. Store the language selection.
2. Switch the navigator to show `HomeScreen`.
3. Set text direction: LTR for English, RTL for Urdu.

**Why a dedicated screen instead of a dialog?:**
Language affects the entire app's text direction (RTL vs LTR). A full screen rebuild from the root is needed to apply `Directionality`. A dialog cannot trigger that rebuild.

---

### 7.2 Home Screen

**File:** [lib/screens/home_screen.dart](lib/screens/home_screen.dart)

This is the main and only functional screen of the app.

**Layout (top to bottom, scrollable):**

```
┌─────────────────────────────────┐
│  SliverAppBar: "Cow Health      │
│  Scanner" + settings icon       │
├─────────────────────────────────┤
│  Tagline text                   │
├─────────────────────────────────┤
│  [Camera]        [Gallery]      │  ← Two side-by-side buttons
├─────────────────────────────────┤
│                                 │
│     ImagePreview (4:3)          │  ← Placeholder or annotated image
│                                 │
├─────────────────────────────────┤
│  [Download]                     │  ← Only visible when image loaded
├─────────────────────────────────┤
│  ResultCard                     │  ← Awaiting / No Detection / Lumpy / Normal
├─────────────────────────────────┤
│  Guidelines                     │  ← Usage instructions
└─────────────────────────────────┘
```

**State variables:**

| Variable | Type | Purpose |
|---|---|---|
| `_displayImageBytes` | `Uint8List?` | PNG bytes of annotated image to display |
| `_label` | `String?` | "Lumpy" or "Normal" |
| `_confidence` | `double?` | 0.0 – 1.0 |
| `_statusText` | `String?` | "Infected" or "Healthy" |
| `_noDetection` | `bool` | True if no cow found in image |
| `_isLoading` | `bool` | True while pipeline is running |
| `_errorMessage` | `String?` | Set if an exception is thrown |

**`_pickImage(ImageSource source)` method walkthrough:**

```dart
Future<void> _pickImage(ImageSource source) async {
  // 1. Reset state for new scan
  setState(() { _isLoading = true; _errorMessage = null; ... });

  // 2. Launch camera or gallery
  final XFile? picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2048,
    maxHeight: 2048,
  );

  if (picked == null) {
    // User cancelled — restore previous state
    setState(() { _isLoading = false; });
    return;
  }

  // 3. Read bytes
  final bytes = await picked.readAsBytes();

  // 4. Run pipeline
  final prediction = await PipelineService.instance.analyzeImage(bytes);

  // 5. Update UI (mounted check prevents crash if widget was disposed)
  if (!mounted) return;
  setState(() {
    _displayImageBytes = prediction.processedImageBytes;
    _label = prediction.label;
    _confidence = prediction.confidence;
    _noDetection = prediction.noDetection;
    _isLoading = false;
  });
}
```

**Why `if (!mounted) return`?:**
`analyzeImage` is asynchronous (takes 1–3 seconds). The user might close the screen before it finishes. Calling `setState` on a disposed widget throws an exception. The `mounted` check prevents this.

---

## 8. Widgets

### 8.1 ImagePreview

**File:** [lib/widgets/image_preview.dart](lib/widgets/image_preview.dart)

A `Card` that shows either a placeholder or the result image.

**Three states:**

| State | What's shown |
|---|---|
| No image, not loading | Animated gradient background + health icon + "No image selected" text |
| Image loaded | `Image.memory(bytes)` with `BoxFit.cover` inside 4:3 aspect ratio box |
| Loading | Current image (or placeholder) + 60% opaque white overlay + `CircularProgressIndicator` |

**Why 4:3 aspect ratio?:**
Most phone cameras produce 4:3 images. Matching the preview to the image ratio avoids letterboxing/pillarboxing that wastes screen space and looks awkward.

**Why `AnimatedContainer` and `AnimatedOpacity`?:**
Smooth transitions (300ms gradient fade, 250ms loading overlay) make the app feel polished rather than abrupt when switching between states.

---

### 8.2 ResultCard

**File:** [lib/widgets/result_card.dart](lib/widgets/result_card.dart)

Displays the diagnosis in a visually prominent card below the image.

**Five states:**

| State | Trigger | Icon | Color | Message |
|---|---|---|---|---|
| Awaiting | No scan yet | `help_outline_rounded` | Gray | "Awaiting scan" |
| No Detection | `noDetection == true` | `search_off_rounded` | Blue | "No cow detected" |
| Error | `errorMessage != null` | `error_outline_rounded` | Red | Error message |
| Lumpy | `label == "Lumpy"` | `sick_rounded` | Red accent | "Prediction: Lumpy — Infected — 92.3%" |
| Normal | `label == "Normal"` | `check_circle_rounded` | Green | "Prediction: Normal — Healthy — 87.2%" |

**Why color-code?:**
Red = danger/disease, green = safe/healthy. This is universally understood and matches medical convention. The farmer can understand the result without reading the text.

---

## 9. Internationalization (i18n)

**File:** [lib/l10n/app_strings.dart](lib/l10n/app_strings.dart)

The app uses a custom `InheritedWidget`-based i18n system rather than Flutter's `gen_l10n` tool.

**Why custom instead of `gen_l10n`?:**
`gen_l10n` requires `.arb` files and build_runner code generation. For a two-language app with no dynamic locale switching, a hand-written `InheritedWidget` is simpler and has zero build-time dependencies.

**How it works:**

```dart
// Access strings anywhere in the widget tree:
final strings = AppStringsScope.of(context);
Text(strings.appTitle);
```

**`AppStringsScope`** is an `InheritedWidget` inserted at the root of the tree (in `main.dart`). It holds an `AppStrings` object configured with the selected language.

**`AppStrings`** has getters like:
```dart
String get appTitle => language == AppLanguage.urdu
    ? 'گائے کی صحت اسکینر'
    : 'Cow Health Scanner';
```

**Urdu (RTL) support:**
In `main.dart`, when Urdu is selected:
```dart
return Directionality(
  textDirection: language == AppLanguage.urdu
      ? TextDirection.rtl
      : TextDirection.ltr,
  child: MaterialApp(...)
);
```
This flips the entire layout — buttons, icons, text alignment — without any per-widget logic.

---

## 10. State Management

The app uses **vanilla StatefulWidget** with no external library (no Provider, Riverpod, BLoC, etc.).

**Why this is appropriate:**
- There is only one screen with meaningful state (`HomeScreen`).
- State flows in one direction: user action → pipeline → `setState` → rebuild.
- No state is shared between screens (language is passed via callback, not a global store).
- Adding Provider or BLoC would be over-engineering for this scope.

**Singleton Services:**

`DetectorService`, `ClassifierService`, and `PipelineService` are singletons:
```dart
static DetectorService? _instance;
static Future<DetectorService> get instance async {
  _instance ??= await _create();
  return _instance!;
}
```
This ensures models are loaded from assets only once and reused across multiple inferences. Loading a TFLite model takes ~300ms; doing this on every button press would create unacceptable lag.

---

## 11. Android Configuration

### `android/app/build.gradle`

| Setting | Value | Why |
|---|---|---|
| `compileSdkVersion` | 36 | Latest stable Android SDK (Android 15) |
| `targetSdkVersion` | 36 | App tested and designed for Android 15 |
| `minSdkVersion` | `flutter.minSdkVersion` | Inherits Flutter's minimum (~21 / Android 5.0) |
| `applicationId` | `com.example.lumpy_skin` | Unique app identifier on Play Store |
| `versionCode` | 1 | Internal build number (increment for each release) |
| `versionName` | "1.0" | User-visible version string |
| `sourceCompatibility` | `JavaVersion.VERSION_17` | Required by Flutter 3.x plugin APIs |
| `kotlinOptions.jvmTarget` | "17" | Match Java version for Kotlin interop |
| `minifyEnabled` | false | R8/ProGuard disabled (safe for debug; enable for release) |
| `shrinkResources` | false | Keep all resources (prevents accidental model stripping) |

**Important note on `shrinkResources: false`:**
If resource shrinking were enabled, the build tools might incorrectly identify the `.tflite` model files as unused resources and remove them from the APK. Keeping it false ensures models are always included.

### `android/app/src/main/AndroidManifest.xml`

- `android:launchMode="singleTop"` — Prevents multiple instances of the app from stacking when the app icon is tapped while already open.
- `<queries>` block — Declares that the app may query for apps that handle `PROCESS_TEXT` intents (used by `image_picker` for text recognition integrations on some OEMs).

---

## 12. Permissions

The app requires three runtime permissions that are NOT declared in `AndroidManifest.xml` directly — they are declared by the plugin libraries (merged during build).

| Permission | Used by | When requested |
|---|---|---|
| `CAMERA` | `image_picker` | When user taps the Camera button |
| `READ_MEDIA_IMAGES` (Android 13+) or `READ_EXTERNAL_STORAGE` | `image_picker` | When user taps the Gallery button |
| `WRITE_EXTERNAL_STORAGE` (Android < 10) or `MediaStore` API (Android 10+) | `flutter_image_gallery_saver` | When user taps the Download button |

**Why not declare them manually?:**
Flutter's plugin system merges manifests from all plugins at build time. Declaring them again in the app manifest is redundant and could cause version conflicts.

---

## 13. Data Flow Diagram

```
User taps "Camera" or "Gallery"
         │
         ▼
  ImagePicker.pickImage()
  (native camera/gallery UI)
         │
         ▼
  XFile → readAsBytes() → Uint8List
         │
         ▼
  PipelineService.analyzeImage(bytes)
    │
    ├─ img.decodeImage(bytes) → img.Image
    │
    ├─ DetectorService.detectLargestCow(image)
    │   ├─ copyResize(640×640)
    │   ├─ build float tensor [1,640,640,3]
    │   ├─ interpreter.run()
    │   ├─ parse output (try 4 layouts)
    │   ├─ filter by confidence > 0.25
    │   └─ return largest DetectionBox (or null)
    │
    ├─ If null → return noDetection=true, original image
    │
    ├─ img.copyCrop(image, box) → crop
    │
    ├─ ClassifierService.classify(crop)
    │   ├─ copyResizeCropSquare(224)
    │   ├─ build float tensor [1,224,224,3]
    │   ├─ interpreter.run()
    │   ├─ detect if softmax needed
    │   ├─ apply softmax if needed
    │   └─ return ClassificationResult(label, confidence)
    │
    ├─ compute(_drawOverlayInIsolate)
    │   ├─ draw red bounding box (4px)
    │   ├─ draw label background
    │   ├─ draw "Lumpy 92.3%" text
    │   └─ img.encodePng() → Uint8List
    │
    └─ return CowHealthPrediction
              │
              ▼
        HomeScreen.setState()
              │
    ┌─────────┴─────────┐
    ▼                   ▼
ImagePreview         ResultCard
(show overlay img)  (show label + confidence)
```

---

## 14. Key Technical Decisions & Rationale

### Decision 1: Two-Stage Pipeline (Detect → Classify)

**What:** Detect the cow first, then classify the crop. Not a single end-to-end model.

**Why:**
- Single-stage models trained on full scenes with LSD labels would need thousands of labelled full-scene images. Cropped classification datasets are easier to create and annotate.
- The detector (COCO-trained) generalizes well out of the box. Only the classifier needs domain-specific training.
- Modular pipeline: either model can be updated independently.

---

### Decision 2: Largest Detection Selected (Not Class-Filtered)

**What:** The pipeline does not filter detections by class=cow (COCO class 19). It takes the largest box regardless of class.

**Why:**
- In field conditions, the cow almost always occupies the majority of the frame (farmers are told to photograph the cow up close).
- Class filtering would reject the cow if the model mislabels it as "horse", "dog", or another large animal.
- If the cow IS the largest object, this heuristic is correct. If it isn't, the classification will likely fail gracefully (model will output low confidence).
- More robust to model class confusion on non-COCO cow appearances (local cattle breeds).

---

### Decision 3: Float16 Models Included But Not Used by Default

**What:** Both float16 (quantized) and float32 models are bundled. The float32 versions are used.

**Why float32 is default:**
- Float32 maintains full precision → more reliable results during development.
- Float16 models are ~40% smaller but may have marginal accuracy differences.

**Why float16 is included:**
- Available as a drop-in swap for production if APK size is a concern.
- Can be selected by changing the asset path constant in the service.

---

### Decision 4: No Internet Permission

**What:** Zero network calls. All inference is on-device.

**Why:**
- Target users are often in rural areas with no or poor connectivity.
- Sending farm animal images to a cloud API would create privacy concerns.
- Latency of cloud inference (2–5s round trip) is worse than local inference (1–2s).
- No backend infrastructure to maintain.

---

### Decision 5: No Persistent Storage of Results

**What:** Results are not saved to a database. Only the annotated image can be saved to the gallery.

**Why:**
- Keeps the app simple — no database setup, no privacy policy for stored health records.
- The gallery save is opt-in (user presses Download).
- A history/records feature would be the logical next step for v2.

---

### Decision 6: Isolate for Drawing, Not for Inference

**What:** PNG encoding and box drawing run in an isolate. TFLite inference does not.

**Why not isolate for TFLite?:**
- TFLite interpreters cannot be sent across isolate boundaries (they hold native memory pointers).
- TFLite's `numThreads: 2` already parallelizes internally.
- Trying to run TFLite in a separate isolate would require re-loading the model, defeating the singleton benefit.

**Why isolate for drawing?:**
- Pixel-level iteration (box borders, text rendering) over a 2048×2048 image can take 200ms.
- PNG encoding (LZ77 compression) of a large image can take 300ms.
- These are pure Dart operations, safe to serialize and run on a background isolate.

---

## 15. Privacy & Security

| Property | Status |
|---|---|
| Network calls | None |
| Data sent to cloud | Never |
| Images stored by app | Never (unless user explicitly saves) |
| API keys | None |
| User accounts | None |
| Analytics / crash reporting | None |
| Models are on-device | Yes, bundled in APK |

**Security note:** Because no data leaves the device, there is no attack surface for data interception. The app cannot be used to exfiltrate farm data.

---

## 16. Known Limitations & Edge Cases

| Limitation | Details | Mitigation |
|---|---|---|
| Single cow per image | Pipeline only analyses the largest detected box | Guidelines instruct users to photograph one cow at a time |
| Non-cattle animals | Largest detection may be a goat, horse, etc. — classifier will still run | Guidelines warn "valid species: cattle only" |
| Poor lighting | YOLO detection degrades in very dark or overexposed photos | Guidelines recommend natural daylight |
| Partial cow | If only the face or legs are visible, detection box may be small and confidence low | Guidelines ask for full-body visibility |
| Camera permissions denied | `ImagePicker` returns null; app shows no error | Can be improved with a permission-explanation dialog |
| Very large images | Capped at 2048×2048 by ImagePicker; larger source images are automatically downsampled | Acceptable tradeoff between memory and detail |
| No history/records | Each scan is isolated; no database | Planned for future versions |
| Android only (in practice) | iOS would need `NSCameraUsageDescription` and gallery entitlements in Info.plist | App is currently configured for Android deployment |
| Model accuracy on unseen breeds | Models trained on specific datasets may have lower accuracy for rare cattle breeds | Confidence score gives user a signal of uncertainty |

---

*Documentation generated from full source code scan — March 2026.*
