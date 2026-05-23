//
//  PlatformMethodHandler.swift
//  Runner
//
//  Created by Hiddify on 12/27/23.
//

import Flutter
import Combine
import HiddifyCore
import DeviceCheck
import Security

public class PlatformMethodHandler: NSObject, FlutterPlugin {
        
    public static let name = "\(Bundle.main.serviceIdentifier)/platform"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: Self.name, binaryMessenger: registrar.messenger())
        let instance = PlatformMethodHandler()
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.channel = channel
    }
    
    private var channel: FlutterMethodChannel?
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "get_paths":
            result(getPaths(args: call.arguments) as NSDictionary)
        case "get_device_identity":
            result(getDeviceIdentity())
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func getPaths(args: Any?) -> [String:String] {
        return [
            "base": FilePath.sharedDirectory.path,
            "working": FilePath.workingDirectory.path,
            "temp": FilePath.cacheDirectory.path
        ]
    }
    
    private func getDeviceIdentity() -> [String: Any] {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        
        let model = UIDevice.current.model
        let systemName = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion
        let localizedModel = UIDevice.current.localizedModel
        let deviceName = UIDevice.current.name
        
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? ""
        
        // Keychain App Instance ID with robust fallback
        var keychainId = KeychainHelper.load()
        if keychainId == nil || keychainId!.isEmpty {
            keychainId = UUID().uuidString
            KeychainHelper.save(keychainId!)
            
            // Backup validation/fallback if Keychain is blocked by sandbox/signatures
            let keychainBackupKey = "com.hiddify.app.keychainIdBackup"
            let storedBackup = UserDefaults.standard.string(forKey: keychainBackupKey)
            if let storedBackup = storedBackup, !storedBackup.isEmpty {
                keychainId = storedBackup
            } else {
                UserDefaults.standard.set(keychainId, forKey: keychainBackupKey)
            }
        } else {
            // Sync fallback
            let keychainBackupKey = "com.hiddify.app.keychainIdBackup"
            UserDefaults.standard.set(keychainId, forKey: keychainBackupKey)
        }
        
        // Install UUID
        let installKey = "com.hiddify.app.installUuid"
        var installUuid = UserDefaults.standard.string(forKey: installKey)
        if installUuid == nil || installUuid!.isEmpty {
            installUuid = UUID().uuidString
            UserDefaults.standard.set(installUuid, forKey: installKey)
        }
        
        var appAttestSupported = false
        if #available(iOS 14.0, *) {
            appAttestSupported = DCAppAttestService.shared.isSupported
        }
        
        let teamId = "Unknown"
        
        return [
            "bundleId": bundleId,
            "appVersion": appVersion,
            "appBuild": appBuild,
            "teamId": teamId,
            "model": model,
            "systemName": systemName,
            "systemVersion": systemVersion,
            "localizedModel": localizedModel,
            "deviceName": deviceName,
            "idfv": idfv,
            "keychainAppInstanceId": keychainId ?? "",
            "installUuid": installUuid ?? "",
            "appAttestSupported": appAttestSupported
        ]
    }
}

public class KeychainHelper {
    private static let service = "com.hiddify.app.deviceidentity"
    private static let account = "appInstanceId"
    
    public static func save(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // Delete existing first to avoid duplicate errors
        SecItemDelete(query as CFDictionary)
        
        // Add new item with proper data
        var newQuery = query
        newQuery[kSecValueData as String] = data
        
        SecItemAdd(newQuery as CFDictionary, nil)
    }
    
    public static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
