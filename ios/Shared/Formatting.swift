import Foundation

/// Clock and date strings. preview/render.js mirrors these formats.
enum ClockFormat {
    static func time(_ date: Date, use24Hour: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    static func date(_ date: Date, style: DateStyleChoice) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        switch style {
        case .long: formatter.dateFormat = "EEEE, d MMMM"
        case .short: formatter.dateFormat = "EEE d MMM"
        case .numeric: formatter.dateFormat = "dd.MM.yy"
        }
        return formatter.string(from: date)
    }
}
