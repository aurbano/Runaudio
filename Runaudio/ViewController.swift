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
    let autoThresholdPercent = 0.2 // how much to remove from the max to get the new threshold
    let maxWaitInterval = 0.6 // maximum amount of time between allowing another step to be measured
    let avgTimingSteps = 5 // How many steps to take into account for timing
    let maxStepForceMeasures = 200 // Number of measurements to store in memory for the baseline calc
    let peakMemory = 50 // how many previous measurements to use to find the new min threshold
    let maxPeak = -1.5 // minimum threshold
    
    // Vars
    let motion = CMMotionManager()
    var accelTimer: Timer?
    var resetStepTimer: Timer?
    var waiting: Bool = false
    var seq = [Double]()
    var steps = 0
    var startStep: DispatchTime?
    var stepTimings = [Double]()
    var chartIndex = 0
    
    // The following are automatically adjusted
    var baseline = -1.0
    var minPeak = -10.0
    var threshold = -1.5
    var waitInterval = 0.3
    
    
    @objc
    func parseData() {
        if let data = self.motion.accelerometerData {
            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            
            let value = x + y + z
            
            if (value.isNaN || value.isInfinite) {
                return
            }
            
            let total = seq.reduce(0, +)
            if (!total.isNaN && seq.count > 0) {
                baseline = total / Double(seq.count)
            }
            
            if (seq.count > maxStepForceMeasures) {
                seq.removeFirst()
            }
            
            let current = Double(value) - baseline
            
            // find minimums to adjust the threshold
            let newMin = seq.suffix(peakMemory).min()
            if (newMin != nil) {
                if (newMin! - baseline < minPeak) {
                    print("new min", newMin! - baseline);
                }
                minPeak = min(maxPeak, newMin! - baseline)
            }
            
            self.threshold = minPeak * (1 - autoThresholdPercent)
            
            seq.append(Double(value))
            self.addDataPoint(y: current)
            
            if (current < threshold && waiting == false) {
                self.view.backgroundColor = UIColor.red
                waiting = true
                
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
                    let timing = avgTiming * 0.3 / 1000000000
                    waitInterval = min(maxWaitInterval, timing)
                }
                
                // now extrapolate that number to 60s
                let bpm = floor(60.0 / avgTiming * pow(10, 9))
                bpmLabel.text = String(bpm)
                
                startStep = DispatchTime.now()
                
                resetStepTimer = Timer.scheduledTimer(
                    timeInterval: waitInterval,
                    target: self,
                    selector: #selector(endStep),
                    userInfo: nil,
                    repeats: false
                )
            }
        }
    }
    
    @objc
    func endStep() {
        waiting = false
        self.view.backgroundColor = UIColor.white
    }
    
    func setupChart() {
        self.chartView.delegate = self
        
        let combined: LineChartDataSet = LineChartDataSet(entries: [ChartDataEntry](), label: "combined")
        
        combined.drawCirclesEnabled = false
        combined.setColor(UIColor.black)
        combined.drawValuesEnabled = false
        combined.lineWidth = 1
        
        self.chartView.pinchZoomEnabled = false
        self.chartView.doubleTapToZoomEnabled = false
        
        self.chartView.data = LineChartData(dataSets: [combined])
        
        let leftAxis = self.chartView.leftAxis
        leftAxis.removeAllLimitLines()
        leftAxis.gridLineDashLengths = [1, 1]
        leftAxis.drawLimitLinesBehindDataEnabled = true
    }
    
    func addDataPoint(y: Double) {
        let x = Double(chartIndex)
        chartIndex = chartIndex + 1
        self.chartView.data?.addEntry(ChartDataEntry(x: x, y: y), dataSetIndex: 0)
        self.chartView.notifyDataSetChanged()
        self.chartView.moveViewToX(x)
        
        let maxX = min(maxStepForceMeasures, seq.count)
        self.chartView.setVisibleXRange(minXRange: Double(1), maxXRange: Double(maxX))
        
        let thresholdLimit = ChartLimitLine(limit: minPeak, label: "Threshold")
        thresholdLimit.lineWidth = 2
        thresholdLimit.labelPosition = .topRight
        thresholdLimit.valueFont = .systemFont(ofSize: 10)
        
        let leftAxis = chartView.leftAxis
        leftAxis.removeAllLimitLines()
        leftAxis.addLimitLine(thresholdLimit)
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

