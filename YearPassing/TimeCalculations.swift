import Foundation

enum Scope: String, CaseIterable {
    case day, week, month, year

    var name: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }

    var letter: String {
        switch self {
        case .day: "D"
        case .week: "W"
        case .month: "M"
        case .year: "Y"
        }
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
