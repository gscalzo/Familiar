import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Familiar")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 0.1.0")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("A macOS desktop pet")
                .multilineTextAlignment(.center)
            Text("inspired by eSheep (1995)")
                .multilineTextAlignment(.center)

            Text("By Giordano Scalzo")
                .font(.callout)

            Divider()

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
                .padding(.top, 2)
        }
        .padding(30)
        .fixedSize()
    }
}
