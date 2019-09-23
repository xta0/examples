import UIKit

struct InferenceResult {
    let score: Float32
    let label: String
}

enum ModelContext {
    static let model = (name: "ResNet18", type: "pt")
    static let label = (name: "Labels", type: "txt")
    static let inputTensorSize = [1, 3, 224, 224]
    static let outputTensorSize = [1, 1000]
}

class ImagePredictor: NSObject {
    private var module = TorchModule.sharedInstance()
    private var labels: [String] = []
    private var isRunning = false

    override init() {
        super.init()
        if !loadModel() {
            fatalError("Load model failed!")
        }
        labels = loadLabels()
    }

    func forward(_ buffer: [Float32]?, completionHandler: ([InferenceResult]?, Error?) -> Void) {
        guard var tensorBuffer = buffer else {
            return
        }
        if isRunning {
            return
        }
        isRunning = true
        guard module.predict(UnsafeMutableRawPointer(&tensorBuffer), tensorSizes: ModelContext.inputTensorSize as [NSNumber], tensorType: .float) else {
            completionHandler([], ImagePredictorError.invalidInputTensor)
            return
        }
        guard let outputBuffer = module.data else {
            completionHandler([], ImagePredictorError.invalidOutputTensor)
            return
        }
        let outputs = outputBuffer.floatArray(size: ModelContext.outputTensorSize[1])
        let results = getTopN(scores: outputs, count: 3)
        completionHandler(results, nil)
        isRunning = false
    }

    private func getTopN(scores: [Float32], count: Int) -> [InferenceResult] {
        let zippedResults = zip(labels.indices, scores)
        let sortedResults = zippedResults.sorted { $0.1 > $1.1 }.prefix(count)
        return sortedResults.map { InferenceResult(score: $0.1, label: labels[$0.0]) }
    }

    private func loadLabels() -> [String] {
        if let filePath = Bundle.main.path(forResource: ModelContext.label.name, ofType: ModelContext.label.type),
            let labels = try? String(contentsOfFile: filePath) {
            return labels.components(separatedBy: .newlines)
        } else {
            fatalError("Label file was not found.")
        }
    }

    private func loadModel() -> Bool {
        if let filePath = Bundle.main.path(forResource: ModelContext.model.name, ofType: ModelContext.model.type) {
            return module.loadModel(filePath)
        }
        return false
    }
}

extension ImagePredictor {
    enum ImagePredictorError: Swift.Error {
        case invalidInputTensor
        case invalidOutputTensor
    }
}
