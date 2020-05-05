//
//  InterfaceController.swift
//  ml-presenter WatchKit Extension
//
//  Created by Viktor Zamaruiev on 6/7/19.
//  Copyright © 2019 Viktor Zamaruiev. All rights reserved.
//

import WatchKit
import Foundation
import CoreMotion
import HealthKit
import AVFoundation

class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate {
    
    let configuration = HKWorkoutConfiguration()
    var session: HKWorkoutSession? = Optional.none
    let healthStore = HKHealthStore()
    let motionManager = CMMotionManager()
    var measurements: [[Double]] = []
    var timer: Timer? = Optional.none
    var audioRecorder: AVAudioRecorder? = Optional.none
    var experimentId: String? = Optional.none
    let experimentUrl = "http://192.168.1.186:8080/experiment"
    let measurementsUrl = "http://192.168.1.186:8080/measurements"
    let audioUploadUrl = "http://192.168.1.186:8080/upload"
    @IBOutlet weak var debugLabel: WKInterfaceLabel!
    
    @IBOutlet weak var displayLabel: WKInterfaceLabel!
    @IBOutlet weak var mainButton: WKInterfaceButton!
    @IBOutlet weak var trainingMode: WKInterfaceButton!
    
    @IBOutlet weak var stopButton: WKInterfaceButton!
    
    @IBAction func stopGathering() {
        motionManager.stopAccelerometerUpdates()
        session?.end()
        timer?.invalidate()
        measurements = []

        print("Stopping")
        if audioRecorder != nil && audioRecorder!.isRecording {
            sendAudio()
        }
        
        experimentId = Optional.none
        stopButton.setHidden(true)
        mainButton.setHidden(false)
        trainingMode.setHidden(false)
        displayLabel.setText("Stopped")
    }

    @IBAction func triggerTrainingMode() {
        stopButton.setHidden(false)
        mainButton.setHidden(true)
        trainingMode.setHidden(true)
        displayLabel.setText("Training mode")
        startExperiment()
        gatherMeasurements()
        recordAudio()
    }
    
    @IBAction func tappedButton() {
        stopButton.setHidden(false)
        mainButton.setHidden(true)
        trainingMode.setHidden(true)
        displayLabel.setText("Presentation mode")
        self.experimentId = ""
        gatherMeasurements()
    }
    
    func startExperiment() {
        print("Starting new experiment")
        measurements = []
        experimentId = Optional.none

        var request = URLRequest(url: URL(string: experimentUrl)!)
        request.httpMethod = "POST"
        let task = URLSession.shared.dataTask(with: request, completionHandler: {
            data,response,_ in
            self.experimentId = String(data: data!, encoding: .utf8)
            print(self.experimentId!)
        })
        task.resume()

    }
    
    func gatherMeasurements() {
       configuration.activityType = .other
       do {
           session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
           session!.startActivity(with: Date())
       } catch {
           dismiss()
           return
       }

       motionManager.accelerometerUpdateInterval = 1.0 / 100.0
       motionManager.startAccelerometerUpdates(to: OperationQueue.main) {
           (data, error) in
           self.displayLabel.setText("Gathering data: " + String(self.measurements.count))
           if data != nil {
               self.measurements.append([
                   data!.acceleration.x,
                   data!.acceleration.y,
                   data!.acceleration.z,
                   data!.timestamp
               ])
           }
       }
       self.timer = Timer(fire: Date(), interval: (1), repeats: true, block: {
           (timer) in
           self.sendMeasurements()
       })
       RunLoop.current.add(self.timer!, forMode:RunLoop.Mode.common)
    }
    
    func sendMeasurements() {
        if self.experimentId == nil {
            return
        }
        var request = URLRequest(url: URL(string: measurementsUrl + "?experimentId=" + self.experimentId!)!)
        request.httpMethod = "POST"
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: self.measurements, options: [])
            self.measurements = []
        } catch {
            print("Error: cannot serialize measeurements to JSON")
            return
        }
        let task = URLSession.shared.dataTask(with: request) {
            (_, _, error) in
            guard error == nil else {
                print("Error calling POST on /measurements)")
                print(error!)
                return
            }
        }
        task.resume()
    }
    
    func recordAudio() {
        let recordingName = "audio.m4a"
        let dirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let pathArray = [dirPath, recordingName]
        guard let filePath = URL(string: pathArray.joined(separator: "/")) else { return }

        let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey:12000,
                        AVNumberOfChannelsKey:1,
                        AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
        ]

        //start recording
        do {
            print("Recording to:")
            print(filePath)
            let session = AVAudioSession.sharedInstance()
            print(session.recordPermission.rawValue)
            try session.setCategory(AVAudioSession.Category.record)
            try session.setActive(true)
            session.requestRecordPermission({ response in
                print("Requested permissions: " + response.description)
            })
            self.audioRecorder = try AVAudioRecorder(url: filePath, settings: settings)
            debugLabel.setText("Recording: " + self.audioRecorder!.record().description)
        } catch {
            debugLabel.setText("Audio recording failed")
        }
    }
    
    func sendAudio() {
        print("Sending audio")
        print(audioRecorder!.url)
        audioRecorder?.stop()
        var request = URLRequest(url: URL(string: audioUploadUrl + "?experimentId=" + self.experimentId!)!)
        request.httpMethod = "POST"
        let audio = NSData.init(contentsOfFile: audioRecorder!.url.absoluteString)
        request.httpBody = audio!.base64EncodedData()
        let task = URLSession.shared.dataTask(with: request, completionHandler: {
            _,_,_ in
            print("Audio sent")
            self.audioRecorder?.deleteRecording()
        })
        task.resume()
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        if !motionManager.isAccelerometerAvailable {
            debugLabel.setText("Accelerometer not available")
        }
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        
    }
}
