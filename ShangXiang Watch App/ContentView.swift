//
//  ContentView.swift
//  ShangXiang Watch App
//
//  Created by mac mini on 2025/1/10.
//

import SwiftUI
import CoreMotion

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    @State private var isIncenseBurning = false
    @State private var remainingTime = 10
    @State private var timer: Timer?
    @State private var motionStatus = "准备上香"
    
    var body: some View {
        VStack {
            ZStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isIncenseBurning ? .orange : .gray)
                    .scaleEffect(isIncenseBurning ? 1.1 : 1)
                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: isIncenseBurning)
            }
            .padding(.top, 20)
            
            
            Text("\(formatTime(remainingTime))")
                .font(.system(.title2))
                .padding(.top, 8)
            
            Text(motionStatus)
                .foregroundColor(isIncenseBurning ? .orange : .gray)
                .font(.body)
                .padding(.top, 8)
            
            Image(systemName: "watch.analog")
                .font(.system(size: 60))
                .rotationEffect(.degrees(motionManager.currentRotation))
                .animation(.easeInOut, value: motionManager.currentRotation)
                .padding(.top, 8)
        }
        .onAppear {
            motionManager.startMotionUpdates { success in
                if success {
                    motionStatus = "请做上香动作"
                } else {
                    motionStatus = "无法检测动作"
                }
            }
        }
        .onDisappear {
            motionManager.stopMotionUpdates()
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secondsLeft = seconds % 60
        
        return String(format: "%02d:%02d", minutes, secondsLeft)
    }
    
    private func startBurning() {
        isIncenseBurning = true
        remainingTime = 60
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                stopBurning()
            }
        }
    }
    
    private func stopBurning() {
        isIncenseBurning = false
        timer?.invalidate()
        timer = nil
    }
    
}

class MotionManager: ObservableObject {
    private var motionManager = CMMotionManager()
    @Published var currentRotation: Double = 0
    @Published var isIncenseMotionDetected = false
    
    private var lastPitch: Double = 0
    private var motionStartTime: Date?
    
    func startMotionUpdates(completion: @escaping (Bool) -> Void) {
        guard motionManager.isDeviceMotionAvailable else {
            completion(false)
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else {
                completion(false)
                return
            }
            
            self?.processMotion(motion)
            
        }
        
        completion(true)
    }
    
    private func processMotion(_ motion: CMDeviceMotion) {
        let pitch = motion.attitude.pitch * 180 / .pi
        currentRotation = pitch
        
        if abs(pitch - lastPitch) > 5 {
            if motionStartTime == nil && pitch < -30 {
                motionStartTime = Date()
            } else if let startTime = motionStartTime,
                      pitch > 30,
                      Date().timeIntervalSince(startTime) < 2.0 {
                isIncenseMotionDetected = true
                motionStartTime = nil
            }
        }
        lastPitch = pitch
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

#Preview {
    ContentView()
}
