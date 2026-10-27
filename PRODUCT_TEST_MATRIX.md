# Excite Assistant & Messenger — Product Test Matrix

This matrix documents the automated test suite (`Tests/TestMatrixRunner.swift`) covering every visual state, concave region hit-test, interactive control, audio ballistic curve, and LLM persona integration across the appliance.

**Test Run Summary:**
- **Total Assertions:** 159
- **Passed:** 159 (100%)
- **Failed:** 0

---

## Suite 1: Asset Suite & Sprite Integrity
| Test Case | Target Asset | Dimensions / Spec | Result | Details |
| :--- | :--- | :--- | :--- | :--- |
| Asset bmp317.png | `bmp317.png` | 600×481 8-bit RLE sheet | **PASS** | Loaded 600×481 master Win32 sprite sheet |
| Asset bmp342.png | `bmp342.png` | 234×33 header | **PASS** | Top drawer header "eXcite ASSISTANT" |
| Asset bmp318.png | `bmp318.png` | 440×31 strip | **PASS** | 11 weather sprites (40×31 each) |
| Asset bmp132.png | `bmp132.png` | 234×60 promo | **PASS** | "We Help Personalize Your Web Experience!" banner |
| Asset bmp124.png | `bmp124.png` | 235×30 strip | **PASS** | Normal state 6-news subtabs |
| Asset bmp146.png | `bmp146.png` | 235×30 strip | **PASS** | Hover state 6-news subtabs |
| Asset bmp170.png | `bmp170.png` | 235×30 strip | **PASS** | Active state 6-news subtabs |
| Asset bmp229.png | `bmp229.png` | 600×48 strip | **PASS** | 12 Zodiac medallions (50×48 each) |
| Asset em2000.png | `em2000.png` | 840×630 sheet | **PASS** | Titanium Excite Messenger chassis sheet |
| Wave Audio Files | `wav356..wav420` | 9 original WAVs | **PASS** | 9 tactile 1999 sound effects present |

---

## Suite 2: Tab Visuals, Text Alignment & Alpha Masking
*Ensures every tab's normal, hover, and active states use exact pixel offsets from `bmp_317` and that hover/active strips are masked strictly to the 671-pixel concave cutout silhouette.*

| Tab ID | Tab Name | Normal Slice $(x, y)$ | Hover / Active $y$ | Alpha Masking | Text Alignment | Status |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: |
| **0** | Email | `(221, 58)` | $y = 31$ | Silhouette `.sourceIn` | Center $y=48$ | **PASS** |
| **1** | Search | `(283, 28)` | $y = 51$ | Silhouette `.sourceIn` | Center $y=68$ | **PASS** |
| **2** | News | `(221, 148)` | $y = 70$ | Silhouette `.sourceIn` | Center $y=87$ (Verified News, not Search) | **PASS** |
| **3** | TV Listings | `(283, 58)` | $y = 88$ | Silhouette `.sourceIn` | Center $y=105$ | **PASS** |
| **4** | TuneIn | `(283, 118)` | $y = 108$ | Silhouette `.sourceIn` | Center $y=125$ | **PASS** |
| **5** | Stocks | `(221, 118)` | $y = 127$ | Silhouette `.sourceIn` | Center $y=144$ | **PASS** |
| **6** | Weather | `(283, 88)` | $y = 146$ | Silhouette `.sourceIn` | Center $y=163$ | **PASS** |
| **7** | Horoscopes | `(221, 88)` | $y = 165$ | Silhouette `.sourceIn` | Center $y=182$ | **PASS** |
| **8** | Deals | `(221, 28)` | $y = 184$ | Silhouette `.sourceIn` | Center $y=201$ | **PASS** |

---

## Suite 3: Reverse $z$-Order Scalloped Hit-Testing
*Verifies that concave scalloped tabs lower on the vertical rail take precedence in overlap zones.*

