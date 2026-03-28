import SwiftUI

/// Apple-style sound picker for alarm tones
struct AlarmSoundPickerView: View {
    @Binding var selectedSoundId: String
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            List {
                ForEach(AlarmSound.allCases) { sound in
                    Button {
                        selectedSoundId = sound.rawValue
                        sound.playPreview()
                    } label: {
                        HStack {
                            Text(sound.displayName)
                                .foregroundStyle(Theme.textDark)
                            Spacer()
                            if selectedSoundId == sound.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.primary)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Sound")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

