//
//  GradViewController.swift
//  HTTPSwiftLab5
//
//  Created by Rick Lattin on 11/25/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import CreateML
import CoreML
import UIKit
import Metal
import Accelerate

class GradViewController: UIViewController {

    @IBOutlet weak var testOutputLabel: UILabel!
    @IBOutlet weak var predictionLabel: UILabel!
    
    @IBAction func makePrediction(_ sender: Any) {
        self.calcVowel(audio_data: self.audio.fftData, peak_index: self.peak_1_index)
        self.testModel()
    }
    let client = MlaasModel()
    
    @IBOutlet weak var freq1grad: UILabel!
    @IBOutlet weak var freq2grad: UILabel!
    @IBOutlet weak var userView: UIView!
    
    var isListeningForPreds: Int = 0
    
    var cur_hz_1: Double = 0.0
    var cur_hz_2: Double = 0.0
    var peak_1_index:Int = 0
    var peak_value: Double = 0.0
    var harmonic_value: Double = 0.0
    
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //sound graph setup
        var run_counter = 0
        setupGraph()
        audio.startMicrophoneProcessing(withFps: 20)
        audio.play()

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
        Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { _ in
            if(self.audio.timeData[0] > 0.037){
                self.updateLabels()
                run_counter = 0
            } else if run_counter > 40{
                if let label1 = self.freq1grad, let label2 = self.freq2grad {
                    label1.text = "Noise"
                    label2.text = "Noise"
                }
            } else {
                run_counter = run_counter+1
            }
        }
        