| Tab Name | Center Hit $(x=30)$ | Top Curve Hit $(x=20)$ | Scallop Overlap Edge | Result |
| :--- | :---: | :---: | :---: | :---: |
| **Email** ($dy: 56$) | Point $(30, 71) \to$ Tab 0 | Point $(20, 58) \to$ Tab 0 | Point $(20, 84) \to$ Tab 1 (Resolved) | **PASS** |
| **Search** ($dy: 75$) | Point $(30, 90) \to$ Tab 1 | Point $(20, 77) \to$ Tab 1 | Point $(20, 103) \to$ Tab 2 (Resolved) | **PASS** |
| **News** ($dy: 94$) | Point $(30, 109) \to$ Tab 2 | Point $(20, 96) \to$ Tab 2 | Point $(20, 122) \to$ Tab 3 (Resolved) | **PASS** |
| **TV Listings** ($dy: 113$) | Point $(30, 128) \to$ Tab 3 | Point $(20, 115) \to$ Tab 3 | Point $(20, 141) \to$ Tab 4 (Resolved) | **PASS** |
| **TuneIn** ($dy: 132$) | Point $(30, 147) \to$ Tab 4 | Point $(20, 134) \to$ Tab 4 | Point $(20, 160) \to$ Tab 5 (Resolved) | **PASS** |
| **Stocks** ($dy: 151$) | Point $(30, 166) \to$ Tab 5 | Point $(20, 153) \to$ Tab 5 | Point $(20, 179) \to$ Tab 6 (Resolved) | **PASS** |
| **Weather** ($dy: 170$) | Point $(30, 185) \to$ Tab 6 | Point $(20, 172) \to$ Tab 6 | Point $(20, 198) \to$ Tab 7 (Resolved) | **PASS** |
| **Horoscopes** ($dy: 189$) | Point $(30, 204) \to$ Tab 7 | Point $(20, 191) \to$ Tab 7 | Point $(20, 217) \to$ Tab 8 (Resolved) | **PASS** |
| **Deals** ($dy: 208$) | Point $(30, 223) \to$ Tab 8 | Point $(20, 210) \to$ Tab 8 | Point $(20, 236) \to$ Tab 8 (Resolved) | **PASS** |

---

## Suite 4: News 6-Subtab Bar
| Subtab Index | Label | Bounds $(x, y, w, h)$ | Normal / Hover / Active Slices | Result |
| :---: | :--- | :---: | :---: | :---: |
| **0** | Top News | $(76, 38, 78, 15)$ | `bmp124`, `bmp146`, `bmp170` col 0, row 0 | **PASS** |
| **1** | Business | $(154, 38, 78, 15)$ | `bmp124`, `bmp146`, `bmp170` col 1, row 0 | **PASS** |
| **2** | Sci/Tech | $(232, 38, 78, 15)$ | `bmp124`, `bmp146`, `bmp170` col 2, row 0 | **PASS** |
| **3** | Odd | $(76, 53, 78, 15)$ | `bmp124`, `bmp146`, `bmp170` col 0, row 1 | **PASS** |
| **4** | Sports | $(154, 53, 78, 15)$ | `bmp124`, `bmp146`, `bmp170` col 1, row 1 | **PASS** |
| **5** | Photos | $(232, 53, 78, 15)$ | `bmp124`, `bmp146`, `bmp170` col 2, row 1 | **PASS** |

---

## Suite 5: Bottom 4-Button Toolbar
| Button | Hit Rect $(x, y, w, h)$ | Zone Identifier | Action | Result |
| :--- | :---: | :---: | :--- | :---: |
| **Tell a Friend** | $(76, 254, 80, 23)$ | `footer_tell` | Launches Excite Messenger chat window | **PASS** |
| **Personalize** | $(156, 254, 67, 23)$ | `footer_pers` | Toggles 1999 Tan / 2000 Titanium Slate skin | **PASS** |
| **Sign In** | $(223, 254, 47, 23)$ | `footer_sign` | Re-checks buddy online status | **PASS** |
| **Prefs** | $(270, 254, 40, 23)$ | `footer_pref` | Opens Ollama & 1Password AI modal dialog | **PASS** |

---

## Suite 6: Hardware Orbs
| Orb | Hit Rect $(x, y, w, h)$ | Hover Sprite | Click Action | Result |
| :--- | :---: | :---: | :--- | :---: |
| **Top Excite Red Orb** | $(24, 28, 25, 25)$ | `(371, 28, 25, 25)` | Triggers live feed refresh & unread flash | **PASS** |
| **Bottom Help '?' Orb** | $(24, 236, 23, 23)$ | `(369, 106, 23, 23)` | Navigates to Email / help | **PASS** |

