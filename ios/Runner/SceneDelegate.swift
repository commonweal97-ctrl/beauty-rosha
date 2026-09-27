import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    
    override func scene(
        _ scene: UIScene,
        continue userActivity: NSUserActivity
    ) {
        print("🔗 Scene Universal Link: \(userActivity.webpageURL?.absoluteString ?? "nil")")
        
        if let url = userActivity.webpageURL {
            if let controller = window?.rootViewController as? FlutterViewController {
                let channel = FlutterMethodChannel(
                    name: "beautyrosha/deeplink",
                    binaryMessenger: controller.binaryMessenger
                )
                channel.invokeMethod("handleLink", arguments: url.absoluteString)
            }
        }
        
        super.scene(scene, continue: userActivity)
    }
}