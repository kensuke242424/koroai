import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("koroai")
                .font(.largeTitle.bold())
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
