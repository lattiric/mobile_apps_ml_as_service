//
//  RingBuffer.swift
//  HTTPSwiftExample
//
//  Created by Eric Larson on 10/27/17.
//  Copyright © 2017 Eric Larson. All rights reserved.
//

import UIKit

let BUFFER_SIZE = 50

class RingBuffer: NSObject {
    
    // Arrays to hold the peaks (instead of x, y, z)
    var peak1 = [Double](repeating: 0, count: BUFFER_SIZE)
    var peak2 = [Double](repeating: 0, count: BUFFER_SIZE)
    
    var head: Int = 0 {
        didSet {
            if head >= BUFFER_SIZE {
                head = 0
            }
        }
    }
    
    // Modify to accept peak1 and peak2 data
    func addNewData(peak1Data: Double, peak2Data: Double) {
        print("Adding new data: \(peak1Data), \(peak2Data)")  // Debugging line
        peak1[head] = peak1Data
        peak2[head] = peak2Data
        head += 1
        if head >= BUFFER_SIZE {
            head = 0
        }
    }
    
    func getDataAsVector() -> [Double] {
        var allVals = [Double](repeating: 0, count: 2 * BUFFER_SIZE)
        
        for i in 0..<BUFFER_SIZE {
            let idx = (head + i) % BUFFER_SIZE
            allVals[2 * i] = peak1[idx]
            allVals[2 * i + 1] = peak2[idx]
            //print("Data at \(i): \(peak1[idx]), \(peak2[idx])")  // Debugging line
        }
        
        return allVals
    }
}
