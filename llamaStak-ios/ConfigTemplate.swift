import Foundation

struct ConfigTemplate {
    static let shared = ConfigTemplate()
    
    let inferenceURL: URL
    let modelId: String
    let systemMessage: String
    
    private init() {
        #if DEBUG
        inferenceURL = URL(string: "YOUR_DEBUG_URL_HERE")!
        modelId = "YOUR_MODEL_ID_HERE"
        #else
        inferenceURL = URL(string: ProcessInfo.processInfo.environment["INFERENCE_URL"] ?? "")!
        modelId = ProcessInfo.processInfo.environment["MODEL_ID"] ?? ""
        #endif
        
        systemMessage = "You are a helpful assistant."
    }
} 