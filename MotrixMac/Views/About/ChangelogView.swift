import SwiftUI

struct ChangelogView: View {
    let changelogs: [ChangelogItem]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(changelogs) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("v\(item.version)")
                                .font(.title3.bold())
                            
                            Text(item.date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(item.changes, id: \.self) { change in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text(change)
                                }
                                .font(.body)
                            }
                        }
                        .padding(.leading, 4)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Changelog")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
