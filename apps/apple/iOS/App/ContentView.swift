import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TimelineView()
    }
}

#Preview {
    ContentView()
        .modelContainer(ModelContainer.blackbox)
}
