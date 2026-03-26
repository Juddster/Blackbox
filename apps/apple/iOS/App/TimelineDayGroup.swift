import Foundation

struct TimelineDayGroup: Identifiable {
    let day: Date
    let segments: [SegmentSnapshot]

    var id: Date { day }

    var title: String {
        if Calendar.autoupdatingCurrent.isDateInToday(day) {
            return "Today"
        }

        if Calendar.autoupdatingCurrent.isDateInYesterday(day) {
            return "Yesterday"
        }

        return day.formatted(.dateTime.weekday(.wide).month().day())
    }
}
