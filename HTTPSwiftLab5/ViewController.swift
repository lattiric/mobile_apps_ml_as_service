//
//  ViewController.swift
//  HTTPSwiftExample
//
//  Created by Eric Larson on 3/30/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//  Updated 2024

// This example is meant to be run with the python example:
//              fastapi_turicreate.py
//              from the course GitHub repository



import UIKit
import Metal
import Accelerate
import CoreMotion

class ViewController: UIViewController, ClientDelegate, UITextFieldDelegate {
    
    // MARK: Class Properties
    
    // interacting with server
    let client = MlaasModel() // how we will interact with the server
    
    // operation queues
//    let motionOperationQueue = OperationQueue()
//    let calibrationOperationQueue = OperationQueue()
//    
//    // motion data properties
    var ringBuffer = RingBuffer()
//    let motion = CMMotionManager()
    var magThreshold = 0.1
    var ipUrlAdress = "none"
    
    // state variables
    var isCalibrating = false
    var isWaitingForMotionData = false
    
    // User Interface properties
    let animation = CATransition()
    @IBOutlet weak var dsidLabel: UILabel!
    @IBOutlet weak var oooLabel: UILabel!
    //@IBOutlet weak var rightArrow: UILabel!
    @IBOutlet weak var aaaLabel: UILabel!
    //@IBOutlet weak var leftArrow: UILabel!
    @IBOutlet weak var largeMotionMagnitude: UIProgressView!
    
    @IBAction func getAllData(_ sender: Any) {
//        client.getAllData()
        for number in peakList{
            print(number)
        }
        print("-------------------------")
        for number in harmonicList{
            print(number)
        }
        for label in labelList{
            print(label)
        }
    }
    
    //Sound variables
    @IBOutlet weak var freq1: UILabel!
    @IBOutlet weak var freq2: UILabel!
    @IBOutlet weak var userView: UIView!
    
    var isListeningForPreds: Int = 0
    @IBAction func togglePredictionListening(_ sender: Any) {
        if(isListeningForPreds == 0){
            isListeningForPreds = 1
            self.startPredictions()
        }else{
            isListeningForPreds = 0
            self.stopPredictions()
        }
        
    }
    
    var cur_hz_1: Double = 0.0
    var cur_hz_2: Double = 0.0
    var peak_1_index:Int = 0
    var peak_value: Double = 0.0
    var harmonic_value: Double = 0.0
    
    var peakList: [Double] = []
    var harmonicList: [Double] = []
    var labelList: [String] = []
    
    //timer to run for like 3 seconds durikng calibration
    var calibrationTimer: Timer?
    var calibrationDuration: TimeInterval = 2.0
    var predictionTimer: Timer?
    var predictionDuration: TimeInterval = 1.0
    
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    // MARK: Class Properties with Observers
    enum CalibrationStage:String {
        case notCalibrating = "notCalibrating"
        case ooo = "ooo"
        case aaa = "aaa"
    }
    
    var calibrationStage:CalibrationStage = .notCalibrating {
        didSet{
            self.setInterfaceForCalibrationStage()
        }
    }
        
    @IBAction func magnitudeChanged(_ sender: UISlider) {
        self.magThreshold = Double(sender.value)
    }
    
    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        print("opened app")
        
        //sound graph setup
        var run_counter = 0
        // graph and audio processing (taken from original push, just moved to modules)
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
                if let label1 = self.freq1, let label2 = self.freq2 {
                    label1.text = "Noise"
                    label2.text = "Noise"
                }
            } else {
                run_counter = run_counter+1
            }
        }
        
        // create reusable animation
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        animation.type = CATransitionType.fade
        animation.duration = 0.5
        
        // setup core motion handlers
        //startMotionUpdates()
        
        // use delegation for interacting with client 
        client.delegate = self
        client.updateDsid(5) // set default dsid to start with
        
//        IPTextField.delegate = self
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            self.ipUrlAdress = textField.text ?? ""
        print("Enter pressed. IP address updated to: \(self.client.server_ip)")
            return true
    }
    
    //MARK: UI Buttons
    @IBAction func getDataSetId(_ sender: AnyObject) {
        client.getNewDsid() // protocol used to update dsid
    }
    
    @IBAction func startCalibration(_ sender: AnyObject) {
        self.isWaitingForMotionData = false // dont do anything yet
        nextCalibrationStage() // kick off the calibration stages
        
    }
    
    @IBAction func makeModel(_ sender: AnyObject) {
        client.trainModel()
    }

}

