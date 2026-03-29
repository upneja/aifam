import SwiftUI

struct TonePickerView: View {
    @Binding var selectedTone: TonePreset

    private let exampleMessage = "Sarah's birthday is in 4 days and you haven't planned anything yet."

    var body: some View {
        VStack(spacing: 16) {
            ForEach(TonePreset.allCases) { tone in
                toneCard(tone)
            }
        }
    }

    private func toneCard(_ tone: TonePreset) -> some View {
        let isSelected = selectedTone == tone

        return Button {
            withAnimation(.snappy) {
                selectedTone = tone
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(tone.displayName)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.primaryText)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.gold)
                            .font(.system(size: 22))
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(AppColors.secondaryText.opacity(0.3))
                            .font(.system(size: 22))
                    }
                }

                Text(tone.description)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.secondaryText)

                // Example in this tone
                Text(toneExample(tone))
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.primaryText.opacity(0.8))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppColors.gold : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(isSelected ? 0.06 : 0.02), radius: isSelected ? 8 : 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func toneExample(_ tone: TonePreset) -> String {
        switch tone {
        case .casual:
            "yo heads up — sarah's bday is in 4 days and you haven't planned anything yet. want me to find dinner spots?"
        case .standard:
            "Sarah's birthday is in 4 days. No plans yet — want me to look into restaurant options for 8 downtown?"
        case .professional:
            "Reminder: Sarah's birthday dinner is April 12th. Reservations have not been made. Shall I compile options for a party of 8?"
        }
    }
}
