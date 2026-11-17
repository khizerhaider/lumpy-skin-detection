<div align="center">

# 🐄 Smart Cattle Health System

**AI-powered tools for livestock health monitoring**

[![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![TensorFlow Lite](https://img.shields.io/badge/TensorFlow%20Lite-on--device-FF6F00?logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)
[![YOLO](https://img.shields.io/badge/Ultralytics-YOLO-111F68)](https://docs.ultralytics.com)

</div>

---

## 📖 Overview

This repository contains the components of a cattle health system made up of two modules:

| Module | Description | Status |
|---|---|---|
| **[LSD: Lumpy Skin Detection](LSD/CodeBase/README.md)** | Offline mobile app that detects a cow in a photo and classifies it as *Lumpy* or *Normal* | ✅ Available |
| **Weight Estimation** | Estimation of cattle body weight | 🚧 In progress |

<p align="center">
  <img src="LSD/CodeBase/docs/screenshots/home.png" width="180" alt="Home screen"/>
  &nbsp;
  <img src="LSD/CodeBase/docs/screenshots/result_lumpy.png" width="180" alt="Lumpy skin detected"/>
  &nbsp;
  <img src="LSD/CodeBase/docs/screenshots/result_normal.png" width="180" alt="Healthy cow"/>
</p>

---

## 📂 Repository Structure

```
.
├── LSD/                     # Lumpy Skin Detection
│   ├── Dataset/             # Dataset (to be added)
│   └── CodeBase/            # Flutter mobile app + TFLite models
└── Weight Estimation/       # Cattle weight estimation module (to be added)
```

---

## 🚀 Quick Start: Lumpy Skin Detection

```bash
git clone https://github.com/khizerhaider/lumpy-skin-detection.git
cd lumpy-skin-detection/LSD/CodeBase
flutter pub get
flutter run
```

See the **[LSD CodeBase README](LSD/CodeBase/README.md)** for features, architecture and setup details,
and **[DOCUMENTATION.md](LSD/CodeBase/DOCUMENTATION.md)** for the full technical documentation.

---

## 🩺 Disclaimer

These tools are screening aids and are **not** a substitute for professional veterinary diagnosis.
