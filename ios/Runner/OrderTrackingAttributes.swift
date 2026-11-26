import ActivityKit
import Foundation

struct OrderTrackingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stageCode: String
        var title: String
        var subtitle: String
        var address: String
        var progress: Double
        var isFinal: Bool
    }

    var orderId: Int
    var orderNumber: String
    var deliveryType: String
    var provider: String
}
