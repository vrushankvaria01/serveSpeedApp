# ServeSpeed

A pocket-sized radar gun for your tennis serve, built natively for iOS.

ServeSpeed turns your iPhone's slow-motion camera into a serve-speed measurement tool by combining 240 fps capture, on-device ball-trajectory detection, and a four-point court calibration to convert pixel motion into real-world MPH. The goal isn't to replace a $500 Pocket Radar — it's to give the average tennis player a number they trust, without the price tag or the clunky UI of the existing App Store options.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![SwiftUI](https://img.shields.io/badge/SwiftUI-blue) ![License: TBD](https://img.shields.io/badge/license-TBD-lightgrey)

---

## Features

- **240 fps slow-motion capture** at 1080p — every ~4 ms of ball flight gets its own frame.
- **One-shot court calibration** — tap the four corners of the far service box and a homography matrix locks the image plane to real-world meters.
- **Peak-velocity-at-contact** measurement — matches how Hawk-Eye/Foxtenn radar reports serve speed on TV, rather than the trajectory-average that competitor apps use.
- **On-device ball tracking** via Apple's `VNDetectTrajectoriesRequest` — no cloud, no API key, no latency.
- **Modern dark UI** with tennis-ball accent palette, animated speed counter, haptic feedback, and full-bleed camera preview.
- **MPH / KM/H / M/S** side-by-side stats with smooth unit transitions.

## Tech stack

| Layer | What we use | Why |
|---|---|---|
| UI | SwiftUI, SF Symbols, custom theme | Native-feeling, fast to iterate, free animations |
| Capture | `AVFoundation` (`AVCaptureSession`, `AVCaptureMovieFileOutput`) | Direct control over the 240 fps slow-mo format |
| Detection | `Vision` (`VNDetectTrajectoriesRequest`) | Built-in parabolic-trajectory tracker, no model to ship |
| Geometry | `simd` + custom Gaussian solver | 4-point homography (DLT) to map image → court coords |
| Concurrency | Swift `async/await`, `actor` | Keep video parsing off the main thread |
| Storage | None (yet) | Sessions are ephemeral for now |

## How it works

```
┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐   ┌──────────────┐
│ AVCapture    │ → │ MovieFile    │ → │ VNDetectTrajectories │ → │ Speed calc   │
│ 1080p/240fps │   │ .mov         │   │ (per-frame Vision)   │   │ peak v at    │
└──────────────┘   └──────────────┘   └──────────────────────┘   │ early flight │
                                                                 └──────┬───────┘
                                                                        ↓
                                                                  ┌──────────┐
                                                                  │ ServeResult │
                                                                  │ MPH / KMH   │
                                                                  └──────────┘
```

The four-corner tap solves an 8×8 linear system for an image→court homography (`Homography.swift`). For each detected trajectory point, we project the pixel into court-plane meters, then compute the largest inter-frame velocity over the early flight window — that's the "peak speed at contact" radar number.

## Setup

### Prerequisites

- macOS 14+ with **Xcode 16+** installed
- An iPhone 8 or newer (240 fps 1080p slow-mo support)
- A free **Apple Developer** account on your Apple ID
- Git + an SSH key linked to GitHub

### Clone & open

```bash
git clone git@github.com:vrushankvaria01/serveSpeedApp.git
cd serveSpeedApp
open ServeSpeed/ServeSpeed.xcodeproj
```

### Configure the target

In Xcode, select the `ServeSpeed` target → **Signing & Capabilities**:

1. Tick **Automatically manage signing**
2. Set **Team** to your personal Apple ID
3. Change the **Bundle Identifier** to something unique (e.g. `com.yourname.servespeed`)

### Run on your iPhone

1. Plug the iPhone in via USB; tap **Trust This Computer**.
2. On the iPhone: **Settings → Privacy & Security → Developer Mode** → On → restart.
3. In Xcode, pick your iPhone as the run destination → ⌘R.
4. First launch may fail with an untrusted-developer prompt. On the iPhone: **Settings → General → VPN & Device Management** → trust your Apple ID developer cert. Then ⌘R again.

