import SwiftUI
import CoreMotion
import AVKit

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

    var body: some View {
        VStack {
            if isPlayingVideo {
                VideoPlayer(url: Bundle.main.url(forResource: "incense", withExtension: "mp4")!)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
        isPlayingVideo = true

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
        isPlayingVideo = false
        timer?.invalidate()
        timer = nil
    }

    func didDetectIncenseMotion() {
        startBurning()
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
}

struct VideoPlayer: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)
        player.play()
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                            object: player.currentItem, queue: .main) { _ in
            player.seek(to: CMTime.zero)
            player.play()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
}

#Preview {
    ContentView()
}
