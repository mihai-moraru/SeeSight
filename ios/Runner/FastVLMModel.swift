//
// FastVLMModel.swift
// Runner
//
// FastVLM Model wrapper for Flutter integration
// Based on Apple's ml-fastvlm implementation
// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.
//

import CoreImage
import Foundation
import MLX
import MLXLMCommon
import MLXVLM

struct VLMResult {
    let response: String
    let ttft: String
    let tokenCount: Int
}

@MainActor
class FastVLMModel {
    
    public var running = false
    public var modelInfo = ""
    
    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }
    
    private let modelConfiguration: ModelConfiguration
    
    /// parameters controlling the output
    let generateParameters = GenerateParameters(temperature: 0.0)
    let maxTokens = 240
    
    /// update the display every N tokens
    let displayEveryNTokens = 4
    
    private var loadState = LoadState.idle
    private var currentTask: Task<VLMResult, Never>?
    
    enum EvaluationState: String, CaseIterable {
        case idle = "Idle"
        case processingPrompt = "Processing Prompt"
        case generatingResponse = "Generating Response"
    }
    
    public var evaluationState = EvaluationState.idle
    
    public init() {
        // Get model configuration from bundle
        modelConfiguration = FastVLMModel.getModelConfiguration()
        FastVLM.register(modelFactory: VLMModelFactory.shared)
    }
    
    private static func getModelConfiguration() -> ModelConfiguration {
        // Look for the model in the app bundle
        let bundle = Bundle.main
        if let modelURL = bundle.url(forResource: "model", withExtension: nil) {
            return ModelConfiguration(directory: modelURL)
        }
        
        // Fallback: Use the FastVLM framework's bundled config
        return FastVLM.modelConfiguration
    }
    
    private func _load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            // limit the buffer cache
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
            
            let modelContainer = try await VLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.modelInfo =
                    "Downloading \(self?.modelConfiguration.name ?? "model"): \(Int(progress.fractionCompleted * 100))%"
                }
            }
            self.modelInfo = "Loaded"
            loadState = .loaded(modelContainer)
            return modelContainer
            
        case .loaded(let modelContainer):
            return modelContainer
        }
    }
    
    public func load() async {
        do {
            _ = try await _load()
        } catch {
            self.modelInfo = "Error loading model: \(error)"
        }
    }
    
    public func generate(image: CIImage, prompt: String) async -> VLMResult {
        if let currentTask, running {
            return await currentTask.value
        }
        
        running = true
        currentTask?.cancel()
        
        let task = Task { () -> VLMResult in
            var response = ""
            var promptTime = ""
            var tokenCount = 0
            
            do {
                let modelContainer = try await _load()
                
                if Task.isCancelled {
                    return VLMResult(response: "", ttft: "", tokenCount: 0)
                }
                
                let userInput = UserInput(
                    prompt: .text(prompt),
                    images: [.ciImage(image)]
                )
                
                let result = try await modelContainer.perform { context in
                    evaluationState = .processingPrompt
                    
                    let llmStart = Date()
                    let input = try await context.processor.prepare(input: userInput)
                    
                    var seenFirstToken = false
                    
                    let result = try MLXLMCommon.generate(
                        input: input, parameters: generateParameters, context: context
                    ) { tokens in
                        if Task.isCancelled {
                            return .stop
                        }
                        
                        if !seenFirstToken {
                            seenFirstToken = true
                            
                            let llmDuration = Date().timeIntervalSince(llmStart)
                            let text = context.tokenizer.decode(tokens: tokens)
                            Task { @MainActor in
                                self.evaluationState = .generatingResponse
                            }
                            promptTime = "\(Int(llmDuration * 1000)) ms"
                            response = text
                        }
                        
                        if tokens.count % displayEveryNTokens == 0 {
                            let text = context.tokenizer.decode(tokens: tokens)
                            response = text
                        }
                        
                        if tokens.count >= maxTokens {
                            return .stop
                        } else {
                            return .more
                        }
                    }
                    
                    tokenCount = result.output.split(separator: " ").count
                    return result
                }
                
                if !Task.isCancelled {
                    response = result.output
                }
                
            } catch {
                if !Task.isCancelled {
                    response = "Failed: \(error)"
                }
            }
            
            if evaluationState == .generatingResponse {
                evaluationState = .idle
            }
            
            running = false
            return VLMResult(response: response, ttft: promptTime, tokenCount: tokenCount)
        }
        
        currentTask = task
        return await task.value
    }
    
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        running = false
    }
    
    /// Generate response with streaming callbacks
    public func generateStreaming(image: CIImage, prompt: String, onEvent: @escaping ([String: Any]) -> Void) async {
        if running {
            return
        }
        
        running = true
        currentTask?.cancel()
        
        var tokenCount = 0
        
        do {
            let modelContainer = try await _load()
            
            if Task.isCancelled {
                onEvent(["type": "error", "message": "Cancelled"])
                running = false
                return
            }
            
            let userInput = UserInput(
                prompt: .text(prompt),
                images: [.ciImage(image)]
            )
            
            let _ = try await modelContainer.perform { context in
                evaluationState = .processingPrompt
                onEvent(["type": "state", "state": "processingPrompt"])
                
                let llmStart = Date()
                let input = try await context.processor.prepare(input: userInput)
                
                var seenFirstToken = false
                
                let result = try MLXLMCommon.generate(
                    input: input, parameters: generateParameters, context: context
                ) { tokens in
                    if Task.isCancelled {
                        return .stop
                    }
                    
                    if !seenFirstToken {
                        seenFirstToken = true
                        
                        let llmDuration = Date().timeIntervalSince(llmStart)
                        let text = context.tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            self.evaluationState = .generatingResponse
                        }
                        
                        // Send TTFT event
                        onEvent([
                            "type": "ttft",
                            "ttft": "\(Int(llmDuration * 1000)) ms"
                        ])
                        
                        // Send state change
                        onEvent(["type": "state", "state": "generatingResponse"])
                        
                        // Send first token
                        onEvent([
                            "type": "token",
                            "text": text,
                            "tokenCount": tokens.count
                        ])
                    }
                    
                    // Stream every N tokens
                    if tokens.count % displayEveryNTokens == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        onEvent([
                            "type": "token",
                            "text": text,
                            "tokenCount": tokens.count
                        ])
                    }
                    
                    tokenCount = tokens.count
                    
                    if tokens.count >= maxTokens {
                        return .stop
                    } else {
                        return .more
                    }
                }
                
                return result
            }
            
            // Send completion event
            onEvent([
                "type": "complete",
                "tokenCount": tokenCount
            ])
            
        } catch {
            if !Task.isCancelled {
                onEvent([
                    "type": "error",
                    "message": "Failed: \(error)"
                ])
            }
        }
        
        evaluationState = .idle
        onEvent(["type": "state", "state": "idle"])
        running = false
    }
}