Free-tier signed apps expire every 7 days — just re-run from Xcode to refresh.

### Field test

- Mount the phone behind the server, **6–10 ft back from the baseline**, on a tripod or fence-clip. Phone in portrait.
- Daylight only for now — 240 fps eats a lot of light and indoor courts make the tracker noisy.
- Open the app → Calibrate Court → tap the four corners of the far service box, in the order the on-screen labels ask for.
- Tap the red shutter → hit a serve → tap stop. Speed shows up in MPH and KM/H.

## Challenges & pivots

### Why not 4K @ 60 fps?

Originally we leaned toward 4K/60 for crisper images, but the math killed it: a 120 mph serve covers ~3 ft per frame at 60 fps and motion-blurs into a streak that no detector can localize accurately. **Pivoted to 1080p @ 240 fps** — frames are softer but the ball is *findable*, which is the whole game.

### Average velocity vs. peak velocity

The popular existing iOS app (SwingVision) reports speeds about **20% lower than radar** because it averages over the ball's whole flight, by which point air drag has bled a lot of energy. Pro radar guns report **peak velocity right after racquet contact**. We rewrote the speed calculator to clamp to the early-flight window and take the max inter-frame velocity, which is much closer to the TV number.

### Court calibration: auto-detect vs. manual tap

Auto-detecting court lines with Vision sounded slick but failed on worn or shadowed courts in informal tests of related projects. We shipped a manual **four-corner tap** instead — 10 seconds of setup per session, but rock solid. Automatic detection is a v2 candidate.

### Trajectory detection: built-in vs. custom CoreML

Open-source TrackNet variants on PyTorch are state of the art for tennis-ball tracking, but converting and embedding them adds ~50 MB and a week of work. For the MVP we use Apple's **`VNDetectTrajectoriesRequest`**, which is built into the OS, free, and good enough for a serve's clean parabolic flight. A custom TrackNet → CoreML conversion is on the roadmap if accuracy plateaus.

### Ground-plane homography on a ball-in-air

A 4-point homography projects screen pixels onto the court *plane*. The ball at contact is ~8–9 ft in the air, which introduces a parallax error vs. its true position. For early-flight speed estimation over a short window, the error is small and we accept it. A 3D reconstruction with a known camera height would close this gap — also v2.

### Landscape → Portrait UX call

Physics favors landscape (ball travels across more pixels), but a portrait camera inside a landscape UI looked rotated and broken. **Shipped portrait** with a small accuracy cost; the UX win was worth it.

## Project structure

```
serveSpeedApp/
├── README.md
├── .gitignore
├── Info-snippets-reference.plist     # Reference for required privacy keys
└── ServeSpeed/                       # Xcode project
    ├── ServeSpeed.xcodeproj/
    └── ServeSpeed/                   # App target sources
        ├── ServeSpeedApp.swift       # @main entry
        ├── ContentView.swift         # Root view + state machine
        ├── Theme.swift               # Colors, fonts, buttons, haptics
        ├── CameraManager.swift       # AVCaptureSession at 1080p/240fps
        ├── CameraPreview.swift       # SwiftUI wrapper around preview layer
        ├── CalibrationView.swift     # 4-corner tap overlay
        ├── Homography.swift          # 4-point image→court homography
        ├── TrajectoryAnalyzer.swift  # VNDetectTrajectoriesRequest pipeline
        ├── SpeedCalculator.swift     # Peak-velocity speed calc
        ├── Info.plist
        └── Assets.xcassets/
```

## Roadmap

- [ ] Audio-based contact detection (mic transient → exact contact timestamp)
- [ ] Custom TrackNet CoreML model for tougher lighting / cluttered backgrounds
- [ ] 3D ball-position reconstruction to remove ground-plane parallax error
- [ ] Auto court-line detection (skip the four-corner tap)
- [ ] Serve history with charts, personal best, fastest serve replay
- [ ] Apple Watch companion for one-tap recording
- [ ] Indoor-court support (lower fps fallback, gain compensation)

## License

TBD. Not yet open-sourced for redistribution.

---

Built with [Claude Code](https://claude.com/claude-code).
