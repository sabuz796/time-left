import AppKit
import SwiftUI
import ServiceManagement
import UserNotifications

extension Scope {
    /// Ring and bar colors. One hex per scope per appearance — the lighter
    /// set for light mode, a lifted set for dark so the bars don't sink into
    /// a dark panel. No derived/interpolated values: these are the palette.
    var color: Color {
        switch self {
        case .day: adaptive(light: 0x5B9BD5, dark: 0x7BB8E8)
        case .week: adaptive(light: 0x9B7EBD, dark: 0xB39DDB)
        case .month: adaptive(light: 0x6BBF8A, dark: 0x8FD4A8)
        case .year: adaptive(light: 0xFF9A8B, dark: 0xFFB3A1)
        case .timer: adaptive(light: 0xF2B35A, dark: 0xF7C56B)
        }
    }

    /// An NSColor that re-resolves against the current appearance, so the
    /// ring re-tints on the fly when the user switches system theme.
    private func adaptive(light: Int, dark: Int) -> Color {
        func rgb(_ hex: Int) -> NSColor {
            NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1)
        }
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? rgb(dark)
                : rgb(light)
        })
    }
}

/// Press state for the panel's custom capsule buttons. `.plain` drops it
/// entirely; the system styles bring a bezel that double-stacks on our
/// capsule fills. Press only — no hover or focus ring (see .focusable()).
private struct CapsulePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.55 : 1)
    }
}

@main
struct YearPassingApp: App {
    @State private var progress = calculateProgress()
    @AppStorage("selectedScope") private var selectedScopeRaw = Scope.year.rawValue
    @AppStorage("timerDurationMinutes") private var timerDurationMinutes = 5
    @AppStorage("timerStartedMinutes") private var timerStartedMinutes = 0
    @AppStorage("timerEndDate") private var timerEndDateRaw = 0.0      // 0 = no timer
    @AppStorage("timerNotifiedEndDate") private var notifiedEndDateRaw = 0.0
    @State private var now = Date()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var bounceUp = false
    @State private var notificationsAllowed = true
    /// Bumped each minute so `calculateProgress` runs 60× less often (#7).
    @State private var lastProgressMinute = -1

    // MARK: - Panel rhythm (one scale: 4 / 8 / 12 / 16 / 20)
    private enum Pad {
        static let outer: CGFloat = 20
        static let gap: CGFloat = 16
        static let row: CGFloat = 8
        static let pill: CGFloat = 7
    }

    // MARK: - Timer state (persisted: survives quit/relaunch, wall-clock based)
    // Math lives in TimerLogic (TimeCalculations.swift); these are thin delegates.

    private var timerRunning: Bool {
        TimerLogic.isRunning(endRaw: timerEndDateRaw, now: now)
    }

    private var timerExpired: Bool {
        TimerLogic.isExpired(endRaw: timerEndDateRaw, now: now)
    }

    private var flashActive: Bool {
        TimerLogic.flashActive(endRaw: timerEndDateRaw, now: now)
    }

    private var timerRemaining: TimeInterval {
        TimerLogic.remaining(endRaw: timerEndDateRaw, now: now)
    }

    private var timerElapsedFraction: Double {
        TimerLogic.elapsedFraction(endRaw: timerEndDateRaw, durationMinutes: startedMinutes, now: now)
    }

    /// The duration this timer was started with, not the currently selected
    /// preset — the chips are disabled mid-timer but the plist survives a
    /// relaunch, and a changed divisor would silently move the ring or name
    /// the wrong duration in the notification.
    private var startedMinutes: Int {
        timerStartedMinutes > 0 ? timerStartedMinutes : timerDurationMinutes
    }

    /// Clears the timer. Leaves the panel on the Timer tab so the next run is
    /// one tap away — the label reports "no timer" rather than a bogus "T: 0%".
    private func resetTimer() {
        timerEndDateRaw = 0
        timerStartedMinutes = 0
        notifiedEndDateRaw = 0
    }

    private func startTimer() {
        timerStartedMinutes = timerDurationMinutes
        timerEndDateRaw = Date().addingTimeInterval(Double(timerDurationMinutes) * 60).timeIntervalSince1970
        notifiedEndDateRaw = 0
        // Permission is asked at launch, not here: prompting over the menu bar
        // panel mid-press means a dismissal silently kills the notification.
    }

