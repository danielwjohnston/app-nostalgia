# App Nostalgia: Excite Assistant & Excite Messenger (1999–2000)

A pixel-identical, native macOS AppKit recreation of the iconic non-rectangular 1999 **Excite Assistant** and 2000 **Excite Messenger** desktop tactile appliances, engineered from reverse-engineered x86 disassembly of original dot-com binaries (`Assistant.exe` and `em.exe`).

Wired into modern keyless live services and an authenticated **Ollama AI Chatbot** with **1Password** integration across vintage Excite dot-com engineer personas.

---

## Features

### 1. Authentic 1999/2000 Tactile Hardware GUI
- **True Non-Rectangular Borderless Appliance**: Borderless transparent AppKit window rendering exact 1999 8-bit RLE sprites (`bmp_317.png`, `bmp_342.png`, `bmp_132.png`, `em2000.png`).
- **Constructive Solid Geometry (CSG) Math**: 9 concave scalloped navigation tabs tucked under each other using exact boolean region subtraction (`CombineRgn(RGN_DIFF)`).
- **Decompiled `TSlidingWins` Ease-Out Physics**: The motorized drawer slides out and in using the original x86 shift-right integer physics (`sar ecx, 3`: remaining distance divided by 8 per frame).
- **Dual-Ballistic 14-LED Hardware VU Meter**: The 14 sunken wells on the TuneIn player deck are mapped to the original 1999 bitmap slots (`x = 194 + i * 8, y = 230, w = 5, h = 9`). Features real-time attack, smooth 300ms exponential decay, and a floating peak-hold diode.
- **9 Original Wave Audio Effects**: Authentic tactile mechanical clicks, chirps, swooshes, and pings extracted from 1999 Win32 resources (`wav356` through `wav420`).
- **1999 Tan / 2000 Titanium Slate Skin**: Instant switching between the classic warm putty dot-com skin and the titanium slate millennium redesign.

### 2. Multi-Scale & Clean Screen Mode
- **Clean Pod Mode (Default)**: Window hugs the pod perfectly ($330\text{px} \times 290\text{px}$ at 1.0x). No floating debug artifacts or empty transparent space.
- **Flyout Controls (`Cmd+D`)**: Toggle flyout pill buttons on demand, expanding the window smoothly.
- **Dynamic Scaling (`Cmd+1` .. `Cmd+4`)**:
  - `1.0x`: Original 1999 72dpi size ($330 \times 290\text{pt}$).
  - `1.25x`: Balanced laptop size ($412.5 \times 362.5\text{pt}$).
  - `1.5x`: High-legibility default ($495 \times 435\text{pt}$).
  - `2.0x`: Pixel-doubled Retina integer scaling ($660 \times 580\text{pt}$).
- **Full macOS Application Menu Bar**: Standard `Excite Assistant` (Quit `Cmd+Q`, About, Prefs `Cmd+,`), `File` (`Cmd+W`, `Cmd+N`), `Edit` (`Cmd+C`, `Cmd+V`, `Cmd+A`), `View` (Scales, Flyouts, Skins, Drawer), `TuneIn Audio`, and `Messenger & AI` menus.

### 3. Excite Messenger Chat & Ollama AI Tie-In
- **Detachable Titanium IM Window**: Floating borderless titanium window styled after `em.exe` (2000).
- **Ollama AI Personas**: Real-time LLM chat integrated via local Ollama (`localhost:11434`) or authenticated endpoints:
  - **Scott Werndorfer** (`swerndorfer@excite.com`): Lead engineer who wrote `TSlidingWins` in VC++ 6.0 / MFC 4.2.
  - **Kevin Kurtz** (`kkurtz@excite.com`): UI and region graphics engineer who carved the scalloped CSG curves.
  - **C.J.klug** (`cjklug@excite.com`): Systems and broadband architect, streaming live SomaFM audio.
  - **Excite Live Bot**: Knowledgeable companion aware of vintage 1999 and modern 2026 tech.
