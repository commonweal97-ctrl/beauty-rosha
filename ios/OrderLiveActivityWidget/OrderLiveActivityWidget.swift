import WidgetKit
import SwiftUI
import ActivityKit

extension Color {
    static let brandPink = Color(red: 0.867, green: 0.094, blue: 0.278) // #DD1847
}

struct OrderLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrderTrackingAttributes.self) { context in
            OrderLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: iconFor(provider: context.attributes.provider))
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.caption2)
                            .foregroundColor(.brandPink)
                        Text(context.state.subtitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !context.state.address.isEmpty {
                            Label(context.state.address, systemImage: "mappin.and.ellipse")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                        ProgressView(value: context.state.progress)
                            .tint(.brandPink)
                    }
                }
            } compactLeading: {
                Image(systemName: iconFor(provider: context.attributes.provider))
                    .foregroundColor(.brandPink)
            } compactTrailing: {
                ProgressView(value: context.state.progress)
                    .progressViewStyle(.circular)
                    .tint(.brandPink)
                    .frame(width: 18, height: 18)
            } minimal: {
                Image(systemName: iconFor(provider: context.attributes.provider))
                    .foregroundColor(.brandPink)
            }
        }
    }

    private func iconFor(provider: String) -> String {
        switch provider {
        case "courier": return "figure.walk"
        case "cdek": return "shippingbox"
        case "yandex": return "y.circle"
        case "fivepost": return "5.circle"
        case "russian_post": return "envelope"
        default: return "shippingbox"
        }
    }
}

struct OrderLiveActivityLockScreenView: View {
    let context: ActivityViewContext<OrderTrackingAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.title)
                        .font(.caption)
                        .foregroundColor(.brandPink)
                    Text(context.state.subtitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.brandPink.opacity(0.3), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(Color.brandPink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
            }
            if !context.state.address.isEmpty {
                Label(context.state.address, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            ProgressView(value: context.state.progress)
                .tint(.brandPink)
        }
        .padding(16)
    }
}
