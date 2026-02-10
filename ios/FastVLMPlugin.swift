//
// FastVLMPlugin.swift
// Runner
//
// Flutter MethodChannel plugin for FastVLM integration
//

import Flutter
import Foundation
import UIKit
import CoreImage

@MainActor
class FastVLMPlugin: NSObject {
    private let channel: FlutterMethodChannel
    private let model = FastVLMModel()
    
    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.fastvlm/vlm",
            binaryMessenger: messenger
        )
        super.init()
        
        channel.setMethodCallHandler { [weak self] call, result in
            Task { @MainActor in
                self?.handle(call, result: result)
            }
        }
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "loadModel":
            loadModel(result: result)
            
        case "processImage":
            guard let args = call.arguments as? [String: Any],
                  let imageData = args["imageData"] as? FlutterStandardTypedData,
                  let width = args["width"] as? Int,
                  let height = args["height"] as? Int,
                  let prompt = args["prompt"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                   message: "Invalid arguments for processImage",
                                   details: nil))
                return
            }
            processImage(imageData: imageData.data, 
                        width: width, 
                        height: height, 
                        prompt: prompt, 
                        result: result)
            
        case "processImageFile":
            guard let args = call.arguments as? [String: Any],
                  let imageBytes = args["imageBytes"] as? FlutterStandardTypedData,
                  let prompt = args["prompt"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                   message: "Invalid arguments for processImageFile",
                                   details: nil))
                return
            }
            processImageFile(imageBytes: imageBytes.data, prompt: prompt, result: result)
            
        case "cancel":
            model.cancel()
            result(nil)
            
        case "getModelInfo":
            result(model.modelInfo)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func loadModel(result: @escaping FlutterResult) {
        Task {
            await model.load()
            result(true)
        }
    }
    
    private func processImage(imageData: Data, width: Int, height: Int, prompt: String, result: @escaping FlutterResult) {
        Task {
            // Convert raw BGRA8888 data to CIImage
            guard let ciImage = createCIImage(from: imageData, width: width, height: height) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "IMAGE_ERROR",
                                       message: "Failed to create image from data",
                                       details: nil))
                }
                return
            }
            
            let vlmResult = await model.generate(image: ciImage, prompt: prompt)
            
            DispatchQueue.main.async {
                result([
                    "response": vlmResult.response,
                    "ttft": vlmResult.ttft,
                    "tokenCount": vlmResult.tokenCount
                ])
            }
        }
    }
    
    private func processImageFile(imageBytes: Data, prompt: String, result: @escaping FlutterResult) {
        Task {
            guard let uiImage = UIImage(data: imageBytes),
                  let ciImage = CIImage(image: uiImage) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "IMAGE_ERROR",
                                       message: "Failed to create image from file data",
                                       details: nil))
                }
                return
            }
            
            let vlmResult = await model.generate(image: ciImage, prompt: prompt)
            
            DispatchQueue.main.async {
                result([
                    "response": vlmResult.response,
                    "ttft": vlmResult.ttft,
                    "tokenCount": vlmResult.tokenCount
                ])
            }
        }
    }
    
    private func createCIImage(from data: Data, width: Int, height: Int) -> CIImage? {
        // Create CGImage from BGRA8888 raw data
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bytesPerPixel * bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            return nil
        }
        
        return CIImage(cgImage: cgImage)
    }
}
