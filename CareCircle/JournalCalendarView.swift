import SwiftUI

// MARK: - Journal calendar (month view, tap date → entry)

private struct JournalDateSelection: Identifiable, Hashable {
    let date: Date
    var id: String { JournalEntry.dayKey(for: date) }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: JournalDateSelection, rhs: JournalDateSelection) -> Bool { lhs.id == rhs.id }
}

struct JournalCalendarView: View {
    @StateObject private var store = JournalStore.shared
    @State private var selectedDateKey: JournalDateSelection?
    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    monthHeader
                    weekdayLabels
                    dayGrid
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .onAppear {
            store.runCleanupIfNeeded()
            store.loadEntries()
        }
        .navigationDestination(item: $selectedDateKey) { key in
            JournalEntryView(date: key.date, onDismiss: { store.loadEntries() })
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")

            Spacer()
            Text(monthYearString(from: displayedMonth))
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next month")
        }
    }

    private var weekdayLabels: some View {
        HStack(spacing: 8) {
            ForEach(weekdaySymbols(), id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let days = daysInDisplayedMonth()
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<days.count, id: \.self) { index in
                dayCell(for: days[index])
            }
        }
    }

    @ViewBuilder
    private func dayCell(for dayInfo: DayInfo?) -> some View {
        if let info = dayInfo {
            Button {
                selectedDateKey = JournalDateSelection(date: info.date)
            } label: {
                VStack(spacing: 4) {
                    Text("\(info.day)")
                        .font(.body.weight(info.isToday ? .bold : .regular))
                        .foregroundStyle(textColor(for: info))
                    if info.hasEntry {
                        Circle()
                            .fill(AppTheme.primaryGreen)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(backgroundColor(for: info))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(info.isToday ? Color.white : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(for: info))
        } else {
            Color.clear
                .frame(height: 44)
        }
    }

    private func textColor(for info: DayInfo) -> Color {
        if info.isToday { return .white }
        if info.hasEntry { return .white }
        return .white.opacity(0.9)
    }

    private func backgroundColor(for info: DayInfo) -> Color {
        if info.isToday { return AppTheme.primaryGreen }
        if info.hasEntry { return AppTheme.primaryGreen.opacity(0.5) }
        return Color.white.opacity(0.15)
    }

    private func accessibilityLabel(for info: DayInfo) -> String {
        var label = "\(info.day)"
        if info.isToday { label += ", today" }
        if info.hasEntry { label += ", has journal entry" }
        return label
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func weekdaySymbols() -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        if first == 0 { return symbols }
        return Array(symbols[first...]) + symbols[..<first]
    }

    private struct DayInfo {
        let date: Date
        let day: Int
        let isToday: Bool
        let hasEntry: Bool
    }

    private func daysInDisplayedMonth() -> [DayInfo?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }
        let startOfMonth = calendar.startOfDay(for: firstDay)
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let firstWeekday = calendar.firstWeekday
        var leadingBlanks = (weekday - firstWeekday + 7) % 7
        if leadingBlanks < 0 { leadingBlanks += 7 }

        let todayStart = calendar.startOfDay(for: Date())
        let datesWithEntries = store.datesWithEntries(in: calendar)

        var result: [DayInfo?] = (0..<leadingBlanks).map { _ in nil }
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            result.append(DayInfo(
                date: startOfDay,
                day: day,
                isToday: startOfDay == todayStart,
                hasEntry: datesWithEntries.contains(startOfDay)
            ))
        }
        return result
    }
}