//MARK: Protocol Required Functions
extension ViewController {
    func updateDsid(_ newDsid:Int){
        // delegate function completion handler
        DispatchQueue.main.async{
            // update label when set
            self.dsidLabel.layer.add(self.animation, forKey: nil)
            self.dsidLabel.text = "Current DSID: \(newDsid)"
        }
    }
    
    func receivedPrediction(_ prediction:[String:Any]){
        if let labelResponse = prediction["prediction"] as? String{
            print(labelResponse)
            self.displayLabelResponse(labelResponse)
        }
        else{
            print("Received prediction data without label.")
        }
    }
}


//MARK: Calibration UI Functions
extension ViewController {
    
    func setDelayedWaitingToTrue(_ time:Double){
        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
            self.isWaitingForMotionData = true
        })
    }
    
    func setAsCalibrating(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.red
    }
    
    func setAsNormal(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.white
    }
    
    // blink the UILabel
    func blinkLabel(_ label:UILabel){
        DispatchQueue.main.async {
            self.setAsCalibrating(label)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                self.setAsNormal(label)
            })
        }
    }
    
    func displayLabelResponse(_ response:String){
        switch response {
        case "['ooo']","ooo":
            blinkLabel(oooLabel)
            break
        case "['aaa']","aaa":
            blinkLabel(aaaLabel)
            break
        default:
            print("Unknown")
            break
        }
    }
    
    func setInterfaceForCalibrationStage(){
        switch calibrationStage {
        case .ooo:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsCalibrating(self.oooLabel)
                self.setAsNormal(self.aaaLabel)
            }
            break
        case .aaa:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsNormal(self.oooLabel)
                self.setAsCalibrating(self.aaaLabel)
            }
            break
        case .notCalibrating:
            self.isCalibrating = false
            DispatchQueue.main.async{
                self.setAsNormal(self.oooLabel)
                self.setAsNormal(self.aaaLabel)
            }
            break
        }
    }
    
//    func nextCalibrationStage(){
//        switch self.calibrationStage {
//        case .notCalibrating:
//            //start with up arrow
//            self.calibrationStage = .ooo
//            setDelayedWaitingToTrue(1.0)
//            break
//        case .ooo:
//            //go to right arrow
//            self.startAudioRecording(for: "ooo")
//            self.calibrationStage = .aaa
//            setDelayedWaitingToTrue(1.0)
//            break
//        case .aaa:
//            //go to down arrow
//            self.startAudioRecording(for: "aaa")
//            self.calibrationStage = .notCalibrating
//            setDelayedWaitingToTrue(1.0)
//            break
//        }
//    }
    
    func nextCalibrationStage() {
        switch self.calibrationStage {
        case .notCalibrating:
            self.calibrationStage = .ooo
            setDelayedWaitingToTrue(1.0) // wait briefly before starting the recording
            startAudioRecording(for: "ooo")  // Start recording for 'ooo'
            break
            
        case .ooo:
            // After 2 seconds of recording for 'ooo', move to 'aaa'
            self.calibrationStage = .aaa
            setDelayedWaitingToTrue(1.0)
            startAudioRecording(for: "aaa") // Start recording for 'aaa'
            break

        case .aaa:
            // After 2 seconds of recording for 'aaa', finish calibration
            self.calibrationStage = .notCalibrating
            setDelayedWaitingToTrue(1.0)  // Delay before switching UI back
            break
        }
    }
    
        // MARK: - Audio Recording and Peak Calculation
        func startAudioRecording(for label: String) {
            audio.startMicrophoneProcessing(withFps: 20)
            
            calibrationTimer?.invalidate()  // get rid of any existing timer
                calibrationTimer = Timer.scheduledTimer(withTimeInterval: calibrationDuration, repeats: false) { _ in
                   
                    //this will go for 2 seconds or whatever we say and then stop, get the 2 highest peaks, and send them to searver
                    
                    self.audio.stopMicrophoneProcessing()
                    self.analyzeAudioPeaks(for: label)
            }
            
//            //for blinking?
//            if label == "ooo" {
//                    self.setAsCalibrating(self.oooLabel)
//                    self.setAsNormal(self.aaaLabel)
//                } else {
//                    self.setAsCalibrating(self.aaaLabel)
//                    self.setAsNormal(self.oooLabel)
//                }
        }
    
    func analyzeAudioPeaks(for label: String) {
            //get highest peaks in the data
            calcTone(audio_data: audio.fftData)
            calcVowel(audio_data: audio.fftData, peak_index: self.peak_1_index)
            
            // Output the two highest peaks to the console
            print("\(label) Calibration Peaks:")
        print("Peak 1: \(peak_value) Hz")
        print("Peak 2: \(harmonic_value) Hz")
            
        //adding to total list
        self.peakList.append(peak_value)
        self.harmonicList.append(harmonic_value)
        self.labelList.append(label)
        
        // send data to server
        let dataToSend: [Double] = [peak_value, harmonic_value]
        client.sendData(dataToSend, withLabel: label)
           
        if self.calibrationStage != .notCalibrating {  //ok fixed this, will calibrate oo once and aa once for each time u click "calibrate once"
                nextCalibrationStage()
            }
        }
}


