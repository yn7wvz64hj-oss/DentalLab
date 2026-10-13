import SwiftUI

struct ToothMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        p.move(to: point(0.5, 0.22))
        p.addCurve(to: point(0.23, 0.18), control1: point(0.38, 0.14), control2: point(0.30, 0.12))
        p.addCurve(to: point(0.22, 0.49), control1: point(0.12, 0.27), control2: point(0.16, 0.39))
        p.addCurve(to: point(0.34, 0.83), control1: point(0.26, 0.57), control2: point(0.23, 0.81))
        p.addCurve(to: point(0.5, 0.57), control1: point(0.44, 0.87), control2: point(0.41, 0.57))
        p.addCurve(to: point(0.66, 0.83), control1: point(0.59, 0.57), control2: point(0.56, 0.87))
        p.addCurve(to: point(0.78, 0.49), control1: point(0.77, 0.81), control2: point(0.74, 0.57))
        p.addCurve(to: point(0.77, 0.18), control1: point(0.84, 0.39), control2: point(0.88, 0.27))
        p.addCurve(to: point(0.5, 0.22), control1: point(0.70, 0.12), control2: point(0.62, 0.14))
        p.closeSubpath()
        return p
    }
}
struct BrandMark: View {
    var body: some View { ToothMark().fill(LinearGradient(colors: [Color(red: 0.76, green: 0.98, blue: 1), Palette.cyan, Palette.teal], startPoint: .topLeading, endPoint: .bottomTrailing)) }
}