---

## Suite 7: TuneIn Deck & 14-LED Hardware VU Meter
*Investigated and confirmed: The 14 sunken gray slots are part of the original 1999 Win32 bitmap `bmp_317` at $(118, 89)$ in the deck slice. The test verifies pixel-exact LED alignment and dual-ballistic animation.*

| Component | Target Coordinates | Dimensions / Specs | Verification Details | Result |
| :--- | :---: | :---: | :--- | :---: |
| **Play Button** | $(77, 226)$ | $36 \times 26$ | Slices `(1, 311)` hover, `(60, 338)` active | **PASS** |
| **Pause Button** | $(114, 226)$ | $36 \times 26$ | Slices `(38, 311)` hover, `(97, 338)` active | **PASS** |
| **Stop Button** | $(151, 226)$ | $36 \times 26$ | Slices `(75, 311)` hover, `(134, 338)` active | **PASS** |
| **Volume Wedge** | $(114..262, 205)$ | $148 \times 14$ | Thumb at $x = 114 + 148 \cdot vol - 3$ | **PASS** |
| **LEDs 0..8 (Green)** | $x = 194 + i \cdot 8, y = 230$ | $5 \times 9$ each | Aligns 100% inside original sunken bitmap wells | **PASS** |
| **LEDs 9..11 (Amber)** | $x = 266, 274, 282, y = 230$ | $5 \times 9$ each | Amber threshold at 65% power level | **PASS** |
| **LEDs 12..13 (Peak Red)** | $x = 290, 298, y = 230$ | $5 \times 9$ each | Red peak threshold at 85% power level | **PASS** |
| **Attack Ballistics** | Instant | $t_{\text{rise}} < 15\text{ms}$ | Level rises instantly on audio transients | **PASS** |
| **Decay Ballistics** | Exponential | $t_{\text{decay}} \approx 300\text{ms}$ | Smooth multiplier decay ($0.84^n$) | **PASS** |
| **Peak Hold Ballistics** | Hold + Step | Hold 350ms | Highest lit segment remains floating before dropping | **PASS** |

---

## Suite 8: Right Bezel & Drawer Collapse
| Component | Coordinates | Action | Result |
| :--- | :---: | :--- | :---: |
| **Right Bezel Slice** | $(76 + dw, 8, 19, 265)$ | Stamped at right end of sliding drawer | **PASS** |
| **Close Box `[X]`** | $(76 + dw + 3..16, 26..40)$ | Click collapses drawer to spine ($dw \to 0$) via `sar ecx, 3` | **PASS** |
| **Double-Click Bezel** | $(x \ge 76 + dw)$ | Toggles debug flyout controls on / off | **PASS** |

---

## Suite 9: Scaling & Flyout Sizing
| Scale Factor | Pod Frame (Clean / Flyouts Hidden) | Pod Frame (Flyouts Visible) | Scaling Multiplier | Result |
| :---: | :---: | :---: | :---: | :---: |
| **1.0x** | $330 \times 290$ pt (Exact 1999 72dpi) | $475 \times 290$ pt | Native 1:1 pixel rendering | **PASS** |
| **1.25x** | $412.5 \times 362.5$ pt | $593.75 \times 362.5$ pt | Balanced laptop size | **PASS** |
| **1.5x** | $495 \times 435$ pt | $712.5 \times 435$ pt | High-legibility desktop size | **PASS** |
| **2.0x** | $660 \times 580$ pt | $950 \times 580$ pt | Pixel-doubled Retina integer scale | **PASS** |

---

