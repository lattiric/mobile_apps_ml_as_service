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
            let csvFile = Bundle.main.url(forResource: "audio_test_data", withExtension: "csv")!
            let dataTable = try MLDataTable(contentsOf: csvFile)
            print(dataTable)
            
            let classifierColumns = ["purpose", "solarPanels", "greenhouses", "size"]
            let classifierTable = dataTable[classifierColumns]
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
