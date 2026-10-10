import Foundation

// Self-check for the calendar + timer math. No test framework, no dependency.
// Build and run: scripts/test.sh

@main
struct Tests {
    static var failures = 0

    static func check<T: Equatable>(_ label: String, _ actual: T, _ expected: T) {
        if actual != expected {
            print("FAIL \(label): got \(actual), want \(expected)")
            failures += 1
        }
    }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h
        var g = Calendar(identifier: .gregorian)
        g.timeZone = TimeZone(identifier: "UTC")!
        return g.date(from: c)!
    }

    static func main() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        // Week offsets must respect the user's firstWeekday.
        // 2026-10-11 is a Sunday.
        let sunday = date(2026, 10, 11)
        let monday = date(2026, 10, 12)
        let saturday = date(2026, 10, 17)

        cal.firstWeekday = 1 // Sunday-first (US)
        check("offset: Sunday is day 0", weekOffset(cal, date: sunday), 0)
        check("offset: Saturday is day 6", weekOffset(cal, date: saturday), 6)
        check("offset: Monday is day 1", weekOffset(cal, date: monday), 1)
        check("week progress: first day starts at 0", calculateProgress(now: sunday, calendar: cal).week, 0.0)
        check("week progress: first day ends below 1/7",
              calculateProgress(now: date(2026, 10, 11, 23), calendar: cal).week < 1.0 / 7.0, true)
        // Last day of the week should be nearly elapsed, not stuck at 6/7.
        check("week progress: last day ends at 1",
              calculateProgress(now: date(2026, 10, 17, 23), calendar: cal).week > 0.99, true)
        check("week label: Sunday has 6 days left",
              timeLeftLabel(for: .week, now: sunday, calendar: cal), "6 days left")
        check("week label: Saturday has 0 days left",
              timeLeftLabel(for: .week, now: saturday, calendar: cal), "0 days left")
        check("week label: singular form",
              timeLeftLabel(for: .week, now: date(2026, 10, 16), calendar: cal), "1 day left")

        cal.firstWeekday = 2 // Monday-first (most of Europe)
        check("offset: Monday is day 0", weekOffset(cal, date: monday), 0)
        check("offset: Sunday is day 6", weekOffset(cal, date: sunday), 6)
        check("week progress: first day starts at 0", calculateProgress(now: monday, calendar: cal).week, 0.0)
        check("week label: Monday has 6 days left",
              timeLeftLabel(for: .week, now: monday, calendar: cal), "6 days left")
        check("week label: Sunday has 0 days left",
              timeLeftLabel(for: .week, now: sunday, calendar: cal), "0 days left")

        check("day label: last hour of the day",
              timeLeftLabel(for: .day, now: date(2026, 10, 11, 23), calendar: cal), "1h 0m left")
        check("year label: Dec 31 has 0 days left",
              timeLeftLabel(for: .year, now: date(2026, 12, 31), calendar: cal), "0 days left")
        check("month label: Jan 1 has 30 days left",
              timeLeftLabel(for: .month, now: date(2026, 1, 1), calendar: cal), "30 days left")

        // The ring must use the duration the timer started with.
        let now = date(2026, 10, 11, 12)
        let end30 = now.addingTimeInterval(30 * 60).timeIntervalSince1970
        check("elapsed: 15m into a 30m timer",
              TimerLogic.elapsedFraction(endRaw: end30, durationMinutes: 30,
                                         now: now.addingTimeInterval(15 * 60)), 0.5)
        check("elapsed: past the end clamps to 1",
              TimerLogic.elapsedFraction(endRaw: end30, durationMinutes: 30,
                                         now: now.addingTimeInterval(60 * 60)), 1.0)
        check("elapsed: before the start clamps to 0",
              TimerLogic.elapsedFraction(endRaw: end30, durationMinutes: 30,
                                         now: now.addingTimeInterval(-60)), 0.0)
        check("elapsed: zero duration is safe",
              TimerLogic.elapsedFraction(endRaw: end30, durationMinutes: 0, now: now), 0.0)
        check("elapsed: no timer is safe",
              TimerLogic.elapsedFraction(endRaw: 0, durationMinutes: 5, now: now), 0.0)
        // Demonstrates the bug #2 was about: the divisor has to match.
        // Bug #2 was that the divisor came from the selected preset rather than
        // the one the timer started with. A too-small divisor drives elapsed
        // negative, so a half-done 30m timer renders as an empty ring.
        check("wrong divisor empties the ring",
              TimerLogic.elapsedFraction(endRaw: end30, durationMinutes: 5,
                                         now: now.addingTimeInterval(15 * 60)), 0.0)

        check("countdown: under an hour", TimerLogic.countdownText(541), "9:01")
        check("countdown: over an hour", TimerLogic.countdownText(3849), "1:04:09")
        check("countdown: zero", TimerLogic.countdownText(0), "0:00")
        check("isRunning: before the end", TimerLogic.isRunning(endRaw: end30, now: now), true)
        check("isRunning: after the end",
              TimerLogic.isRunning(endRaw: end30, now: now.addingTimeInterval(31 * 60)), false)
        check("isExpired: after the end",
              TimerLogic.isExpired(endRaw: end30, now: now.addingTimeInterval(31 * 60)), true)
        check("isExpired: no timer", TimerLogic.isExpired(endRaw: 0, now: now), false)
        check("flash: active right after the end",
              TimerLogic.flashActive(endRaw: end30, now: now.addingTimeInterval(30 * 60 + 5)), true)
        check("flash: inactive after the window",
              TimerLogic.flashActive(endRaw: end30, now: now.addingTimeInterval(30 * 60 + 11)), false)
        check("flash: inactive while running", TimerLogic.flashActive(endRaw: end30, now: now), false)
        check("sinceExpiry: no timer", TimerLogic.sinceExpiry(endRaw: 0, now: now), 0.0)

        if failures == 0 {
            print("All checks passed.")
        } else {
            print("\(failures) check(s) failed.")
            exit(1)
        }
    }
}
