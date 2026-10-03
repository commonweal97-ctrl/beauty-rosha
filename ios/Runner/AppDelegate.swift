// ios/Runner/AppDelegate.swift
import Flutter
import UIKit
import WebKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
    private var pushChannel: FlutterMethodChannel?
    
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
}