## Suite 10: Excite Messenger Chat Window & Ollama Engine
| Feature | Target / Value | Verification Spec | Result |
| :--- | :--- | :--- | :---: |
| **Input Field Contrast** | Dark on Cream White | `textColor` $(0.05, 0.05, 0.12)$, `bg` $(0.99, 0.99, 0.96)$ | **PASS** |
| **Placeholder Text** | High Contrast Gray | `NSAttributedString` placeholder `#61617A` | **PASS** |
| **Transcript Auto-Wrap** | Bottom-Pinned Stacking | Dynamic height calculations from newest backwards | **PASS** |
| **Scott Werndorfer Persona** | `swerndorfer@excite.com` | Lead engineer, `TSlidingWins`, `sar ecx, 3`, VC++ 6.0 | **PASS** |
| **Kevin Kurtz Persona** | `kkurtz@excite.com` | UI region engineer, `CombineRgn(RGN_DIFF)` | **PASS** |
| **C.J.klug Persona** | `cjklug@excite.com` | Systems architect, broadband cable, SomaFM streaming | **PASS** |
| **Excite Live Bot Persona** | `livebot@excite.com` | Ollama AI assistant, vintage 1999 + modern 2026 | **PASS** |
| **Slash Commands** | `/key`, `/model`, `/host`, `/op`, `/status` | Built-in CLI command parser | **PASS** |
| **1Password CLI `op`** | `op item get --reveal`, `op read` | Automated token extraction | **PASS** |

---

## Suite 11: Instant Messaging Window Dynamic Scaling
*Verifies that the Excite Instant Messenger chat window dynamically tracks and inherits pod scale factor (1.0x, 1.25x, 1.5x, 2.0x), maintaining exact proportional window bounds, input field coordinates, font size, and send button alignment.*

| Scale Factor | Chat Window Bounds | Main Pod Height | Input Field Frame | Input Font | Send Button Bounds | Close [X] Geometry | Result |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1.0x** | $260 \times 290$ pt | $290$ pt | $(14, 224, 176, 22)$ | $11.0$ pt | $(196, 224, 52, 22)$ | $(236, 14, 16, 14)$ | **PASS** |
| **1.25x** | $325 \times 362.5$ pt | $362.5$ pt | $(17.5, 280, 220, 27.5)$ | $13.75$ pt | $(245, 280, 65, 27.5)$ | $(295, 17.5, 20, 17.5)$ | **PASS** |
| **1.5x** | $390 \times 435$ pt | $435$ pt | $(21, 336, 264, 33)$ | $16.5$ pt | $(294, 336, 78, 33)$ | $(354, 21, 24, 21)$ | **PASS** |
| **2.0x** | $520 \times 580$ pt | $580$ pt | $(28, 448, 352, 44)$ | $22.0$ pt | $(392, 448, 104, 44)$ | $(472, 28, 32, 28)$ | **PASS** |

---

## Suite 12: Interactive GUI Elements
*Verifies that every GUI element across the tactile appliance performs an appropriate, functional, authentic interaction.*

| Element / Control | Location / Tab | Interaction Trigger | Action Performed | Result |
| :--- | :--- | :--- | :--- | :---: |
| **Live Search Prompt** | Tab #1 (Search) | Click search well or Search button | Opens Wikipedia live search modal prompt & displays results | **PASS** |
| **City Forecast Selector** | Tab #6 (Weather) | Click city name header | Opens worldwide city prompt and refreshes 5-day forecast via Open-Meteo | **PASS** |
| **Zodiac 12-Sign Cycle** | Tab #7 (Horoscopes) | Click Zodiac medallion or `< Sign` | Cycles all 12 astrological signs with live daily horoscope readings | **PASS** |
| **`< Networks` Station Picker** | Tab #4 (TuneIn) | Click `< Networks` header button | Displays popup menu with all live SomaFM stream channels | **PASS** |
| **Excite Member Sign In** | Bottom Toolbar (Button 3) | Click `Sign In` | Opens Member Name, 1Password credentials, and Presence selector | **PASS** |
| **Assistant Help Guide** | Bottom Orb (Left Rail) | Click `'?'` help sphere | Displays comprehensive Y2K tactile appliance guide & shortcut map | **PASS** |
| **News Deep Link Rows** | Tab #2 (News) | Click headline row | Opens full news article in browser | **PASS** |
| **Stock Quote Rows** | Tab #3 (Stocks) | Click ticker symbol | Opens Yahoo Finance market summary in browser | **PASS** |
| **TV Listing Rows** | Tab #5 (TV/Movies) | Click show title | Opens entertainment guide in browser | **PASS** |
| **Deal Bargain Rows** | Tab #8 (Deals) | Click bargain deal | Opens shopping link in browser | **PASS** |
| **Buddy List Rows** | Tab #0 (Buddies) | Click buddy row | Opens direct instant message session with selected engineer/bot | **PASS** |
