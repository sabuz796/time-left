# Time Left — Menu Bar, 100% On-Device 🔒

<p align="center">
  <img src="images/time-left-icon.svg" width="128" alt="Time Left icon">
</p>

> “Don’t waste your time in anger, regrets, worries, and grudges. Life is too short to be unhappy.”
> — Roy T. Bennett

Minimal macOS menu bar app that shows how much of your **day / week / month / year** has passed — plus a **built-in countdown timer** (5m–1h). No network, no tracking, no data leaves your Mac.

![Swift](https://img.shields.io/badge/Swift-6.3-orange) ![macOS](https://img.shields.io/badge/macOS-13+-blue) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

## 🤔 What is this?

**Time Left is a tiny app that reminds you life is passing — in a good way.**

It lives quietly in your macOS menu bar as a small `⏳ Y: 71%` icon. Click it and you get a popover with an **animated progress ring** showing how much of the **day, month, or year** has already passed — and how much is left, in plain numbers ("104 days left"). Pick the scope you care about, tick **Launch at Login**, and let it sit there as a gentle nudge to make the rest count.

- 🕐 **Day** — "20h 35m left of today"
- 📅 **Week** — "3 days left"
- 📅 **Month** — "12 days left"
- 🗓️ **Year** — "104 days left"
- ⏱️ **Timer** — pick 5/10/15/30/60 min and the menu bar counts down live (`9:41`, or `1:04:09` for an hour+). Persists across quit/relaunch, gentle notification when time's up
- 🔋 **~0.5 MB, no window, no dock icon, no network** — it just works, all day, on every Mac from macOS 13+ (Apple Silicon and Intel)

For anyone who likes a quiet reminder that time is the one thing you can't get back. ⏳

## 📸 Screenshots

<p align="center">
  <img src="images/day.png" width="22%" alt="Day view">
  &nbsp;
  <img src="images/week.png" width="22%" alt="Week view">
  &nbsp;
  <img src="images/month.png" width="22%" alt="Month view">
  &nbsp;
  <img src="images/year.png" width="22%" alt="Year view">
</p>
<p align="center"><i>Day • Week • Month • Year — switch scopes with the pills, the ring and menu-bar label follow. <b>Launch at Login</b> keeps Time Left running from day one.</i></p>

## Install (one file)

1. Build or grab `dist/TimeLeft.dmg` from a release (universal binary — Apple Silicon and Intel)
2. Double-click → drag `TimeLeft.app` → `Applications`
3. Open `TimeLeft` — find `⏳ Y: 71%` in menu bar → click for Day/Week/Month/Year scopes, the countdown Timer, animated ring, and the Launch-at-Login toggle

> 🔒 **Privacy friendly — absolutely nothing leaves this machine.** All calculations run locally in `YearPassing/TimeCalculations.swift` using `Calendar.current`. No `URLSession`, no analytics.

## ⚠️ macOS blocked the app?

If macOS shows *"TimeLeft can't be opened because it is from an unidentified developer"* or *"damaged and can't be opened"* (common for unsigned apps downloaded from the internet), remove the quarantine flag and open it:

```bash
xattr -cr /Applications/TimeLeft.app
```

Then open the app normally. This only clears Gatekeeper's quarantine attribute — the app is fully local and touches nothing outside your Mac.

## Swift only, butter smooth

* **Pure SwiftUI** — `MenuBarExtra` + `ProgressView` + `Calendar` (no JS/Python/deps, `otool -L` shows only SwiftUI/AppKit/Foundation plus ServiceManagement and UserNotifications)
* **Selectable scope** — Day/Week/Month/Year pills + rows; choice persists via `@AppStorage`; tray label follows (`D: 64%` / `W: 57%` / `M: 55%` / `Y: 71%`)
* **Countdown timer** — presets 5/10/15/30/60 min; menu bar shows `m:ss` (or `h:mm:ss` for 1h+) only while a timer runs; end date is persisted so the countdown survives quit/relaunch; "Time's up" notification on finish
* **Launch at Login** — checkbox in the popover, backed by `SMAppService`
* **Timed** — refreshes every 0.5s via `Timer.publish` (keeps the countdown live)

## Dev

```bash
# build + run instantly (no install) — your edit-test loop
./scripts/dev.sh

# build the app bundle (build/.apps/TimeLeft.app — hidden so Launchpad shows only /Applications)
./scripts/build.sh

# rebuild the DMG (dist/TimeLeft.dmg)
./scripts/build-dmg.sh
```

## Releasing

```bash
# tag a release (triggers GitHub Actions → builds DMG + publishes release automatically)
git tag v1.2
git push origin v1.2
```

Or manually: `./scripts/build-dmg.sh` → GitHub → Releases → New release → attach `dist/TimeLeft.dmg`.

## Structure

```
scripts/build.sh            // swiftc → build/.apps/TimeLeft.app (universal, re-signed)
scripts/dev.sh              // build + run without installing
scripts/build-dmg.sh        // hdiutil → dist/TimeLeft.dmg
scripts/gen_icon.swift      // app icon generator (run by build.sh)
YearPassing/YearPassingApp.swift   // MenuBarExtra: pills, ring hero, selectable rows, countdown timer, launch-at-login toggle
YearPassing/TimeCalculations.swift// pure Calendar math + Scope enum
YearPassing/Info.plist            // LSUIElement, AppIcon
```

MIT — build locally, share the DMG.
