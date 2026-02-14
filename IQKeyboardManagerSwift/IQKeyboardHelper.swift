
import UIKit

class IQKeyboardHelper {
    
    static let shared = IQKeyboardHelper()
    private init() {}
    
    static func getCurrentWindow() -> UIWindow? {
        return shared.getSafeWindow()
    }
    
    static func getCurrentWindow(maxRetries: Int = 10, completion: @escaping (UIWindow?) -> Void) {
        shared.getWindowWithRetry(maxRetries: maxRetries, completion: completion)
    }
    
    static func hasAvailableWindow() -> Bool {
        return getCurrentWindow() != nil
    }
    
    static func getAllWindows() -> [UIWindow] {
        return shared.getAllAvailableWindows()
    }
    
    static func getKeyWindow() -> UIWindow? {
        return shared.getMainWindow()
    }
    
    private func getSafeWindow() -> UIWindow? {
        if let keyWindow = getMainWindow() {
            return keyWindow
        }
        
        if #available(iOS 13.0, *) {
            if let window = getWindowFromScenes() {
                return window
            }
        }
        
        if let window = getWindowFromAllWindows() {
            return window
        }
        
        if #available(iOS 13.0, *) {
        } else {
            if let window = getLegacyKeyWindow() {
                return window
            }
        }
        
        return nil
    }
    
    private func getMainWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        if window.isKeyWindow {
                            return window
                        }
                    }
                }
            }
        } else {
            return UIApplication.shared.keyWindow
        }
        return nil
    }
    
    @available(iOS 13.0, *)
    private func getWindowFromScenes() -> UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    return keyWindow
                }
                if let firstWindow = windowScene.windows.first {
                    return firstWindow
                }
            }
        }
        return nil
    }
    
    private func getWindowFromAllWindows() -> UIWindow? {
        let allWindows = UIApplication.shared.windows
        
        if let keyWindow = allWindows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        
        if let visibleWindow = allWindows.first(where: { !$0.isHidden }) {
            return visibleWindow
        }
        
        return allWindows.first
    }
    
    private func getLegacyKeyWindow() -> UIWindow? {
        return UIApplication.shared.keyWindow
    }
    
    private func getAllAvailableWindows() -> [UIWindow] {
        return UIApplication.shared.windows.filter { !$0.isHidden }
    }
    
    private func getWindowWithRetry(maxRetries: Int, completion: @escaping (UIWindow?) -> Void, currentRetry: Int = 0) {
        if let window = getSafeWindow() {
            DispatchQueue.main.async {
                completion(window)
            }
            return
        }
        
        if currentRetry >= maxRetries {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        let delay = 0.1 * Double(currentRetry + 1)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.getWindowWithRetry(
                maxRetries: maxRetries,
                completion: completion,
                currentRetry: currentRetry + 1
            )
        }
    }
}


extension IQKeyboardHelper {
    
    static func performWithWindow(_ action: @escaping (UIWindow) -> Void, fallback: (() -> Void)? = nil) {
        if let window = getCurrentWindow() {
            DispatchQueue.main.async {
                action(window)
            }
        } else {
            getCurrentWindow { window in
                if let window = window {
                    action(window)
                } else {
                    fallback?()
                }
            }
        }
    }
    
    static func getSafeAreaInsets() -> UIEdgeInsets {
        if let window = getCurrentWindow() {
            if #available(iOS 11.0, *) {
                return window.safeAreaInsets
            }
        }
        return .zero
    }
    
    static func getScreenSize() -> CGSize {
        return UIScreen.main.bounds.size
    }
    
    static func isLandscape() -> Bool {
        if let window = getCurrentWindow() {
            if #available(iOS 13.0, *) {
                return window.windowScene?.interfaceOrientation.isLandscape ?? false
            } else {
                return UIApplication.shared.statusBarOrientation.isLandscape
            }
        }
        return UIScreen.main.bounds.width > UIScreen.main.bounds.height
    }
} 
