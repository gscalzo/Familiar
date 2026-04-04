import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Welcome to Familiar")
                .font(.title)

            Text(
                "For the best experience, Familiar needs Screen Recording permission "
                    + "to detect windows. Your pet will walk on other app windows!"
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: 400)

            HStack(spacing: 16) {
                Button("Continue Without") {
                    onComplete()
                }

                Button("Grant Permission") {
                    CGRequestScreenCaptureAccess()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }

            Text("You can change this later in System Settings > Privacy & Security > Screen Recording")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}
