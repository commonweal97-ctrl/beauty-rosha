// ios/Runner/BadgeManager.swift
import Flutter
import UIKit

public class BadgeManager: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.beautyrosha.beautyRosha/badge",
            binaryMessenger: registrar.messenger()
        )
        let instance = BadgeManager()
        registrar.addMethodCallDelegate(instance, channel: channel)
        print("🛎 BadgeManager registered")
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setBadge":
            if let count = call.arguments as? Int {
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber = count
                }
                result(nil)
            } else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Badge count must be Int",
                    details: nil
                ))
            }
            
        case "clearBadge":
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
            result(nil)
            
        case "getBadge":
            let count = UIApplication.shared.applicationIconBadgeNumber
            result(count)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}