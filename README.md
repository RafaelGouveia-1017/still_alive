<div align="center">
  <picture>
    <img alt="StillAlive"
         src="./lib/assets/logo.png"
         width="15%">
  </picture>
</div>
<div align="center">
<h1>StillAlive – Personal Safety Platform</h1>
</div>
<div align="center">

[![Android](<https://img.shields.io/badge/Android-Min:%2010%20(API%2029)%20|%20Target:%2016%20(API%2036)-green?logo=android>)](https://developer.android.com/develop)
[![iOS](https://img.shields.io/badge/iOS-Min:%2016.0%20|%20Target:%2026.0-%23000000?logo=ios)](https://developer.apple.com/documentation/)
<br>
[![Flutter](<https://img.shields.io/badge/Frontend-Flutter%20(3.44.4)-%2302569B?logo=flutter>)](https://flutter.dev)
[![Dart](<https://img.shields.io/badge/Frontend-Dart%20(3.12.2)-%2302569B?logo=dart>)](https://dart.dev/)
[![Rust](<https://img.shields.io/badge/BackEnd-Rust%20(1.96.0)-orange?logo=rust>)](https://www.rust-lang.org/)
<br>
[![License](https://img.shields.io/badge/License-MIT-yellow?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNmZmZmZmYiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIiBjbGFzcz0ibHVjaWRlIGx1Y2lkZS1zY2FsZS1pY29uIGx1Y2lkZS1zY2FsZSI+PHBhdGggZD0iTTEyIDN2MTgiLz48cGF0aCBkPSJtMTkgOCAzIDhhNSA1IDAgMCAxLTYgMHpWNyIvPjxwYXRoIGQ9Ik0zIDdoMWExNyAxNyAwIDAgMCA4LTIgMTcgMTcgMCAwIDAgOCAyaDEiLz48cGF0aCBkPSJtNSA4IDMgOGE1IDUgMCAwIDEtNiAwelY3Ii8+PHBhdGggZD0iTTcgMjFoMTAiLz48L3N2Zz4=)](https://opensource.org/licenses/MIT)

</div>

**StillAlive** is a proactive personal safety application designed to mitigate the "silent emergency" – situations where a person becomes incapacitated (due to accidents, medical emergencies, or attacks) and is unable to manually call for help.

Unlike traditional "check-in" apps that require active interaction, **StillAlive** operates on a "fail-safe" principle: if a user does not manually deactivate a safety timer, the system automatically assumes a state of danger and triggers a pre-defined emergency protocol.

## 🚨 The Problem

People in vulnerable situations—such as solo hikers, travelers in unfamiliar areas, or the elderly—often face scenarios where they lose the ability to communicate. Existing solutions often require constant manual updates, which are impossible during an actual emergency.

## ✨ Key Features

- **Safety Timer (Fail-Safe Mechanism):** Set a duration for your activity. If the timer expires without user interaction, the emergency protocol initiates automatically.
- **Automated Emergency Protocol:** Gradual escalation of alerts via:
  - SMS, Email, and Push Notifications.
  - Real-time location sharing with emergency contacts.
  - Integration with **Telegram** and **Discord** via automated bots.
- **Offline Resilience:** In areas with no cellular coverage, the app activates local survival mechanisms, including high-intensity audio alerts and immediate local notifications.
- **Privacy by Design:**
  - **No Account Required:** Minimal data collection to protect user anonymity.
  - **Permission-Based:** Location and contact data are only accessed/used according to explicit user configurations.
  - **Secure Storage:** All sensitive data is encrypted and stored locally.
- **Easy Adoption:** Support for **QR Code generation** to allow emergency contacts to join alert groups easily.

## 🛠 Tech Stack

- **Frontend:** [Flutter](https://flutter.dev/) (Dart) for a high-performance, cross-platform mobile experience.
- **Core Engine:** [Rust](https://www.rust-lang.org/) for high-performance, memory-safe logic, integrated via [`flutter_rust_bridge`](https://github.com/fzyzcjy/flutter_rust_bridge).
- **Local Database:** [SQLite](https://www.sqlite.org/) for robust, encrypted local data persistence.
- **CI/CD:** [GitHub Actions](https://github.com/features/actions) for automated testing pipelines.
- **Communication:** REST/JSON for backend/service integration.

## 🏗 Architecture

The project follows a hybrid architecture:

1. **UI Layer (Flutter):** Handles user interaction, maps, and visual feedback.
2. **Logic Layer (Rust):** Handles the heavy lifting, timer precision, and sensitive cryptographic operations, ensuring maximum reliability.
3. **Integration Layer:** Uses [`flutter_rust_bridge`](https://github.com/fzyzcjy/flutter_rust_bridge) to allow seamless, type-safe communication between Dart and Rust.

## 🚀 Roadmap

- **Phase 1: Analysis** (Requirements, Mockups, Research)
- **Phase 2: Development** (Core functionality, UI Implementation, Unit/Integration Tests)
- **Phase 3: Testing & Documentation** (System testing, Manuals, Final Report)

Target Completion: July 2026

## 🛡 Privacy & Security

StillAlive is built on the principle of **Privacy by Design**. We minimize data retention and never require unnecessary personal information. All communications are encrypted, and the app is designed to function with the absolute minimum of data exposure required to ensure safety.

## 👤 Author

**Rafael Gouveia**  
_Software Engineering Student_  
[ESTSetúbal / IPS](https://www.estsetubal.ips.pt/)

---

_This project is part of a Final Year Project (Licenciatura em Engenharia Informática)._
