// ios/Runner/AppDelegate.swift
import Flutter
import UIKit
import WebKit
import FirebaseCore
import FirebaseMessaging
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
    private var pushChannel: FlutterMethodChannel?
    private var liveActivityChannel: FlutterMethodChannel?
    private var liveActivityTokenTasks: [String: Task<Void, Never>] = [:]
    private var liveActivityAuthHeaders: [Int: [String: String]] = [:]

    private func swiftLog(_ msg: String) {
        NSLog("%@", msg)
        DispatchQueue.main.async { [weak self] in
            self?.liveActivityChannel?.invokeMethod("onSwiftLog", arguments: msg)
        }
    }
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        
        UNUserNotificationCenter.current().delegate = self
        
        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        
        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BadgeManager") {
            BadgeManager.register(with: registrar)
        }
        
        let messenger = engineBridge.applicationRegistrar.messenger()
        pushChannel = FlutterMethodChannel(
            name: "beautyrosha/push",
            binaryMessenger: messenger
        )

        // SSL-канал (UIScene-compatible)
        let sslChannel = FlutterMethodChannel(
            name: "beautyrosha/ssl",
            binaryMessenger: messenger
        )
        sslChannel.setMethodCallHandler { [weak self] call, result in
            if call.method == "trustAllCertificates" {
                self?.trustAllCertificates()
                result(true)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        let liveActivityChannel = FlutterMethodChannel(
            name: "beautyrosha/live_activity",
            binaryMessenger: messenger
        )
        liveActivityChannel.setMethodCallHandler { [weak self] call, result in
            NSLog("LiveActivity channel call: %@ args=%@", call.method, String(describing: call.arguments))
            guard let self = self else { return }

            switch call.method {
            case "startOrUpdate":
                guard #available(iOS 16.1, *),
                      let args = call.arguments as? [String: Any] else {
                    result(false)
                    return
                }
                self.startOrUpdateLiveActivity(args: args, completion: result)

            case "endActivity":
                guard #available(iOS 16.1, *),
                      let args = call.arguments as? [String: Any],
                      let orderId = args["order_id"] as? Int else {
                    result(false)
                    return
                }
                self.endLiveActivity(orderId: orderId, completion: result)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
        self.liveActivityChannel = liveActivityChannel
    }
    
    override func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if let url = userActivity.webpageURL {
            if let controller = window?.rootViewController as? FlutterViewController {
                let channel = FlutterMethodChannel(
                    name: "beautyrosha/deeplink",
                    binaryMessenger: controller.binaryMessenger
                )
                channel.invokeMethod("handleLink", arguments: url.absoluteString)
            }
        }
        
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
    
    private func trustAllCertificates() {
        if #available(iOS 11.0, *) {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = WKWebsiteDataStore.default()
            
            UserDefaults.standard.set(true, forKey: "NSAllowsArbitraryLoads")
            UserDefaults.standard.set(true, forKey: "NSAllowsArbitraryLoadsInWebContent")
        }
    }
    
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if let link = userInfo["link"] as? String {
            pushChannel?.invokeMethod("handlePush", arguments: link)
        }
        
        completionHandler(.newData)
    }
}

