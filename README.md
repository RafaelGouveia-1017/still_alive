<div align="center">
  <picture>
    <img alt="StillAlive"
         src="https://lh3.googleusercontent.com/kewa78VhdxECe_P9m5CenxAQ29ElE5SkF2WDqRsOFWH9SKK6pP4gCRk4FeMsjvyQEN8LREGJ_so20ZcT0lbrjlk=s0?imgmax=0"
         width="15%">
  </picture>
</div>
<div align="center">
<h1>StillAlive – Personal Safety Platform</h1>
</div>
<div align="center">
  <a href="https://developer.android.com/develop">
    <img
      src="https://img.shields.io/badge/Android-Min%3A%2010%20(API%2029)%20%7C%20Target%3A%2016%20(API%2036)-green?logo=android"
      alt="Android"
    />
  </a>
  <br>
  <a href="https://flutter.dev">
    <img
      src="https://img.shields.io/badge/Frontend-Flutter%20(3.47.5)-%2302569B?logo=flutter"
      alt="Flutter"
    />
  </a>
  <a href="https://dart.dev/">
    <img
      src="https://img.shields.io/badge/Frontend-Dart%20(3.13.4)-%2302569B?logo=dart"
      alt="Dart"
    />
  </a>
  <a href="https://www.rust-lang.org/">
    <img
      src="https://img.shields.io/badge/BackEnd-Rust%20(1.98.1)-orange?logo=rust"
      alt="Rust"
    />
  </a>
  <br>
  <a href="https://opensource.org/licenses/MIT">
    <img
      src="https://img.shields.io/badge/License-MIT-yellow?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNmZmZmZmYiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIiBjbGFzcz0ibHVjaWRlIGx1Y2lkZS1zY2FsZS1pY29uIGx1Y2lkZS1zY2FsZSI+PHBhdGggZD0iTTEyIDN2MTgiLz48cGF0aCBkPSJtMTkgOCAzIDhhNSA1IDAgMCAxLTYgMHpWNyIvPjxwYXRoIGQ9Ik0zIDdoMWExNyAxNyAwIDAgMCA4LTIgMTcgMTcgMCAwIDAgOCAyaDEiLz48cGF0aCBkPSJtNSA4IDMgOGE1IDUgMCAwIDEtNiAwelY3Ii8+PHBhdGggZD0iTTcgMjFoMTAiLz48L3N2Zz4="
      alt="MIT License"
    />
  </a>
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

### 📦 Dependencies

StillAlive uses a collection of Flutter/Dart packages to provide its core functionality, user interface, device integration, mapping, communication, security, and other platform capabilities.

#### 🔗 Flutter & Rust Integration

