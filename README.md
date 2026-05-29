# StillAlive – Personal Safety Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Frontend-Flutter/Dart-%2302569B.svg)](https://flutter.dev)
[![Rust](https://img.shields.io/badge/Core-Rust-%23000000.svg)](https://www.rust-lang.org/)

**StillAlive** is a proactive personal safety application designed to mitigate the "silent emergency" – situations where a person becomes incapacitated (due to accidents, medical emergencies, or attacks) and is unable to manually call for help.

Unlike traditional "check-in" apps that require active interaction, **StillAlive** operates on a "fail-safe" principle: if a user does not manually deactivate a safety timer, the system automatically assumes a state of danger and triggers a pre-defined emergency protocol.

## 🚨 The Problem

People in vulnerable situations—such as solo hikers, travelers in unfamiliar areas, or the elderly—often face scenarios where they lose the ability to communicate. Existing solutions often require constant manual updates, which are impossible during an actual emergency.

## ✨ Key Features

* **Safety Timer (Fail-Safe Mechanism):** Set a duration for your activity. If the timer expires without user interaction, the emergency protocol initiates automatically.
* **Automated Emergency Protocol:** Gradual escalation of alerts via:
  * SMS, Email, and Push Notifications.
  * Real-time location sharing with emergency contacts.
  * Integration with **Telegram** and **Discord** via automated bots.
* **Offline Resilience:** In areas with no cellular coverage, the app activates local survival mechanisms, including high-intensity audio alerts and immediate local notifications.
* **Privacy by Design:**
  * **No Account Required:** Minimal data collection to protect user anonymity.
  * **Permission-Based:** Location and contact data are only accessed/used according to explicit user configurations.
  * **Secure Storage:** All sensitive data is encrypted and stored locally.
* **Easy Adoption:** Support for **QR Code generation** to allow emergency contacts to join alert groups easily.

## 🛠 Tech Stack

* **Frontend:** [Flutter](https://flutter.dev/) (Dart) for a high-performance, cross-platform mobile experience.
* **Core Engine:** [Rust](https://www.rust-lang.org/) for high-performance, memory-safe logic, integrated via `flutter_rust_bridge`.
* **Local Database:** [SQLite](https://www.sqlite.org/) for robust, encrypted local data persistence.
* **CI/CD:** [GitHub Actions](https://github.com/features/actions) for automated testing pipelines.
* **Communication:** REST/JSON for backend/service integration.

## 🏗 Architecture

The project follows a hybrid architecture:

1. **UI Layer (Flutter):** Handles user interaction, maps, and visual feedback.
2. **Logic Layer (Rust):** Handles the heavy lifting, timer precision, and sensitive cryptographic operations, ensuring maximum reliability.
3. **Integration Layer:** Uses `flutter_rust_bridge` to allow seamless, type-safe communication between Dart and Rust.

## 🚀 Roadmap

* **Phase 1: Analysis** (Requirements, Mockups, Research)
* **Phase 2: Development** (Core functionality, UI Implementation, Unit/Integration Tests)
* **Phase 3: Testing & Documentation** (System testing, Manuals, Final Report)

Target Completion: July 2026

## 🛡 Privacy & Security

StillAlive is built on the principle of **Privacy by Design**. We minimize data retention and never require unnecessary personal information. All communications are encrypted, and the app is designed to function with the absolute minimum of data exposure required to ensure safety.

## 👤 Author

**Rafael Gouveia**  
*Software Engineering Student*  
[ESTSetúbal / IPS](https://www.estsetubal.ips.pt/)

---
*This project is part of a Final Year Project (Licenciatura em Engenharia Informática).*
