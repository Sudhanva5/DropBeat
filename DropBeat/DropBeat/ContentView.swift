import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Player Info
            HStack {
                // Album Art Placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Track Playing")
                        .font(.headline)
                    Text("DropBeat")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Search Bar Placeholder
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                Text("Search")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(width: 300, height: 400)
    }
}