extension AppDelegate {
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let link = response.notification.request.content.userInfo["link"] as? String {
            if pushChannel == nil {
                if let controller = window?.rootViewController as? FlutterViewController {
                    let channel = FlutterMethodChannel(
                        name: "beautyrosha/push",
                        binaryMessenger: controller.binaryMessenger
                    )
                    channel.invokeMethod("handlePush", arguments: link)
                }
            } else {
                pushChannel?.invokeMethod("handlePush", arguments: link)
            }
        }
        
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcm_token")
        }
    }

    @available(iOS 16.1, *)
    private func startOrUpdateLiveActivity(args: [String: Any], completion: @escaping FlutterResult) {
        let activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard activitiesEnabled,
              let orderId = args["order_id"] as? Int else {
            NSLog("LiveActivity guard failed: enabled=%d args=%@", activitiesEnabled ? 1 : 0, args)
            completion(false)
            return
        }

        let orderNumber = args["order_number"] as? String ?? "\(orderId)"
        let deliveryType = args["delivery_type"] as? String ?? "pickup"
        let provider = args["provider"] as? String ?? "pickup"
        let stageCode = args["stage_code"] as? String ?? "pending"
        let title = args["title"] as? String ?? "Заказ в обработке"
        let subtitle = args["subtitle"] as? String ?? ""
        let address = args["address"] as? String ?? ""
        let progress = args["progress"] as? Double ?? 0.15
        let isFinal = args["is_final"] as? Bool ?? false
        let authHeaders = args["headers"] as? [String: String]

        let state = OrderTrackingAttributes.ContentState(
            stageCode: stageCode,
            title: title,
            subtitle: subtitle,
            address: address,
            progress: progress,
            isFinal: isFinal
        )

        Task {
            if let existing = Activity<OrderTrackingAttributes>.activities.first(where: { $0.attributes.orderId == orderId }) {
                if isFinal {
                    await existing.end(
                        ActivityContent(state: state, staleDate: nil),
                        dismissalPolicy: .after(.now + 300)
                    )
                    self.liveActivityTokenTasks[existing.id]?.cancel()
                    self.liveActivityTokenTasks.removeValue(forKey: existing.id)
                } else {
                    await existing.update(ActivityContent(state: state, staleDate: nil))
                    self.observeLiveActivityPushToken(activity: existing, orderId: orderId, deliveryType: deliveryType, authHeaders: authHeaders)
                }
                completion(true)
                return
            }

            let attributes = OrderTrackingAttributes(
                orderId: orderId,
                orderNumber: orderNumber,
                deliveryType: deliveryType,
                provider: provider
            )

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: .token
                )
                self.observeLiveActivityPushToken(activity: activity, orderId: orderId, deliveryType: deliveryType, authHeaders: authHeaders)
                completion(true)
            } catch {
                NSLog("LiveActivity Activity.request failed: %@", String(describing: error))
                completion(false)
            }
        }
    }

    @available(iOS 16.1, *)
    private func endLiveActivity(orderId: Int, completion: @escaping FlutterResult) {
        Task {
            for activity in Activity<OrderTrackingAttributes>.activities where activity.attributes.orderId == orderId {
                await activity.end(dismissalPolicy: .immediate)
                self.liveActivityTokenTasks[activity.id]?.cancel()
                self.liveActivityTokenTasks.removeValue(forKey: activity.id)
            }
            await self.notifyLiveActivityStopped(orderId: orderId)
            completion(true)
        }
    }

    @available(iOS 16.1, *)
    private func observeLiveActivityPushToken(
        activity: Activity<OrderTrackingAttributes>,
        orderId: Int,
        deliveryType: String,
        authHeaders: [String: String]? = nil
    ) {
        if let authHeaders = authHeaders, !authHeaders.isEmpty {
            liveActivityAuthHeaders[orderId] = authHeaders
        }
        liveActivityTokenTasks[activity.id]?.cancel()
        liveActivityTokenTasks[activity.id] = Task {
            self.swiftLog("[LA-SWIFT] observing pushTokenUpdates for orderId=\(orderId) activityId=\(activity.id) state=\(String(describing: activity.activityState))")
            for await tokenData in activity.pushTokenUpdates {
                let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
                self.swiftLog("[LA-SWIFT] got pushToken len=\(tokenHex.count) bytes=\(tokenData.count) orderId=\(orderId) activityId=\(activity.id)")
                await self.sendLiveActivityToken(
                    orderId: orderId,
                    activityId: activity.id,
                    pushToken: tokenHex,
                    deliveryType: deliveryType
                )
            }
        }
    }

    private func sendLiveActivityToken(
        orderId: Int,
        activityId: String,
        pushToken: String,
        deliveryType: String
    ) async {
        guard let url = URL(string: "https://xn--80abvyjk6cts.xn--p1ai/api/user/live-activity/register"),
              let host = url.host else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("BeautyRosha/1.0 (Flutter; Dart)", forHTTPHeaderField: "User-Agent")

        // Извлекаем cookie-пары и остальные заголовки
        var cookiePairs: [(String, String)] = []
        if let headers = liveActivityAuthHeaders[orderId] {
            for (k, v) in headers {
                if k.lowercased() == "cookie" {
                    for pair in v.split(separator: ";") {
                        let parts = pair.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                        if parts.count == 2 { cookiePairs.append((parts[0], parts[1])) }
                    }
                } else if k.lowercased() == "user-agent" {
                    request.setValue(v, forHTTPHeaderField: k)
                } else if k.lowercased() == "x-csrf-token" {
                    request.setValue(v, forHTTPHeaderField: k)
                }
            }
        }

        let body: [String: Any] = [
            "order_id": orderId,
            "activity_id": activityId,
            "push_token": pushToken,
            "delivery_type": deliveryType,
        ]
        self.swiftLog("[LA-SWIFT] POST register body order_id=\(orderId) activity_id=\(activityId) token_len=\(pushToken.count) cookies=\(cookiePairs.map { $0.0 }.joined(separator: ","))")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // URLSession игнорирует Cookie из setValue — временно подменяем HTTPCookieStorage.shared
        let storage = HTTPCookieStorage.shared
        let urlForHost = URL(string: "https://\(host)/")!
        let oldCookies = storage.cookies(for: urlForHost) ?? []
        for c in oldCookies { storage.deleteCookie(c) }
        for (name, value) in cookiePairs {
            let props: [HTTPCookiePropertyKey: Any] = [
                .domain: host,
                .path: "/",
                .secure: "TRUE",
                .name: name,
                .value: value,
            ]
            if let c = HTTPCookie(properties: props) { storage.setCookie(c) }
        }

        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = storage
        let isolatedSession = URLSession(configuration: config)

        defer {
            for c in storage.cookies(for: urlForHost) ?? [] { storage.deleteCookie(c) }
            for c in oldCookies { storage.setCookie(c) }
        }

        do {
            let (data, resp) = try await isolatedSession.data(for: request)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let respText = String(data: data, encoding: .utf8) ?? ""
            self.swiftLog("[LA-SWIFT] register status=\(code) body=\(respText)")
        } catch {
            self.swiftLog("[LA-SWIFT] register error: \(String(describing: error))")
        }
    }

    private func notifyLiveActivityStopped(orderId: Int) async {
        guard let url = URL(string: "https://xn--80abvyjk6cts.xn--p1ai/api/user/live-activity/stop") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = ["order_id": orderId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }
}