- **Live "Typing..." Status**: Real-time instant messenger typing indicator while Ollama streams tokens.
- **Bottom-Pinned Auto-Wrapping Transcript**: Multi-line responses wrap automatically and stay pinned to the newest incoming messages.
- **1Password Integration**:
  - Direct 1Password CLI (`op`) detection on Intel & Apple Silicon.
  - Reads keys via `op item get --reveal`, `op://` Secret References, or GUI modal dialog.
  - In-chat instant commands: `/key <token>`, `/model <name>`, `/host <url>`, `/op [item]`, `/status`.

### 4. Modern Keyless Live Feeds
| Pod Station | Live Service Backend |
| :--- | :--- |
| **TuneIn Radio** | Real-time SomaFM streams (Groove Salad, Secret Agent, DEF CON Radio, Underground 80s, Left Coast 70s, Lush) with live track metadata. |
| **News** | Live 6-subtab feed: Hacker News Firebase API, Spaceflight News, Reddit tech/business, ESPN. |
| **Weather** | Open-Meteo 5-day forecast + Geocoding city search mapped to 11 original `bmp_318` sprites. |
| **Stocks** | CoinGecko live cryptocurrency and financial quotes with color-coded 24h change. |
| **TV Listings** | TVMaze live US prime-time schedule and episode ratings. |
| **Deals** | CheapShark software and gaming discounts. |
| **Instant Search** | Wikipedia live search API with excerpt extraction. |

---

## Automated Product Test Matrix
The project includes a complete test harness in `Tests/TestMatrixRunner.swift` testing **127 assertions** across all UI elements, hit-tests, audio ballistics, and LLM hooks:
- **Tab Visuals & Masks**: 27 / 27 PASS
- **Reverse $z$-Order Hit-Testing**: 27 / 27 PASS
- **News 6-Subtabs Strip**: 12 / 12 PASS
- **Bottom 4-Button Toolbar**: 8 / 8 PASS
- **Hardware Orbs**: 4 / 4 PASS
- **TuneIn & 14-LED VU Meter**: 12 / 12 PASS
- **Right Bezel & Close `[X]`**: 4 / 4 PASS
- **Window Scaling & Flyout Sizing**: 8 / 8 PASS
- **Chat Window, Contrast & Personas**: 8 / 8 PASS
- **Assets & Wave Audio Integrity**: 17 / 17 PASS

*Total: 127 / 127 Passed (0 Failed, 100% Success).* See [`PRODUCT_TEST_MATRIX.md`](PRODUCT_TEST_MATRIX.md) for detailed results.

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Cmd + Q` | **Quit Excite Assistant** |
| `Cmd + W` | **Close Active Window** |
| `Cmd + ,` | **Preferences / Ollama & 1Password AI Settings** |
| `Cmd + 1` .. `4` | **Set Pod Scale** (1.0x, 1.25x, 1.5x, 2.0x) |
| `Cmd + D` | **Toggle Flyout Debug Controls** |
| `Cmd + K` | **Collapse / Expand Sliding Drawer** |
| `Cmd + T` | **Switch Skin** (1999 Tan / 2000 Titanium Slate) |
| `Cmd + X` | **Toggle CSG HRGN X-Ray Wireframe** |
| `Cmd + N` | **Open Excite Messenger Chat Session** |
| `Cmd + P` | **Play / Pause TuneIn Radio** |
| `Cmd + ]` / `[` | **Next / Previous Radio Channel** |
| `Cmd + R` | **Refresh All Live Feeds** |

---

## Quick Start

### Build & Run
```bash
# Clone the repository
git clone https://github.com/danielwjohnston/app-nostalgia.git
cd app-nostalgia

# Run the app bundle directly
./run.sh
```

Or build with Swift Package Manager:
```bash
swift build
./.build/debug/ExciteMessenger
```

Run the automated test matrix:
```bash
swift Tests/TestMatrixRunner.swift
```

---

## Documentation References
- [`PRODUCT_TEST_MATRIX.md`](PRODUCT_TEST_MATRIX.md) — 127-point test matrix and verification logs.
- [`excite_gui_decompilation.md`](excite_gui_decompilation.md) — Low-level x86 decompilation reference (`TSlidingWins`, `CombineRgn`, `SetWindowRgn`).
- [`capsule_drawer_design_system.md`](capsule_drawer_design_system.md) — Y2K tactile Capsule & Drawer design system specification.
