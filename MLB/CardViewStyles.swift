import SwiftUI

// 用來製作卡片發光漸層的輔助結構
struct CardBackground: View {
    let isPitcher: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(LinearGradient(
                colors: [isPitcher ? Color.blue.opacity(0.15) : Color.red.opacity(0.15), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isPitcher ? Color.blue.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
            )
    }
}
