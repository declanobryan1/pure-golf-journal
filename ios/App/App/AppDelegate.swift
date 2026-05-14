import UIKit
import WebKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Paint UIWindow + root view + every container view cream so the keyboard's
        // rounded corners blend into Pure's theme. iOS's default systemBackground
        // is dark on light themes / black at startup, which shows through the corners
        // and around the keyboard during open animation. Painting cream means cream
        // is what shows in those gaps.
        let cream = UIColor(red: 0xFA/255.0, green: 0xF7/255.0, blue: 0xF2/255.0, alpha: 1.0)
        let paint: () -> Void = { [weak self] in
            guard let window = self?.window else { return }
            window.backgroundColor = cream
            window.rootViewController?.view.backgroundColor = cream
            // Paint container UIViews cream so the keyboard's rounded corners blend.
            // Crucially, SKIP the WKWebView itself — painting its UIView backgroundColor
            // cream caused a "blank cream on resume" bug where the WebView's own color
            // showed through during the brief window when the WebKit content layer was
            // stale post-suspend. The HTML body already sets cream as background, so
            // skipping the WebView changes nothing visually on cold-launch.
            func paintTree(_ v: UIView) {
                if v is WKWebView { return }
                v.backgroundColor = cream
                v.subviews.forEach(paintTree)
            }
            if let root = window.rootViewController?.view {
                paintTree(root)
            }
        }
        paint()
        DispatchQueue.main.async(execute: paint)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: paint)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Force the WKWebView's compositor to repaint on resume. iOS suspends the
        // GPU/Metal context when the app backgrounds; on resume the WebView's
        // UIView backgroundColor (cream, set in didFinishLaunching) shows through
        // until the WebKit content layer is asked to redraw. Without this, users
        // see a blank cream screen with invisible-but-clickable React content.
        guard let window = self.window, let root = window.rootViewController?.view else { return }
        func findWebView(_ v: UIView) -> WKWebView? {
            if let wv = v as? WKWebView { return wv }
            for sub in v.subviews { if let found = findWebView(sub) { return found } }
            return nil
        }
        guard let webView = findWebView(root) else { return }
        webView.setNeedsDisplay()
        // Belt-and-suspenders: also evaluate a no-op JS expression that touches the
        // DOM. Reading offsetHeight forces a layout flush, which iOS treats as a
        // dirty rect and re-rasterizes the page. Cheap and reliable.
        webView.evaluateJavaScript("document.body.offsetHeight", completionHandler: nil)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

    // MARK: - Push notifications
    // Capacitor's @capacitor/push-notifications plugin listens on these NotificationCenter
    // names. Without forwarding the AppDelegate APNs callbacks, the plugin never sees the
    // token and the JS-side "registration" event never fires (silent failure).
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
    }

}