| Package                                                                                                           |  Version | Creator                                                                 |
| ----------------------------------------------------------------------------------------------------------------- | -------: | ----------------------------------------------------------------------- |
| [flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge)                                               | `2.13.0` | [fzyzcjy](https://github.com/fzyzcjy/flutter_rust_bridge)               |
| `rust_lib_still_alive`                                                                                            |    Local | [StillAlive Project](https://github.com/RafaelGouveia-1017/still_alive) |
| [flutter_localizations](https://api.flutter.dev/flutter/flutter_localizations/flutter_localizations-library.html) |      SDK | [Flutter Team](https://github.com/flutter/flutter)                      |

> **Note:** `rust_lib_still_alive` is a local Rust library generated for the StillAlive project and exposed to Flutter through [`flutter_rust_bridge`](https://pub.dev/packages/flutter_rust_bridge). It is not published as a standalone package on `pub.dev`.

#### 🎨 UI, Icons & Visual Design

| Package                                                                   |   Version | Creator                                                                       |
| ------------------------------------------------------------------------- | --------: | ----------------------------------------------------------------------------- |
| [lucide_icons_flutter](https://pub.dev/packages/lucide_icons_flutter)     | `^3.1.22` | [Lucide Contributors](https://github.com/lucide-icons/lucide)                 |
| [font_awesome_flutter](https://pub.dev/packages/font_awesome_flutter)     | `^11.0.0` | [Flutter Community](https://github.com/fluttercommunity/font_awesome_flutter) |
| [animated_splash_screen](https://pub.dev/packages/animated_splash_screen) |  `^1.3.0` | [Clean Code](https://github.com/clean-code-dev/animated_splash_screen)        |
| [page_transition](https://pub.dev/packages/page_transition)               |  `^2.2.2` | [kalismeras61](https://github.com/kalismeras61/flutter_page_transition)       |
| [flutter_native_splash](https://pub.dev/packages/flutter_native_splash)   |  `^2.4.8` | [jonbhanson](https://github.com/jonbhanson/flutter_native_splash)             |

#### 🧩 State Management, Data & Utilities

| Package                                                           |    Version | Creator                                                                              |
| ----------------------------------------------------------------- | ---------: | ------------------------------------------------------------------------------------ |
| [provider](https://pub.dev/packages/provider)                     | `^6.1.5+1` | [rrousselGit](https://github.com/rrousselGit/provider)                               |
| [collection](https://pub.dev/packages/collection)                 |  `^1.19.1` | [Dart Team](https://github.com/dart-lang/core/tree/main/pkgs/collection)             |
| [path](https://pub.dev/packages/path)                             |   `^1.9.1` | [Dart Team](https://github.com/dart-lang/core/tree/main/pkgs/path)                   |
| [path_provider](https://pub.dev/packages/path_provider)           |   `^2.1.6` | [Flutter Team](https://github.com/flutter/packages/tree/main/packages/path_provider) |
| [freezed_annotation](https://pub.dev/packages/freezed_annotation) |   `^3.1.0` | [Freezed Contributors](https://github.com/rrousselGit/freezed)                       |
| [logging](https://pub.dev/packages/logging)                       |   `^1.3.0` | [Dart Team](https://github.com/dart-lang/core/tree/main/pkgs/logging)                |
| [vector_math](https://pub.dev/packages/vector_math)               |   `^2.4.3` | [Dart Team](https://github.com/google/vector_math.dart)                              |

#### 📱 Device & System Integration

| Package                                                                                       |  Version | Creator                                                                                                    |
| --------------------------------------------------------------------------------------------- | -------: | ---------------------------------------------------------------------------------------------------------- |
| [permission_handler](https://pub.dev/packages/permission_handler)                             | `12.0.3` | [Baseflow](https://github.com/Baseflow/flutter-permission-handler)                                         |
| [battery_optimization_permission](https://pub.dev/packages/battery_optimization_permission)   | `^1.1.3` | [H Square Apps](https://pub.dev/packages/battery_optimization_permission/publisher)                        |
| [package_info_plus](https://pub.dev/packages/package_info_plus)                               |  `9.0.1` | [Flutter Community](https://github.com/fluttercommunity/plus_plugins/tree/main/packages/package_info_plus) |
| [battery_plus](https://pub.dev/packages/battery_plus)                                         | `^7.1.2` | [Flutter Community](https://github.com/fluttercommunity/plus_plugins/tree/main/packages/battery_plus)      |
| [connectivity_plus](https://pub.dev/packages/connectivity_plus)                               |  `7.3.1` | [Flutter Community](https://github.com/fluttercommunity/plus_plugins/tree/main/packages/connectivity_plus) |
| [internet_connection_checker_plus](https://pub.dev/packages/internet_connection_checker_plus) | `^3.1.2` | [OutdatedGuy](https://github.com/OutdatedGuy/internet_connection_checker_plus)                             |

#### 🧭 Maps, Location & Navigation

| Package                                                                         |   Version | Creator                                                                |
| ------------------------------------------------------------------------------- | --------: | ---------------------------------------------------------------------- |
| [google_polyline_algorithm](https://pub.dev/packages/google_polyline_algorithm) |  `^3.1.0` | [OlehMarch](https://github.com/marchdev-tk/google_polyline_algorithm)  |
| [latlong2](https://pub.dev/packages/latlong2)                                   | `^0.10.1` | [ThexXTURBOXx](https://github.com/ThexXTURBOXx/dart-latlong)           |
| [flutter_map](https://pub.dev/packages/flutter_map)                             |  `^8.3.2` | [Fleaflet](https://github.com/fleaflet/flutter_map)                    |
| [flutter_map_vector_tiles](https://pub.dev/packages/flutter_map_vector_tiles)   |  `^2.9.0` | [JonasGrunau](https://github.com/JonasGrunau/flutter-map-vector-tiles) |
| [flutter_map_compass](https://pub.dev/packages/flutter_map_compass)             |  `^1.1.1` | [josxha](https://github.com/josxha/flutter_map_plugins)                |
| [geolocator](https://pub.dev/packages/geolocator)                               |  `14.0.2` | [Baseflow](https://github.com/Baseflow/flutter-geolocator)             |

#### 📷 QR Codes & Scanning

| Package                                                   |  Version | Creator                                                                  |
| --------------------------------------------------------- | -------: | ------------------------------------------------------------------------ |
| [mobile_scanner](https://pub.dev/packages/mobile_scanner) | `^7.4.1` | [juliansteenbakker](https://github.com/juliansteenbakker/mobile_scanner) |
| [qr_flutter](https://pub.dev/packages/qr_flutter)         | `^4.1.0` | [Yakka](https://github.com/theyakka/qr.flutter)                          |

#### 🎙️ Audio & Recording

| Package                                               |  Version | Creator                                                   |
| ----------------------------------------------------- | -------: | --------------------------------------------------------- |
| [record](https://pub.dev/packages/record)             | `^7.1.1` | [llfbandit](https://github.com/llfbandit/record)          |
| [audioplayers](https://pub.dev/packages/audioplayers) | `^6.8.1` | [Blue Fire](https://github.com/bluefireteam/audioplayers) |

#### 👥 Contacts & Messaging

| Package                                                       |  Version | Creator                                                        |
| ------------------------------------------------------------- | -------: | -------------------------------------------------------------- |
| [flutter_contacts](https://pub.dev/packages/flutter_contacts) | `^2.6.0` | [QuisApp](https://github.com/QuisApp/flutter_contacts)         |
| [send_message](https://pub.dev/packages/send_message)         | `^1.0.2` | [dabhinavaghan](https://github.com/DabhiNavaghan/send_message) |

#### 📐 Layout, Interaction & Navigation

| Package                                                                                 |   Version | Creator                                                                             |
| --------------------------------------------------------------------------------------- | --------: | ----------------------------------------------------------------------------------- |
| [flutter_reorderable_grid_view](https://pub.dev/packages/flutter_reorderable_grid_view) |  `^5.7.0` | [karvulf](https://github.com/karvulf/flutter-reorderable-grid-view)                 |
| [fluttertoast](https://pub.dev/packages/fluttertoast)                                   | `^10.0.2` | [ponnamkarthik](https://github.com/ponnamkarthik/FlutterToast)                      |
| [scrollable_positioned_list](https://pub.dev/packages/scrollable_positioned_list)       |  `^0.3.8` | [Google](https://github.com/google/flutter.widgets)                                 |
| [restart_app](https://pub.dev/packages/restart_app)                                     | `^1.10.1` | [gabrimatic](https://github.com/gabrimatic/restart_app)                             |
| [url_launcher](https://pub.dev/packages/url_launcher)                                   |  `^6.3.3` | [Flutter Team](https://github.com/flutter/packages/tree/main/packages/url_launcher) |
| [file_picker](https://pub.dev/packages/file_picker)                                     |  `11.0.3` | [miguelpruivo](https://github.com/vicajilau/flutter_file_picker/)                   |

#### 🔐 Security & Cryptography

| Package                                   |  Version | Creator                                                       |
| ----------------------------------------- | -------: | ------------------------------------------------------------- |
| [bcrypt](https://pub.dev/packages/bcrypt) | `^1.2.0` | [astudilloalex](https://github.com/astudilloalex/dart-bcrypt) |

## 🏗 Architecture

The project follows a hybrid architecture:

1. **UI Layer (Flutter):** Handles user interaction, maps, and visual feedback.
2. **Logic Layer (Rust):** Handles the heavy lifting, timer precision, and sensitive cryptographic operations, ensuring maximum reliability.
3. **Integration Layer:** Uses [`flutter_rust_bridge`](https://github.com/fzyzcjy/flutter_rust_bridge) to allow seamless, type-safe communication between Dart and Rust.

## 🛡 Privacy & Security

StillAlive is built on the principle of **Privacy by Design**. We minimize data retention and never require unnecessary personal information. All communications are encrypted, and the app is designed to function with the absolute minimum of data exposure required to ensure safety.

## 📖 Viewing the docs

To enable navigation and search, the [generated docs](https://github.com/RafaelGouveia-1017/still_alive/commits/main/docs) must be served with an HTTP server.

An easy way to run an HTTP server locally is to use [`package:dhttpd`](https://pub.dev/packages/dhttpd).
For example:

```bash
# For Dart code
> dart pub global activate dhttpd
> dart pub global run dhttpd --path docs

# For Rust code (no HTTP server needed)
> cd rust
> cargo doc --no-deps --document-private-items --open
# or
# Open ...\still_alive\rust\target\doc\rust_lib_still_alive\index.html
```

To then read the generated docs in your browser, open the link that `dhttpd` outputs, usually `http://localhost:8080`.

## 👥 Contributors

<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%">
        <a href="https://github.com/RafaelGouveia-1017">
          <img
            src="https://avatars.githubusercontent.com/u/133778965?v=4?s=100"
            width="100px;"
            alt="guy_who_started_this"
          />
          <br>
          <sub><b>Rafael Gouveia</b></sub>
        </a>
        <br>
        <a href="https://github.com/RafaelGouveia-1017/still_alive/commits?author=RafaelGouveia-1017" title="Code">💻</a>
        <a href="https://github.com/RafaelGouveia-1017/still_alive/commits/main/test/?author=RafaelGouveia-1017" title="Tests">⚠️</a>
        <a href="https://github.com/RafaelGouveia-1017/still_alive/commits/main/docs/?author=RafaelGouveia-1017" title="Documentation">📖</a>
        <a href="https://github.com/RafaelGouveia-1017/still_alive/blob/main/README.md" title="Idea">💡</a>
        <a href="#feedback" title="Planning & Feedback">🤔</a>
        <a href="#maintenance" title="Maintenance">🚧</a>
      </td>
      <td align="center" valign="top" width="14.28%">
        <a href="https://chatgpt.com/"
          >
          <img
            src="https://upload.wikimedia.org/wikipedia/commons/4/46/ChatGPT_Search_logo_Black_Square_-_rounded_corners.svg"
            width="100px;"
            alt="ChatGPT"
          />
          <br><sub><b>ChatGPT</b></sub>
        </a>
        <br>
        <a href="https://github.com/RafaelGouveia-1017/still_alive/commits" title="Code">💻</a>
        <a href="https://github.com/RafaelGouveia-1017/still_alive/commits/main/test/" title="Tests">⚠️</a>
        <a href="https://github.com/RafaelGouveia-1017/still_alive/commits" title="Documentation">📖</a>
      </td>
            <td align="center" valign="top" width="14.28%">
        <a href="https://github.com/brunomnsilva"
          >
          <img
            src="https://avatars.githubusercontent.com/u/16222114?v=4?s=100"
            width="100px;"
            alt="Bruno Silva"
          />
          <br><sub><b>Bruno Silva</b></sub>
        </a>
        <br>
        <a href="#feedback" title="Planning & Feedback">🤔</a>
      </td>
    </tr>
  </tbody>
</table>
