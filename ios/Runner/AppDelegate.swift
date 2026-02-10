// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.

import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var fastVLMPlugin: FastVLMPlugin?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        
        // Initialize FastVLM plugin
        fastVLMPlugin = FastVLMPlugin(messenger: controller.binaryMessenger)
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