    private func fireTimerDoneNotification(durationMinutes: Int) {
        // The Glass chime plays via NSSound (works even in Do Not Disturb);
        // don't also set content.sound or the alert chimes twice.
        if notificationsAllowed { NSSound(named: NSSound.Name("Glass"))?.play() }
        let content = UNMutableNotificationContent()
        content.title = "⏰ Time's up"
        content.body = "Your \(durationMinutes) minute timer finished."
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "timer-done", content: content, trigger: nil)
        )
    }

    private func handleTimerTick() {
        guard timerExpired else { return }
        let since = TimerLogic.sinceExpiry(endRaw: timerEndDateRaw, now: now)
        if notifiedEndDateRaw != timerEndDateRaw {
            notifiedEndDateRaw = timerEndDateRaw
            if since < 60 {
                fireTimerDoneNotification(durationMinutes: startedMinutes)
            }
        }
        if since >= TimerLogic.flashSeconds {
            // resetTimer also leaves the Timer tab — otherwise the label falls
            // through to "T: 0%", since progress.value(for: .timer) is always 0.
            resetTimer()
        }
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at Login toggle failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var selectedScope: Scope {
        Scope(rawValue: selectedScopeRaw) ?? .year
    }

    private func select(_ scope: Scope) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selectedScopeRaw = scope.rawValue
        }
    }

    /// Start-button fill. Timer scope colour, both appearances — the old
    /// #C0392B red no longer belongs to the palette.
    private static let timerFill = Scope.timer.color

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: Pad.gap) {
                scopePills
                ringHero(scope: selectedScope)
                // Small air above the swap region: the ring's stroke bleeds
                // into this seam, so it can't be zero — but it doesn't need 24pt.
                Color.clear
                    .frame(height: 8)
                // ZStack (not VStack) so the two blocks share space during the
                // crossfade — a stacked if/else briefly holds both, shoving the
                // content below down before it settles back up.
                ZStack {
                    if selectedScope == .timer {
                        timerControls
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    } else {
                        scopeRows
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    }
                }
                // Report the swap region's true height. Without this the panel
                // remembers the taller scopeRows and Timer sits in a void.
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Divider()
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { toggleLaunchAtLogin($0) }
                ))
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                Text("“Life is too short to be unhappy.”")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                HStack(spacing: Pad.row + 2) {
                    Link(destination: URL(string: "https://github.com/sabuz796/time-left/issues")!) {
                        Label("Report Bug", systemImage: "exclamationmark.bubble")
                            .font(.callout)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Pad.pill)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                            .foregroundStyle(.secondary)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(CapsulePress())

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Text("Quit")
                    }
                    .keyboardShortcut("q")
                    .font(.callout)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Pad.pill)
                    .background(Capsule().fill(Color.primary.opacity(0.07)))
                    .foregroundStyle(.secondary)
                    .contentShape(Capsule())
                    .buttonStyle(CapsulePress())
                }
            }
            .padding(.horizontal, Pad.outer)
            .padding(.vertical, Pad.gap)
            .frame(minWidth: 260, idealWidth: 280)
            // The default MenuBarExtra window material is near-transparent,
            // so text sat directly over whatever was behind the panel. A
            // solid adaptive window background keeps it legible.
            .background(Color(nsColor: .windowBackgroundColor))
        } label: {
            // The clock lives on the label, not the panel: MenuBarExtra
            // instantiates its content lazily, so a timer attached there only
            // ticks while the panel is open — freezing the menu bar countdown
            // and never asking for notification permission.
            HStack(spacing: 3) {
                // Stopwatch = timer context, hourglass = a period passing. The
                // Timer tab keeps the stopwatch even when idle, so the panel
                // and the bar agree on which scope is open.
                Image(systemName: (timerRunning || flashActive || selectedScope == .timer) ? "stopwatch" : "hourglass")
                if timerRunning {
                    Text(TimerLogic.countdownText(timerRemaining))
                        .monospacedDigit()
                } else if flashActive {
                    let blink = Int(now.timeIntervalSince1970 * 2) % 2 == 0
                    Text(blink ? "Done ✅" : "Time's up")
                        .monospacedDigit()
                } else if selectedScope == .timer {
                    // No timer, Timer tab open: say so. progress.value(for:
                    // .timer) is 0 by design, so a percentage here would be
                    // a wrong number in an app showing a right one.
                    Text("timer")
                } else {
                    Text("\(selectedScope.letter): \(Int(progress.value(for: selectedScope) * 100))%")
                        .monospacedDigit()
                }
            }
            .onReceive(timer) { _ in
                now = Date()
                if flashActive { bounceUp.toggle() }
                // Calendar math is per-minute-accurate; the tick is 0.5s.
                let minute = Calendar.current.component(.minute, from: now)
                if minute != lastProgressMinute {
                    lastProgressMinute = minute
                    progress = calculateProgress(now: now)
                }
                handleTimerTick()
            }
            .task {
                // Asked once at launch, never over the panel mid-press.
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                notificationsAllowed = (settings.authorizationStatus == .authorized
                                        || settings.authorizationStatus == .provisional)
                if settings.authorizationStatus == .notDetermined {
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                    let after = await UNUserNotificationCenter.current().notificationSettings()
                    notificationsAllowed = (after.authorizationStatus == .authorized
                                            || after.authorizationStatus == .provisional)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func ringHero(scope: Scope) -> some View {
        let isTimer = scope == .timer
        let pct = isTimer ? timerElapsedFraction : progress.value(for: scope)
        return ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 10)
            Circle()
                // No timer = empty track. pct is 0 when idle, so `1 - pct`
                // trimmed to 1.0 and drew a full ring around "no timer" —
                // reading as 100% complete with nothing running.
                .trim(from: 0, to: isTimer
                    ? (timerRunning || flashActive ? 1 - pct : 0)
                    : pct)
                .stroke(scope.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: scope)
            VStack(spacing: 2) {
                if isTimer {
                    if timerRunning {
                        Text(TimerLogic.countdownText(timerRemaining))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if timerExpired {
                        Text("Done ✅")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .offset(y: bounceUp ? -3 : 3)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: bounceUp)
                        Text("timer finished")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "stopwatch")
                            .font(.system(size: 30))
                            .foregroundStyle(scope.color)
                        Text("no timer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(timeLeftLabel(for: scope, now: now))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .id(scope)
                        .transition(.opacity)
                }
            }
        }
        .frame(width: 120, height: 120)
    }

    private var timerControls: some View {
        VStack(spacing: Pad.row + 2) {
            HStack(spacing: Pad.row) {
                ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                    let selected = timerDurationMinutes == minutes
                    Button {
                        timerDurationMinutes = minutes
                    } label: {
                        Text(minutes >= 60 ? "1h" : "\(minutes)m")
                            .font(.callout.weight(selected ? .semibold : .regular))
                            .monospacedDigit()
                            // Unselected uses .primary, not .secondary: the
                            // amber tint barely moves contrast either way
                            // (2.38:1 at 7%, 2.33:1 at 22%), so the text colour
                            // is the only lever that matters — primary is
                            // 7.4:1 against the tint, secondary is 2.3:1.
                            // Selected is solid amber + black, matching Start.
                            .foregroundStyle(selected ? Color.black : Color.primary)
                            .padding(.horizontal, Pad.pill)
                            .padding(.vertical, Pad.pill)
                            .background(
                                Capsule().fill(selected
                                    ? Scope.timer.color
                                    : Scope.timer.color.opacity(0.15))
                            )
                            .contentShape(Capsule())
                    }
                    // Equal fifths so the presets read as one row.
                    .frame(maxWidth: .infinity)
                    .buttonStyle(CapsulePress())
                    .disabled(timerRunning)
                }
            }
            Button {
                timerRunning ? resetTimer() : startTimer()
            } label: {
                Label(timerRunning ? "Stop" : "Start", systemImage: timerRunning ? "stop.fill" : "play.fill")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Pad.row)
                    .background(
                        // One style for both states. The running state used a
                        // 18% amber wash with amber text — faint twice over.
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Self.timerFill)
                    )
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(CapsulePress())
            if timerRunning {
                Text("Menu bar shows the countdown, even if you quit and reopen.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Scope selector across the top. Kept alongside the scope rows on
    /// purpose: the pills pick the scope, the rows show every scope at once.
    private var scopePills: some View {
        HStack(spacing: 4) {
            ForEach(Scope.allCases, id: \.self) { scope in
                Button {
                    select(scope)
                } label: {
                    Text(scope.name)
                        .font(.callout.weight(selectedScope == scope ? .semibold : .regular))
                        // Color.primary, not scope.color: the palette hexes
                        // are pastel and wash out on their own tinted capsule.
                        .foregroundStyle(selectedScope == scope ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(scope.color.opacity(selectedScope == scope ? 0.25 : 0))
                        )
                        .contentShape(Capsule())
                }
                // CapsulePress, not .plain: the system styles bring a bezel
                // that double-stacks on the capsule fills.
                .buttonStyle(CapsulePress())
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }

    private var scopeRows: some View {
        VStack(spacing: Pad.row) {
            // Timer is a pill, not a row — it has no percentage to report, so
            // showing it here only ever rendered an empty track and a dash.
            ForEach(Scope.allCases.filter { $0 != .timer }, id: \.self) { scope in
                scopeRow(scope)
            }
        }
    }

    /// One row per calendar scope. Never renders Timer — it has no percentage
    /// to report, so it lives in the pill row instead.
    private func scopeRow(_ scope: Scope) -> some View {
        let pct = progress.value(for: scope)
        let isActive = selectedScope == scope
        return Button {
            select(scope)
        } label: {
            HStack(spacing: Pad.row + 2) {
                Text(scope.name)
                    .font(.callout.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .frame(width: 48, alignment: .leading)
                ProgressView(value: pct)
                    .tint(scope.color)
                Text("\(Int(pct * 100))%")
                    .font(.callout.monospacedDigit())
                    .contentTransition(.numericText())
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    // Wide enough for the widest value at .callout.monospacedDigit().
                    .frame(width: 56, alignment: .trailing)
            }
            .padding(.horizontal, Pad.row + 2)
            .padding(.vertical, Pad.pill)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(isActive ? 0.08 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(CapsulePress())
        // Keeps a visible focus ring for Full Keyboard Access.
        .focusable()
    }
}
