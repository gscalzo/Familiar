import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Familiar")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 0.1.0")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("A macOS desktop pet\ninspired by eSheep (1995)")
                .multilineTextAlignment(.center)

            Text("By Giordano Scalzo")
                .font(.callout)

            Divider()
                .frame(width: 200)

            HStack(spacing: 4) {
                Text("License:")
                    .foregroundStyle(.secondary)
                Text("MIT")
            }
            .font(.callout)

            Link(
                "github.com/gscalzo/Familiar",
                destination: URL(string: "https://github.com/gscalzo/Familiar")!
            )
            .font(.callout)

            Text("fam work  ·  fam yay  ·  fam think")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 320)
    }
}
