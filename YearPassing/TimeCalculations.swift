import Foundation

enum Scope: String, CaseIterable {
    case day, week, month, year, timer

    var name: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .timer: "Timer"
        }
    }

    var letter: String {
        String(name.first!)
    }
}

struct TimeProgress {
    let day: Double      // 0.0 – 1.0
    let week: Double     // 0.0 – 1.0
    let month: Double    // 0.0 – 1.0
    let year: Double     // 0.0 – 1.0

    func value(for scope: Scope) -> Double {
        switch scope {
        case .day: day
        case .week: week
        case .month: month
        case .year: year
        case .timer: 0 // timer progress is handled separately (elapsed fraction)
        }
    }
}

func timeLeftLabel(for scope: Scope, date: Date = Date()) -> String {
    let calendar = Calendar.current
    switch scope {
    case .day:
        let endOfDay = calendar.startOfDay(for: date).addingTimeInterval(24 * 60 * 60)
        let comps = calendar.dateComponents([.hour, .minute], from: date, to: endOfDay)
        return "\(comps.hour ?? 0)h \(comps.minute ?? 0)m left"
    case .week:
        // weekday 1 = first day of the week in the user's calendar
        let weekday = calendar.component(.weekday, from: date)
        let daysLeft = 7 - weekday
        return leftLabel(days: daysLeft)
    case .month:
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: date)
        return leftLabel(days: daysInMonth - dayOfMonth)
    case .year:
        let daysInYear = calendar.range(of: .day, in: .year, for: date)?.count ?? 365
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return leftLabel(days: daysInYear - dayOfYear)
    case .timer:
        return "" // countdown label is built in the app from the timer end date
    }
}

private func leftLabel(days: Int) -> String {
    days == 1 ? "1 day left" : "\(days) days left"
}

func calculateProgress(for date: Date = Date()) -> TimeProgress {
    let calendar = Calendar.current

    // Day progress
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    let dayProgress = Double(hour * 60 + minute) / (24.0 * 60.0)

    // Week progress (weekday 1 = first day of the week in user's calendar)
    let weekday = calendar.component(.weekday, from: date)
    let weekProgress = Double(weekday - 1) / 7.0

    // Month progress
    let dayOfMonth = calendar.component(.day, from: date)
    let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    let monthProgress = Double(dayOfMonth - 1) / Double(daysInMonth)

    // Year progress
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    let daysInYear = calendar.range(of: .day, in: .year, for: date)?.count ?? 365
    let yearProgress = Double(dayOfYear - 1) / Double(daysInYear)

    return TimeProgress(day: dayProgress, week: weekProgress, month: monthProgress, year: yearProgress)
}


/// Pure timer math — no state, no SwiftUI. The app keeps the @AppStorage
/// properties and delegates all logic here, so it stays testable in isolation.
enum TimerLogic {
    static func isRunning(endRaw: Double, now: Date) -> Bool {
        endRaw > 0 && now < endDate(endRaw)
    }

    static func isExpired(endRaw: Double, now: Date) -> Bool {
        endRaw > 0 && now >= endDate(endRaw)
    }

    /// First 10 seconds after the timer finishes — menu bar flashes, then auto-reverts.
    static func flashActive(endRaw: Double, now: Date) -> Bool {
        endRaw > 0 && now.timeIntervalSince(endDate(endRaw)) >= 0
            && now.timeIntervalSince(endDate(endRaw)) < 10
    }

    static func remaining(endRaw: Double, now: Date) -> TimeInterval {
        endRaw > 0 ? max(0, endDate(endRaw).timeIntervalSince(now)) : 0
    }

    static func elapsedFraction(endRaw: Double, durationMinutes: Int, now: Date) -> Double {
        guard endRaw > 0, durationMinutes > 0 else { return 0 }
        let total = Double(durationMinutes) * 60
        return min(1, max(0, 1 - endDate(endRaw).timeIntervalSince(now) / total))
    }

    /// "9:41" for sub-hour timers, "1:04:09" for an hour or more.
    static func countdownText(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private static func endDate(_ raw: Double) -> Date {
        Date(timeIntervalSince1970: raw)
    }
}
