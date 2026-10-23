import SwiftUI

/// Lightweight playback animation; does not record audio or request the microphone.
struct AudioVisualizer: View {
    @ObservedObject private var playback = PlaybackManager.shared
    @AppStorage("wd.media.visualizer") private var style = "wave"
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !playback.isPlaying)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let strength = playback.isPlaying ? 1.0 : 0.15
                if style == "dots" {
                    for index in 0..<24 {
                        let x = CGFloat(index + 1) * size.width / 25
                        let y = size.height / 2 + sin(time * 2 + Double(index) * 0.45) * size.height * 0.25 * strength
                        context.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(.cyan))
                    }
                } else {
                    var path = Path()
                    for x in stride(from: 0.0, through: size.width, by: 3.0) {
                        let y = size.height / 2 + sin(x / 28 + time * 3) * sin(x / max(1, size.width) * .pi) * size.height * 0.3 * strength
                        if x == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .linearGradient(Gradient(colors: style == "neon" ? [.purple, .cyan, .pink] : [.cyan, .blue]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), lineWidth: style == "neon" ? 4 : 2)
                }
            }
        }.background(.black).accessibilityLabel(tr("مؤثر بصري للتشغيل", "Playback visual effect"))
    }
}
