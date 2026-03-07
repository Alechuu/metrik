import WidgetKit
import SwiftUI

@main
struct MetrikWidgetBundle: WidgetBundle {
    var body: some Widget {
        MetrikWidget()
    }
}

struct MetrikWidget: Widget {
    let kind: String = "MetrikWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(macOS 14.0, *) {
                MetrikWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MetrikWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Metrik")
        .description("Track your lines of code")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MetrikWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}
