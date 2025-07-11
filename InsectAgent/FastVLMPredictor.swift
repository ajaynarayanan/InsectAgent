//
//  FastVLMPredictor.swift
//  FastVLM
//
//  Created by Ajay Narayanan on 7/1/25.
//

import UIKit
import MLXLMCommon
import SwiftUICore


actor FastVLMPredictor: ObservableObject {
    @Published private(set) var tau: Double
    var model: FastVLMModel?

    init(tau: Double) {
        self.tau = tau
    }
    
    /// Make sure `model` exists, creating it on the main actor if needed.
    func ensureModelInitialized() async {
        guard model == nil else { return }
        // This calls the @MainActor init of FastVLMModel
        let newModel = await FastVLMModel()
        // Assign back on the actor’s own executor
        self.model = newModel
    }
    
    func updateTau(_ newTau: Double) {
        tau = newTau
    }
    
    private func generatePrompt(
        imageName: String,
        candidates: [String],
        knowledgeEntries: [String: Any]
    ) -> String {
        var prompt = """
        I'm showing you an image of an insect. \
        Your task is to identify which type of insect this is from the provided candidates, \
        using both the visual appearance and the knowledge provided about each candidate. \
        YOUR OUTPUT should be just the insect candidate name, no need of any justification.\n\nCandidates:\n
        """
        for (i, candidate) in candidates.enumerated() {

            if let entry = knowledgeEntries[candidate] as? [String: Any],
               let label = entry["label"] as? String {
                prompt += "\(i + 1). \(label)\n"
            } else {
                prompt += "\(i + 1). \(candidate)\n"
            }
            
            
            if let entry = knowledgeEntries[candidate] as? [String: Any],
               let vk = entry["visual_knowledge"] as? String {
                prompt += "Knowledge: \(vk)\n\n"
            } else {
                prompt += "Knowledge: No specific visual knowledge available for this candidate.\n\n"
            }
        }
        prompt += """
        
        Analyze the image carefully and compare the visual characteristics of the insect with the knowledge provided for each candidate. \
        Then, give your prediction on which candidate is most likely correct. YOUR OUTPUT should be just the insect candidate name, no need of any justification. 
        """
        return prompt
    }

    /// Predict, sending both the image and the prompt as multipart/form-data.
    func predict(
        image: UIImage,
        top_k: Int,
        visionPredictions: [String: Float],
        classes_to_idx: [String: Any],
        knowledgeEntries: [String: Any]
    ) async throws -> String {


        // Get the top candidate (key and confidence)
        if let (topKey, topConf) = visionPredictions.max(by: { $0.value < $1.value }) {
            print(topKey, topConf)
            if Double(topConf) > tau {
                // Vision confidence is high, so skip calling the LLM
                print("Vision confidence high (≥τ); no VLM fallback.")
                return "not using LLM"
            }
        }

        print("Using VLM for final result!!")
        
        // Take only the top_k candidates by descending confidence
        let sortedCandidates = visionPredictions
            .sorted(by: { $0.value > $1.value })
            .prefix(top_k)
            .compactMap { candidateName, _ in
                if let idxAny = classes_to_idx[candidateName] {
                    if let idxInt = idxAny as? Int {
                        return String(idxInt)
                    }
                    else if let idxNum = idxAny as? NSNumber {
                        return String(idxNum.intValue)
                    }
                }
                return nil
            }

        let promptText = await generatePrompt(
            imageName: image.accessibilityIdentifier ?? "insect.jpg",
            candidates: sortedCandidates,
            knowledgeEntries: knowledgeEntries
        )

        
        // Reset Response UI (show spinner)
        Task { @MainActor in
            await model!.output = ""
        }

        // Construct request to model
        let userInput = UserInput(
            prompt: .text(promptText),
            images: [.ciImage(CIImage(image: image)!)]
        )

        print("User Input")
        print(userInput)
        
        // 3️⃣ Kick off generation and capture the Task
        let generationTask = await model!.generate(userInput)

        // 4️⃣ Wait for it to finish
        let taskOutput = await generationTask.value

        // return the value
        return await model!.output

        
    }
}

// Helper to append string to Data
fileprivate extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) {
            append(d)
        }
    }
}
