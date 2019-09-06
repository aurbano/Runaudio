//
//  ViewController.swift
//  Runaudio
//
//  Created by Alejandro Alvarez Martinez on 06/09/2019.
//

import UIKit
import CoreMotion
import AVFoundation
import Charts

class ViewController: UIViewController, ChartViewDelegate {
    
    @IBOutlet weak var bpmLabel: UILabel!
    @IBOutlet weak var stepsLabel: UILabel!
    @IBOutlet weak var chartView: LineChartView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        bpmLabel.text = String(0)
        stepsLabel.text = String(0)
        
        setupChart()
        startAccelerometers()
    }
    
    // Params
    let freq = 100.0 // in Hz
    let stepsForThresholdCalc = 3 // previous steps to use in threshold calculation
    let autoThresholdPercent = 0.05 // how much to remove from the max to get the new threshold
    let minThreshold = 0.1
    let maxThreshold = 0.7
    let maxWaitInterval = 0.6
    var threshold = 0.3
    var waitInterval = 0.4
    var avgTimingSteps = 5 // Adjusts based on speed
    
    // Vars
    var accelTimer: Timer?
    var resetStepTimer: Timer?
    var waiting: Bool = false
    let motion = CMMotionManager()
    var seq = [Double]()
    var steps = 0
    var dir = -1.0
    var startStep: DispatchTime?
    var stepTimings = [Double]()
    
    @objc
    func parseData() {
        if let data = self.motion.accelerometerData {
            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            
            let sum = x + y + z
            let absSum = x*x + y*y + z*z
            let value = absSum.squareRoot()
            seq.append(value)
            
            let total = seq.reduce(0, +)
            var avg = 0.0

            if (total > 0) {
                avg = total / Double(seq.count)
            }
            if (seq.count > 100) {
                seq.removeFirst()
            }
            
            let current = abs(Double(value) - Double(avg))
            
            let sameDirection = ((sum < 0) == (dir < 0))
            if (sameDirection && current > threshold && waiting == false) {
                self.view.backgroundColor = UIColor.red
                waiting = true
                dir = sum
                
                steps = steps + 1
                stepsLabel.text = String(steps)
                
                // play sound
                AudioServicesPlayAlertSound(SystemSoundID(1057))
                
                if let startStep = startStep {
                    if (steps > 0) {
                        let end = DispatchTime.now()
                        let diff = Double(end.uptimeNanoseconds - startStep.uptimeNanoseconds)
                        stepTimings.append(diff)
                    }
                }
                
                if (stepTimings.count > avgTimingSteps) {
                    stepTimings.removeFirst()
                }
                
                // update the bpm
                let totalTimings = stepTimings.reduce(0, +)
                var avgTiming = 0.0
                if (stepTimings.count > 0) {
                    avgTiming = totalTimings / Double(stepTimings.count)
                }
                
                if (avgTiming > 0) {
                    let timing = avgTiming * 0.7 / 1000000000
                    waitInterval = min(maxWaitInterval, timing)
                }
                
                // now extrapolate that number to 60s
                let bpm = floor(60.0 / avgTiming * pow(10, 9))
                bpmLabel.text = String(bpm)
                
//                if (bpm > 110) {
//                    avgTimingSteps = 10
//                } else if (bpm > 70) {
//                    avgTimingSteps = 7
//                } else {
//                    avgTimingSteps = 5
//                }
                
                startStep = DispatchTime.now()
                
                resetStepTimer = Timer.scheduledTimer(
                    timeInterval: waitInterval,
                    target: self,
                    selector: #selector(endStep),
                    userInfo: nil,
                    repeats: false
                )
                
                self.adaptThreshold()
            }
        }
    }
    
    @objc
    func endStep() {
        waiting = false
        self.view.backgroundColor = UIColor.white
    }
    
    func setupChart() {
        chartView.delegate = self
    }
    
    func adaptThreshold() {
        // adapt the threshold based on the maximums of the last few steps
        guard let maxStep = seq.suffix(stepsForThresholdCalc).max() else {
            return
        }
        threshold = min(
            maxThreshold,
            max(
                minThreshold,
                maxStep * (1 - autoThresholdPercent)
            )
        )
        print("threshold", threshold)
    }
    
    func startAccelerometers() {
        // Make sure the accelerometer hardware is available.
        if self.motion.isAccelerometerAvailable {
            self.motion.accelerometerUpdateInterval = 1.0 / freq
            self.motion.startAccelerometerUpdates()
            
            self.accelTimer = Timer.scheduledTimer(
                timeInterval: 1.0/freq,
                target: self,
                selector: #selector(parseData),
                userInfo: nil,
                repeats: true
            )
        }
    }
}

