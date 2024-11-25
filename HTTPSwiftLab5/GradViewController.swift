//
//  GradViewController.swift
//  HTTPSwiftLab5
//
//  Created by Rick Lattin on 11/25/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import CreateML
import UIKit

class GradViewController: UIViewController {

    @IBOutlet weak var testOutputLabel: UILabel!
    
    @IBAction func trainModel(_ sender: Any) {
        self.trainCoreMLModel()
    }
    let client = MlaasModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
//    func createModel(fileName: String?){
//        do {
//            let config = MLModelConfiguration()
//            let model = try GoogLeNetPlaces(configuration: config)
//        }
//    }
    
    func trainCoreMLModel(){
        do {
            //read in dataset
            let csvFile = Bundle.main.url(forResource: "audio_table_data_test", withExtension: "csv")!
            let dataTable = try MLDataTable(contentsOf: csvFile)
            print(dataTable)
            
            //set columns to grab
            let classifierColumns = ["Peak", "Harmonic", "Vowel"]
            let classifierTable = dataTable[classifierColumns]
            
            //divide data
            let (classifierEvaluationTable, classifierTrainingTable) = classifierTable.randomSplit(by: 0.20, seed: 5)
            let classifier = try MLDecisionTreeClassifier(trainingData: classifierTrainingTable,
                                              targetColumn: "Vowel")
            
            let trainingError = classifier.trainingMetrics.classificationError
            let trainingAccuracy = (1.0 - trainingError) * 100

            // Classifier validation accuracy as a percentage
            let validationError = classifier.validationMetrics.classificationError
            let validationAccuracy = (1.0 - validationError) * 100
            
            let classifierEvaluation = classifier.evaluation(on: classifierEvaluationTable)

            // Classifier evaluation accuracy as a percentage
            let evaluationError = classifierEvaluation.classificationError
            let evaluationAccuracy = (1.0 - evaluationError) * 100
            
            
            print("Train Accuracy: ",trainingAccuracy)
            print("Val Accuracy: ",validationAccuracy)
            print("Eval Accuracy: ",evaluationAccuracy)
            
            testOutputLabel.text = String(validationAccuracy)
            
            let classifierMetadata = MLModelMetadata(author: "Rick Lattin",
                                                     shortDescription: "Predicts the whether the vowel ooo or aaa is said",
                                                     version: "1.0")


            /// Save the trained classifier model to the Desktop.
            let grad_models_path = "/Users/ricklattin/Documents/SMU Year 5 Sem 1/Mobile Apps/Mobile Apps Lab 5/mobile_apps_ml_as_service/grad_models"
            try classifier.write(to: URL(string: grad_models_path)!, metadata: classifierMetadata)
        } catch {
            print("Error loading data table: \(error)")
        }
    }
    
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
