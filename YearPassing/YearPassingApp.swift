import SwiftUI
import ServiceManagement

extension Scope {
    var color: Color {
        switch self {
        case .day: .blue
        case .month: .green
        case .year: .orange
        }
    }
}

@main
struct YearPassingApp: App {
    @State private var progress = calculateProgress()
    @AppStorage("selectedScope") private var selectedScopeRaw = Scope.year.rawValue
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

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

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var selectedScope: Scope {
        Scope(rawValue: selectedScopeRaw) ?? .year
    }

    private func select(_ scope: Scope) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selectedScopeRaw = scope.rawValue
        }
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 14) {
                scopePills
                ringHero(scope: selectedScope)
                scopeRows
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
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minWidth: 240, idealWidth: 260)
            .textSelection(.enabled)
            .onReceive(timer) { _ in
                progress = calculateProgress()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "hourglass")
                Text("\(selectedScope.letter): \(Int(progress.value(for: selectedScope) * 100))%")
                    .monospacedDigit()
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
        let pct = progress.value(for: scope)
        return ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 10)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(scope.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(pct * 100))%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(timeLeftLabel(for: scope))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120, height: 120)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: pct)
    }

    private var scopeRows: some View {
        VStack(spacing: 6) {
            ForEach(Scope.allCases, id: \.self) { scope in
                scopeRow(scope)
            }
        }
    }

    private func scopeRow(_ scope: Scope) -> some View {
        let pct = progress.value(for: scope)
        let isActive = selectedScope == scope
        return Button {
            select(scope)
        } label: {
            HStack(spacing: 10) {
                Text(scope.name)
                    .font(.callout.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .frame(width: 48, alignment: .leading)
                ProgressView(value: pct)
                    .tint(scope.color)
                Text("\(Int(pct * 100))%")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .frame(width: 40, alignment: .trailing)
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