        // Do any additional setup after loading the view.
    }
    
    // MARK: - Audio Input Functions
    func setupGraph() {
            if let graph = self.graph {
                graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
                graph.addGraph(withName: "fft",
                               shouldNormalizeForFFT: true,
                               numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 2)
                graph.addGraph(withName: "time",
                               numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
                graph.makeGrids()
            }
        }

        func updateGraph() {
            if let graph = self.graph {
                graph.updateGraph(data: audio.fftData, forKey: "fft")
                graph.updateGraph(data: audio.timeData, forKey: "time")
            }
        }
        
        func updateLabels() {
            if let label1 = self.freq1grad, let label2 = self.freq2grad {
                self.calcTone(audio_data: audio.fftData)
//                var output_label_1 = String(Int(cur_hz_1))
                label1.text = String(peak_value) + " Hz"
//                var output_label_2 = String(Int(cur_hz_2))
                label2.text = String(harmonic_value) + " Hz"
            }
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            audio.pause()
        }
        
        func calcTone(audio_data: [Float]) {
            let data: [Float] = audio_data
            var window: [Float] = []
            var max_list: [Int: Int] = [:]
            var max_list_val: [Int: Float] = [:]
            let hz_per_index = 44100.0/Double(AudioConstants.AUDIO_BUFFER_SIZE)
            
            for i in 9...(data.count-6) {
                window = Array(data[(i)...(i)+5])

                if let win_max = window.max(){
                    if let win_index = data.firstIndex(of: win_max){
                        
                        if let _ = max_list[win_index]{
                            max_list[win_index] = max_list[win_index]!+1
                            max_list_val[win_index] = win_max
                        }else {
                            max_list[win_index] = 1
                            max_list_val[win_index] = win_max
                        }
                    }
                }
            }
            
            //populates all possible peaks
            var possible_peaks: [Int: Float] = [:]
            for item in max_list{
                if item.value >= 6{
                    possible_peaks[item.key] = max_list_val[item.key]
                }
            }
            
            // Get first highest frequency from dict
            if let (key, _) = possible_peaks.max(by: { $0.value < $1.value }){
                cur_hz_1 = Double(key)*hz_per_index
                peak_1_index = key
                possible_peaks.removeValue(forKey: key)
            } else {
                cur_hz_1 = Double(0.0)
            }
                    
            // Get second highest frequency from dict
            if let (key, _) = possible_peaks.max(by: {  $0.value < $1.value }){
                cur_hz_2 = Double(key)*hz_per_index
            } else {
                cur_hz_2 = Double(0.0)
            }
        }
    
    func calcVowel(audio_data: [Float], peak_index: Int) {
        let data: [Float] = audio_data
        self.peak_value = Double(data[peak_index])
        self.harmonic_value = Double(data[peak_index*2])
//        let ratio_percent = harmonic_value/peak_value
    }
    
    func copyBundleFileToDocumentsDirectoryIfNeeded(file:String) {
            let fileManager = FileManager.default
            guard let bundleURL = Bundle.main.url(forResource: file, withExtension: "json"),
                  let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(file+".json") else {
                print("File path error.")
                return
            }
            
            if !fileManager.fileExists(atPath: documentsURL.path) {
                do {
                    try fileManager.copyItem(at: bundleURL, to: documentsURL)
                    print(file+".json copied to documents directory.")
                } catch {
                    print("Failed to copy \(file).json: \(error.localizedDescription)")
                }
            }
    }
    
    
    // MARK: - Create ML Functions
    func testModel(){
        do {
            let config = MLModelConfiguration()
            let model = try AudioTabularClassifier_1(configuration: config)
            let prediction = try model.prediction(Peak: peak_value, Harmonic: harmonic_value)
            print(String(prediction.Vowel))
            self.predictionLabel.text = "Prediction Result: " + String(prediction.Vowel)
        } catch {
            
        }
    }
    
    
//    func trainCoreMLModel(){
//        do {
//            //read in dataset
//            copyBundleFileToDocumentsDirectoryIfNeeded(file: "audio_table_data_test")
//            let csvFile = Bundle.main.url(forResource: "audio_table_data_test", withExtension: "csv")!
//            let dataTable = try MLDataTable(contentsOf: csvFile)
//            print(dataTable)
//            
//            //set columns to grab
//            let classifierColumns = ["Peak", "Harmonic", "Vowel"]
//            let classifierTable = dataTable[classifierColumns]
//            
//            //divide data
//            let (classifierEvaluationTable, classifierTrainingTable) = classifierTable.randomSplit(by: 0.20, seed: 5)
//            let classifier = try MLDecisionTreeClassifier(trainingData: classifierTrainingTable,
//                                              targetColumn: "Vowel")
//            
//            let trainingError = classifier.trainingMetrics.classificationError
//            let trainingAccuracy = (1.0 - trainingError) * 100
//
//            // Classifier validation accuracy as a percentage
//            let validationError = classifier.validationMetrics.classificationError
//            let validationAccuracy = (1.0 - validationError) * 100
//            
//            let classifierEvaluation = classifier.evaluation(on: classifierEvaluationTable)
//
//            // Classifier evaluation accuracy as a percentage
//            let evaluationError = classifierEvaluation.classificationError
//            let evaluationAccuracy = (1.0 - evaluationError) * 100
//            
//            print("Train Accuracy: ",trainingAccuracy)
//            print("Val Accuracy: ",validationAccuracy)
//            print("Eval Accuracy: ",evaluationAccuracy)
//            
//            testOutputLabel.text = String(validationAccuracy)
//            
//            let classifierMetadata = MLModelMetadata(author: "Rick Lattin",
//                                                     shortDescription: "Predicts the whether the vowel ooo or aaa is said",
//                                                     version: "1.0")
//
//            // Save the trained classifier model to the Desktop.
//            let gradFileUrl = URL(fileURLWithPath: "/Users/ricklattin/Documents/SMU Year 5 Sem 1/Mobile Apps/Mobile Apps Lab 5/mobile_apps_ml_as_service/HTTPSwiftLab5/grad_models/grad_cur_audio_model.mlmodel")
//            try classifier.write(to: gradFileUrl, metadata: classifierMetadata)
//        } catch {
//            print("Error loading data table: \(error)")
//        }
//    }

}
