import SwiftUI
import CoreMotion
import AVKit
import AVFoundation

// 定义协议，用于通知 ContentView 检测到上香动作
protocol MotionManagerDelegate {
    func didDetectIncenseMotion()
}

struct ContentView: View, MotionManagerDelegate {
    @StateObject private var motionManager = MotionManager()
    @State private var isIncenseBurning = false
    @State private var remainingTime = 10
    @State private var timer: Timer?
    @State private var motionStatus = "准备上香"
    @State private var isPlayingVideo = false
    @State private var videoPlayer: AVPlayer? = {
        if let url = Bundle.main.url(forResource: "incense", withExtension: "mp4") {
            return AVPlayer(url: url)
        } else {
            print("未找到视频文件")
            return nil
        }
    } ()
    

    var body: some View {
        VStack {
            if isPlayingVideo{
                if let player = videoPlayer {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                        .scaleEffect(x: 2, y:1.5, anchor: .center) // 放大视频
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: WKInterfaceDevice.current().screenBounds.width,
                            height: WKInterfaceDevice.current().screenBounds.height * 1.2)
                            .position(
                                x: WKInterfaceDevice.current().screenBounds.width/2,
                                y: WKInterfaceDevice.current().screenBounds.height/2)
                        .ignoresSafeArea()
                        .clipped() // 裁剪超出部分
                        .onAppear {
                        player.seek(to: .zero)
                            player.play()
                            // 添加视频播放结束的观察
                            NotificationCenter.default.addObserver(
                                forName: .AVPlayerItemDidPlayToEndTime,
                                object: player.currentItem,
                                queue: .main
                            ) { [weak player] _ in
                                player?.pause()
                                player?.seek(to: .zero)
                                // 使用主线程更新 UI 状态
                                DispatchQueue.main.async {
                                    isPlayingVideo = false
                                    isIncenseBurning = false
                                    // 重置 MotionManager 的检测状态
                                    motionManager.resetMotionDetection()
                                }
                            }
                        }
                        .onDisappear {
                            player.pause()
                            player.seek(to: .zero)
                            NotificationCenter.default.removeObserver(self)
                        }
                        .overlay(Color.clear)
                        .allowsHitTesting(false)
                } else {
                    Text("视频播放器未初始化成功")
                }
            } else {
                ZStack {
                    if let headerImage = UIImage(named: "header.png") ?? UIImage(contentsOfFile: Bundle.main.path(forResource: "header", ofType: "png") ?? "") {
                        Image(uiImage: headerImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: WKInterfaceDevice.current().screenBounds.width * 1.0)
                    }
                    
                    // VStack {                        
                    //     Button(action: {
                    //         isIncenseBurning = true
                    //         remainingTime = 60
                    //         isPlayingVideo = true
                    //     }) {
                    //         Text("测试视频播放")
                    //             .foregroundColor(.blue)
                    //             .padding()
                    //             .background(RoundedRectangle(cornerRadius: 8)
                    //                 .stroke(Color.blue, lineWidth: 1))
                    //     }
                    //     .padding(.top, 16)
                    // }
                }
            }
        }
       .onAppear {
            motionManager.delegate = self
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
       .ignoresSafeArea(.all)
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secondsLeft = seconds % 60

        return String(format: "%02d:%02d", minutes, secondsLeft)
    }

    private func startBurning() {
        isIncenseBurning = true
        remainingTime = 60
        isPlayingVideo = true
    }

    private func stopBurning() {
        isIncenseBurning = false
        isPlayingVideo = false
    }

    func didDetectIncenseMotion() {
        DispatchQueue.main.async {
            startBurning()
        }
    }
}

class MotionManager: ObservableObject {
    private var motionManager = CMMotionManager()
    @Published var currentRotation: Double = 0
    @Published var isIncenseMotionDetected = false

    private var lastPitch: Double = 0
    private var motionStartTime: Date?
    var delegate: MotionManagerDelegate?

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
        // 如果正在播放视频，不处理动作
        if isIncenseMotionDetected {
            return
        }

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
                delegate?.didDetectIncenseMotion()
            }
        }
        lastPitch = pitch
    }

    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    func resetMotionDetection() {
        isIncenseMotionDetected = false
        motionStartTime = nil
        lastPitch = 0
    }
}

#Preview {
    ContentView()
}
