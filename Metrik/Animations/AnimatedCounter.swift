import SwiftUI

struct AnimatedCounter: View {
    let value: Int
    let prefix: String
    let format: AnimatedCounterFormat

    @State private var displayValue: Int = 0

    enum AnimatedCounterFormat {
        case integer
        case compact
    }

    init(_ value: Int, prefix: String = "", format: AnimatedCounterFormat = .integer) {
        self.value = value
        self.prefix = prefix
        self.format = format
    }

    var body: some View {
        Text(formattedValue)
            .contentTransition(.numericText(value: Double(displayValue)))
            .animation(.spring(duration: 0.6, bounce: 0.15), value: displayValue)
            .onAppear { displayValue = value }
            .onChange(of: value) { _, newValue in
                displayValue = newValue
            }
    }

    private var formattedValue: String {
        let formatted: String
        switch format {
        case .integer:
            formatted = NumberFormatter.localizedString(from: NSNumber(value: displayValue), number: .decimal)
        case .compact:
            if displayValue >= 1000 {
                formatted = String(format: "%.1fk", Double(displayValue) / 1000)
            } else {
                formatted = "\(displayValue)"
            }
        }
        return prefix + formatted
    }
}

struct AnimatedDecimalCounter: View {
    let value: Double

    @State private var displayValue: Double = 0

    var body: some View {
        Text(String(format: "%.1f/hr", displayValue))
            .contentTransition(.numericText(value: displayValue))
            .animation(.spring(duration: 0.6, bounce: 0.15), value: displayValue)
            .onAppear { displayValue = value }
            .onChange(of: value) { _, newValue in
                displayValue = newValue
            }
    }
}
