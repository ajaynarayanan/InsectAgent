//
//  InsectAgentDemoView.swift
//  InsectAgent
//
//  Created by Ajay Narayanan on 7/2/25.
//

import SwiftUI
import CoreML
import Vision


struct InsectAgentDemoView: View {
    // MARK: — Config
    let sampleImages = ["24946", "40107", "12892"]
    let sampleImagesGroundTruth: [String: String] = [
        "24946": "longlegged spider mite",
        "12892": "large cutworm",
        "40107": "alfalfa seed chalcid"
    ]
    let predictionsToShow = 5
    
    // MARK: — Predictors
    let imagePredictor = ImagePredictor()
    @StateObject var vlmPredictor = FastVLMPredictor(tau: 70)

    // MARK: — UI State
    @State private var currentIndex: Int = 0
    @State private var tau: Double = 70.0
    @State private var visionResults: [String] = []
    @State private var vlmResult: String = ""
    @State private var finalResult: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            
            // — Image Carousel with Ground Truth
            TabView(selection: $currentIndex) {
                ForEach(sampleImages.indices, id: \.self) { idx in
                    VStack {
                        Text("Ground truth: \(sampleImagesGroundTruth[sampleImages[idx]] ?? "—")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        Image(sampleImages[idx])
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                            .shadow(radius: 4)
                        
                    }
                    .padding(.horizontal)
                    .tag(idx)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .frame(height: 320)
            
            // — Slider & Measure Button
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("τ: \(String(format: "%.1f", tau))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $tau, in: 0...100, step: 0.1)
                }
                
                Button(action: runClassification) {
                    Text("Classify")
                        .bold()
                        .frame(minWidth: 80)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // — Results Cards
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Final Prediction card (already full-width by default)
                    CardView(title: "Predicted Insect class") {
                        Text(finalResult)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Vision Top-5: now full-width
                    CardView(title: "Resnet18 Top-\(predictionsToShow) candidates") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(visionResults, id: \.self) { line in
                                Text(line)
                                    .font(.body)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity)

                    // VLM Output: also full-width
                    CardView(title: "FastVLM Output") {
                        ScrollView {
                            Text(vlmResult)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 150)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)  // Overall horizontal padding
            }

            
            Spacer()
        }
        .padding(.top)
    }
    // MARK: — Classification Logic
    

    private func runClassification() {
        vlmPredictor.updateTau(tau)
        Task {
            await classifyCurrentImage()
        }
    }
    
    func classifyCurrentImage() async {

        // 2) Lazily create your FastVLMModel
        await vlmPredictor.ensureModelInitialized()
        
        let name = sampleImages[currentIndex]
        guard let uiImage = UIImage(named: name) else { return }
        
        // 1) Vision prediction
        guard let predictions = await predictAsync(image: uiImage) else { return }
        let topK = predictions.prefix(predictionsToShow)
        visionResults = topK
            .map { "\($0.classification) – \($0.confidencePercentage)%" }
        
        // 2) VLM fallback & final selection
        let visionMap = Dictionary(
            uniqueKeysWithValues: predictions.map {
                ($0.classification, Float($0.confidencePercentage) ?? 0)
            }
        )
        
        var final = predictions.first?.classification ?? "—"
        do {
            print("classes_to_idx ::: \(classes_to_idx)")
            print("knowledgeBase ::: \(knowledgeBase)")
            let vlmText = try await vlmPredictor.predict(
                image: uiImage,
                top_k: predictionsToShow,
                visionPredictions: visionMap,
                classes_to_idx: classes_to_idx,
                knowledgeEntries: knowledgeBase
            )
            vlmResult = vlmText
            
            // If any of the topK appears in the LLM’s reply, pick it
            for p in topK {
                if vlmText.lowercased().contains(p.classification.lowercased()) {
                    final = p.classification
                    break
                }
            }
        } catch {
            vlmResult = "Error: \(error.localizedDescription)"
        }
        
        finalResult = final
    }
    
    // Async wrapper
    func predictAsync(image: UIImage) async -> [ImagePredictor.Prediction]? {
        await withCheckedContinuation { cont in
            do {
                try imagePredictor.makePredictions(for: image) { preds in
                    cont.resume(returning: preds)
                }
            } catch {
                print("Vision error:", error)
                cont.resume(returning: nil)
            }
        }
    }
    
    // Lazy-loaded resources
    private var knowledgeBase: [String: Any] {
        readJson(file_name: "enhanced_visual_knowledge")
    }
    private var classes_to_idx: [String: Any] {
        readJson(file_name: "subset_class_to_idx")
    }
    
    private func readJson(file_name: String) -> [String: Any] {
        guard
            let url = Bundle.main.url(forResource: file_name, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data),
            let dict = json as? [String: Any]
        else { return [:] }
        return dict
    }
}

// MARK: — A simple Card container
struct CardView<Content: View>: View {
    let title: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
            
            content()
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    InsectAgentDemoView()
}
