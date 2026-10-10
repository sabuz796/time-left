import SwiftUI
import ServiceManagement
import UserNotifications

extension Scope {
    var color: Color {
        switch self {
        case .day: .blue
        case .week: .purple
        case .month: .green
        case .year: Color(red: 0xFF / 255.0, green: 0xA2 / 255.0, blue: 0x59 / 255.0) // #FFA259
        case .timer: Color(red: 0xE4 / 255.0, green: 0x57 / 255.0, blue: 0x42 / 255.0) // #E45742
        }
    }
}

@main
struct YearPassingApp: App {
    @State private var progress = calculateProgress()
    @AppStorage("selectedScope") private var selectedScopeRaw = Scope.year.rawValue
    /// Last non-timer scope — menu bar shows this whenever no timer is active.
    @AppStorage("displayScope") private var displayScopeRaw = Scope.year.rawValue
    @AppStorage("timerDurationMinutes") private var timerDurationMinutes = 5
    @AppStorage("timerEndDate") private var timerEndDateRaw = 0.0      // 0 = no timer
    @AppStorage("timerNotifiedEndDate") private var notifiedEndDateRaw = 0.0
    @State private var now = Date()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var bounceUp = false

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
        TimerLogic.elapsedFraction(endRaw: timerEndDateRaw, durationMinutes: timerDurationMinutes, now: now)
    }

    private func startTimer() {
        timerEndDateRaw = Date().addingTimeInterval(Double(timerDurationMinutes) * 60).timeIntervalSince1970
        notifiedEndDateRaw = 0
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func stopTimer() {
        timerEndDateRaw = 0
        notifiedEndDateRaw = 0
    }

    private func fireTimerDoneNotification(durationMinutes: Int) {
        // The Glass chime plays via NSSound (works even in Do Not Disturb);
        // don't also set content.sound or the alert chimes twice.
        NSSound(named: NSSound.Name("Glass"))?.play()
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
                fireTimerDoneNotification(durationMinutes: timerDurationMinutes)
            }
        }
        if since >= TimerLogic.flashSeconds {
            timerEndDateRaw = 0
            notifiedEndDateRaw = 0
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

    private var displayScope: Scope {
        Scope(rawValue: displayScopeRaw) ?? .year
    }

    private func select(_ scope: Scope) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selectedScopeRaw = scope.rawValue
            if scope != .timer { displayScopeRaw = scope.rawValue }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 14) {
                scopePills
                ringHero(scope: selectedScope)
                // ZStack (not VStack) so the two blocks share space during the
                // crossfade — a stacked if/else briefly holds both, shoving the
                // content below down before it settles back up.
                ZStack {
                    if selectedScope == .timer {
                        timerControls
                            .transition(.opacity)
                    } else {
                        scopeRows
                            .transition(.opacity)
                    }
                }
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
                HStack(spacing: 10) {
                    Link(destination: URL(string: "https://github.com/sabuz796/time-left/issues")!) {
                        Label("Report Bug", systemImage: "exclamationmark.bubble")
                            .font(.callout)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                            .foregroundStyle(.secondary)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q")
                    .buttonStyle(.plain)
                    .font(.callout)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.07)))
                    .foregroundStyle(.secondary)
                    .contentShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minWidth: 240, idealWidth: 260)
            .textSelection(.enabled)
            .onReceive(timer) { _ in
                now = Date()
                if flashActive { bounceUp.toggle() }
                progress = calculateProgress()
                handleTimerTick()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: (timerRunning || flashActive) ? "stopwatch" : "hourglass")
                if timerRunning {
                    Text(TimerLogic.countdownText(timerRemaining))
                        .monospacedDigit()
                } else if flashActive {
                    let blink = Int(now.timeIntervalSince1970 * 2) % 2 == 0
                    Text(blink ? "Done ✅" : "Time's up")
                        .monospacedDigit()
                } else {
                    Text("\(displayScope.letter): \(Int(progress.value(for: displayScope) * 100))%")
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var scopePills: some View {
        HStack(spacing: 4) {
            ForEach(Scope.allCases, id: \.self) { scope in
                Button {
                    select(scope)
                } label: {
                    Text(scope.name)
                        .font(.callout.weight(selectedScope == scope ? .semibold : .regular))
                        .foregroundStyle(selectedScope == scope ? scope.color : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(scope.color.opacity(selectedScope == scope ? 0.25 : 0))
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }

    private func ringHero(scope: Scope) -> some View {
        let isTimer = scope == .timer
        let pct = isTimer ? timerElapsedFraction : progress.value(for: scope)
        return ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 10)
            Circle()
                .trim(from: 0, to: isTimer ? 1 - pct : pct)
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
                    Text(timeLeftLabel(for: scope))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .id(scope)
                        .transition(.opacity)
                }
            }
        }
        .frame(width: 120, height: 120)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: pct)
    }

    private var timerControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                    let selected = timerDurationMinutes == minutes
                    Button {
                        timerDurationMinutes = minutes
                    } label: {
                        Text(minutes >= 60 ? "1h" : "\(minutes)m")
                            .font(.callout.weight(selected ? .semibold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(selected ? Scope.timer.color : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(Scope.timer.color.opacity(selected ? 0.22 : 0.07))
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(timerRunning)
                }
            }
            Button {
                timerRunning ? stopTimer() : startTimer()
            } label: {
                Label(timerRunning ? "Stop" : "Start", systemImage: timerRunning ? "stop.fill" : "play.fill")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(timerRunning ? Scope.timer.color.opacity(0.18) : Scope.timer.color)
                    )
                    .foregroundStyle(timerRunning ? Scope.timer.color : Color.white)
            }
            .buttonStyle(.plain)
            if timerRunning {
                Text("Menu bar shows the countdown, even if you quit and reopen.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var scopeRows: some View {
        VStack(spacing: 6) {
            ForEach(Scope.allCases, id: \.self) { scope in
                scopeRow(scope)
            }
        }
    }

    private func scopeRow(_ scope: Scope) -> some View {
        let isTimer = scope == .timer
        let pct = isTimer ? timerElapsedFraction : progress.value(for: scope)
        let trailing = isTimer
            ? (timerRunning ? TimerLogic.countdownText(timerRemaining) : (timerExpired ? "Done" : "—"))
            : "\(Int(pct * 100))%"
        let isActive = selectedScope == scope
        return Button {
            select(scope)
        } label: {
            HStack(spacing: 10) {
                Text(scope.name)
                    .font(.callout.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .frame(width: 48, alignment: .leading)
                ProgressView(value: isTimer ? (timerRunning ? 1 - pct : 1) : pct)
                    .tint(scope.color)
                Text(trailing)
                    .font(.callout.monospacedDigit())
                    .contentTransition(.numericText())
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(isActive ? 0.08 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
