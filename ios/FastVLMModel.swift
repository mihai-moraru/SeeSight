//
// FastVLMModel.swift
// Runner
//
// FastVLM Model wrapper for Flutter integration
// Uses MLXVLM package's FastVLM implementation
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
    }
    
    private static func getModelConfiguration() -> ModelConfiguration {
        // Look for the model in the app bundle
        let bundle = Bundle.main
        if let modelURL = bundle.url(forResource: "model", withExtension: nil) {
            return ModelConfiguration(directory: modelURL)
        }
        
        // Fallback: Use the VLMRegistry's FastVLM configuration
        return VLMRegistry.fastvlm
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
            
            // Warmup: run a dummy inference to compile GPU kernels
            await _warmup(modelContainer)
            
            return modelContainer
            
        case .loaded(let modelContainer):
            return modelContainer
        }
    }
    
    private func _warmup(_ modelContainer: ModelContainer) async {
        // Create a small dummy image for warmup
        let dummyImage = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let userInput = UserInput(
            prompt: .text("Hi"),
            images: [.ciImage(dummyImage)]
        )
        
        do {
            _ = try await modelContainer.perform { context in
                let input = try await context.processor.prepare(input: userInput)
                return try MLXLMCommon.generate(
                    input: input, 
                    parameters: GenerateParameters(maxTokens: 1, temperature: 0.0), 
                    context: context
                ) { (_: [Int]) -> GenerateDisposition in
                    return .stop
                }
            }
            self.modelInfo = "Ready"
        } catch {
            // Warmup failed, but model is still usable
            self.modelInfo = "Loaded (no warmup)"
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
        
        let task = Task { @MainActor () -> VLMResult in
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
                
                self.evaluationState = .processingPrompt
                
                let result = try await modelContainer.perform { context in
                    let llmStart = Date()
                    let input = try await context.processor.prepare(input: userInput)
                    
                    var seenFirstToken = false
                    
                    let result = try MLXLMCommon.generate(
                        input: input, parameters: self.generateParameters, context: context
                    ) { tokens in
                        if Task.isCancelled {
                            return .stop
                        }
                        
                        if !seenFirstToken {
                            seenFirstToken = true
                            
                            let llmDuration = Date().timeIntervalSince(llmStart)
                            let text = context.tokenizer.decode(tokens: tokens)
                            promptTime = "\(Int(llmDuration * 1000)) ms"
                            response = text
                        }
                        
                        if tokens.count % self.displayEveryNTokens == 0 {
                            let text = context.tokenizer.decode(tokens: tokens)
                            response = text
                        }
                        
                        if tokens.count >= self.maxTokens {
                            return .stop
                        } else {
                            return .more
                        }
                    }
                    
                    tokenCount = result.output.split(separator: " ").count
                    return result
                }
                
                self.evaluationState = .generatingResponse
                
                if !Task.isCancelled {
                    response = result.output
                }
                
            } catch {
                if !Task.isCancelled {
                    response = "Failed: \(error)"
                }
            }
            
            self.evaluationState = .idle
            self.running = false
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
}