//MARK: Audio Input Functions
extension ViewController {
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
            if let label1 = self.freq1, let label2 = self.freq2 {
                self.calcTone(audio_data: audio.fftData)
                var output_label_1 = String(Int(cur_hz_1))
                label1.text = output_label_1 + " Hz"
                var output_label_2 = String(Int(cur_hz_2))
                label2.text = output_label_2 + " Hz"
            }
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            audio.pause()
        }
        
        func calcTone(audio_data: [Float]) {
            var data: [Float] = audio_data
            var window: [Float] = []
            var max_list: [Int: Int] = [:]
            var max_list_val: [Int: Float] = [:]
            var hz_per_index = 44100.0/Double(AudioConstants.AUDIO_BUFFER_SIZE)
            
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
            }
    
    func startPredictions(){
        audio.startMicrophoneProcessing(withFps: 20)
        
        predictionTimer?.invalidate()  // get rid of any existing timer
        predictionTimer = Timer.scheduledTimer(withTimeInterval: predictionDuration, repeats: true) { _ in
            
            var vol_max: Float = 0.0
            for x in 1...100 {
                if(self.audio.timeData[x] > vol_max){
                    vol_max = self.audio.timeData[x]
                }
            }
            print("Max Volume: ", vol_max)
            if(vol_max > 0.07){
                self.calcTone(audio_data: self.audio.fftData)
                self.calcVowel(audio_data: self.audio.fftData, peak_index: self.peak_1_index)
                
                // Output the two highest peaks to the console
                print("Prediction Peaks:")
                print("Peak 1: \(self.peak_value) Hz")
                print("Peak 2: \(self.harmonic_value) Hz")
                
                // send data to server
                let dataToSend: [Double] = [self.peak_value, self.harmonic_value]
                self.client.sendData(dataToSend)
            }
        }
    }
    
    func stopPredictions(){
        audio.stopMicrophoneProcessing()
        predictionTimer?.invalidate()
    }
}





//MARK: Motion Extension Functions
//extension ViewController {
//    // Core Motion Updates
//    func startMotionUpdates(){
//        // some internal inconsistency here: we need to ask the device manager for device
//
//        if self.motion.isDeviceMotionAvailable{
//            self.motion.deviceMotionUpdateInterval = 1.0/200
//            self.motion.startDeviceMotionUpdates(to: motionOperationQueue, withHandler: self.handleMotion )
//        }
//    }
//
//    func handleMotion(_ motionData:CMDeviceMotion?, error:Error?){
//        if let accel = motionData?.userAcceleration {
//            self.ringBuffer.addNewData(xData: accel.x, yData: accel.y, zData: accel.z)
//            let mag = fabs(accel.x)+fabs(accel.y)+fabs(accel.z)
//
//            DispatchQueue.main.async{
//                //show magnitude via indicator
//                self.largeMotionMagnitude.progress = Float(mag)/0.2
//            }
//
//            if mag > self.magThreshold {
//                // buffer up a bit more data and then notify of occurrence
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: {
//                    self.calibrationOperationQueue.addOperation {
//                        // something large enough happened to warrant
//                        self.largeMotionEventOccurred()
//                    }
//                })
//            }
//        }
//    }
//
//    // Calibration event has occurred, send to server
//    func largeMotionEventOccurred(){
//        if(self.isCalibrating){
//            //send a labeled example
//            if(self.calibrationStage != .notCalibrating && self.isWaitingForMotionData)
//            {
//                self.isWaitingForMotionData = false
//
//                // send data to the server with label
//                self.client.sendData(self.ringBuffer.getDataAsVector(),
//                                     withLabel: self.calibrationStage.rawValue)
//
//                self.nextCalibrationStage()
//            }
//        }
//        else
//        {
//            if(self.isWaitingForMotionData)
//            {
//                self.isWaitingForMotionData = false
//                //predict a label
//                self.client.sendData(self.ringBuffer.getDataAsVector())
//                // dont predict again for a bit
//                setDelayedWaitingToTrue(2.0)
//
//            }
//        }
//    }
//}
