//
//  PlatformMethodHandler.swift
//  Runner
//
//  Created by Hiddify on 12/27/23.
//

import Flutter
import Combine
import HiddifyCore

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
        
        // Safe default or fallback for device name to avoid sandbox restrictions on launch
        let deviceName = "iPhone"
        
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? ""
        
        // Super-safe persistent Instance ID stored in UserDefaults to bypass Keychain signature/sandbox restrictions entirely
        let keychainKey = "com.hiddify.app.keychainAppInstanceId"
        var keychainId = UserDefaults.standard.string(forKey: keychainKey)
        if keychainId == nil || keychainId!.isEmpty {
            keychainId = UUID().uuidString
            UserDefaults.standard.set(keychainId, forKey: keychainKey)
        }
        
        // Install UUID
        let installKey = "com.hiddify.app.installUuid"
        var installUuid = UserDefaults.standard.string(forKey: installKey)
        if installUuid == nil || installUuid!.isEmpty {
            installUuid = UUID().uuidString
            UserDefaults.standard.set(installUuid, forKey: installKey)
        }
        
        // App Attest safely returning false to prevent linking or signature validation crashes in unsigned packages
        let appAttestSupported = false
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
