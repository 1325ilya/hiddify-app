import UIKit
import Flutter
import HiddifyCore
import Sentry
@main
@objc class AppDelegate: FlutterAppDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupFileManager()
        registerHandlers()
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func setupFileManager() {
        try? FileManager.default.createDirectory(at: FilePath.workingDirectory, withIntermediateDirectories: true)
        FileManager.default.changeCurrentDirectoryPath(FilePath.sharedDirectory.path)
    }
    
    func registerHandlers() {
        if let registrar = self.registrar(forPlugin: MethodHandler.name) {
            MethodHandler.register(with: registrar)
        }
        if let registrar = self.registrar(forPlugin: PlatformMethodHandler.name) {
            PlatformMethodHandler.register(with: registrar)
        }
        if let registrar = self.registrar(forPlugin: FileMethodHandler.name) {
            FileMethodHandler.register(with: registrar)
        }
        if let registrar = self.registrar(forPlugin: StatusEventHandler.name) {
            StatusEventHandler.register(with: registrar)
        }
        if let registrar = self.registrar(forPlugin: AlertsEventHandler.name) {
            AlertsEventHandler.register(with: registrar)
        }
    }
}

