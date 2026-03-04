import SwiftUI

struct KeyBadge: View {
    let key: String

    var body: some View {
        Text(KeyMaps.glyph(for: key) ?? key)
            .font(.system(.body, design: .rounded))
            .multilineTextAlignment(.center)
            .fontWeight(.bold)
            .padding(.vertical, 4)
            .frame(width: 24)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 5.0, style: .continuous))
    }
}