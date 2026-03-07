import SwiftUI

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    var trigger: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isPulsing)
            .onChange(of: trigger) { _, _ in
                isPulsing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPulsing = false
                }
            }
    }
}

extension View {
    func pulseOnChange(_ trigger: Bool) -> some View {
        modifier(PulseEffect(trigger: trigger))
    }
}
