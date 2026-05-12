import SwiftUI

// MARK: - Declutter your mind — offline emotional grounding (breathing, grounding prompts, affirmations)

struct DeclutterView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                breathingSection
                groundingSection
                affirmationsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .navigationTitle("Declutter your mind")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Section 1: Guided Breathing

    private var breathingSection: some View {
        BreathingSectionView()
    }

    // MARK: - Section 2: Grounding Prompts

    private var groundingSection: some View {
        GroundingSectionView()
    }

    // MARK: - Section 3: Gentle Affirmations

    private var affirmationsSection: some View {
        AffirmationsSectionView()
    }
}

// MARK: - Breathing (4–4–6, 1/2/3 min, circle + timer + Start/Pause/End)

private struct BreathingSectionView: View {
    private static let phaseDurations: [(name: String, seconds: Int)] = [
        ("Inhale", 4),
        ("Hold", 4),
        ("Exhale", 6)
    ]
    private static let durationOptions = [1, 2, 3] // minutes

    @State private var selectedDurationMinutes: Int = 2
    @State private var isActive = false
    @State private var isPaused = false
    @State private var phaseIndex = 0
    @State private var secondsLeftInPhase = 4
    @State private var totalSecondsRemaining = 2 * 60
    @State private var circleScale: CGFloat = 0.6
    @State private var timer: Timer?
    @State private var phaseTimer: Timer?

    private var phaseName: String { Self.phaseDurations[phaseIndex].name }
    private var formattedTime: String {
        let m = totalSecondsRemaining / 60
        let s = totalSecondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Breathe with me")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            if !isActive {
                Text("Inhale 4s · Hold 4s · Exhale 6s")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach(Self.durationOptions, id: \.self) { minutes in
                        Button {
                            selectedDurationMinutes = minutes
                        } label: {
                            Text("\(minutes) min")
                                .font(.subheadline.weight(.medium))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selectedDurationMinutes == minutes ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if isActive {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.25))
                        .scaleEffect(circleScale)
                        .animation(.easeInOut(duration: breathAnimationDuration), value: circleScale)
                        .frame(width: 160, height: 160)

                    VStack(spacing: 8) {
                        Text(phaseName)
                            .font(.title3.weight(.semibold))
                        Text(formattedTime)
                            .font(.title2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            HStack(spacing: 12) {
                if !isActive {
                    Button {
                        startBreathing()
                    } label: {
                        Text("Start")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                } else {
                    Button {
                        isPaused.toggle()
                        if isPaused {
                            timer?.invalidate()
                            phaseTimer?.invalidate()
                        } else {
                            startTimers()
                        }
                    } label: {
                        Text(isPaused ? "Resume" : "Pause")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)

                    Button {
                        endEarly()
                    } label: {
                        Text("End early")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .onDisappear {
            timer?.invalidate()
            phaseTimer?.invalidate()
        }
    }

    private var breathAnimationDuration: Double {
        let (_, sec) = Self.phaseDurations[phaseIndex]
        return Double(sec)
    }

    private func startBreathing() {
        totalSecondsRemaining = selectedDurationMinutes * 60
        phaseIndex = 0
        secondsLeftInPhase = Self.phaseDurations[0].seconds
        circleScale = 0.6
        isActive = true
        isPaused = false
        updateCircleScaleForPhase()
        startTimers()
    }

    private func startTimers() {
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            secondsLeftInPhase -= 1
            if secondsLeftInPhase <= 0 {
                phaseIndex = (phaseIndex + 1) % Self.phaseDurations.count
                secondsLeftInPhase = Self.phaseDurations[phaseIndex].seconds
                updateCircleScaleForPhase()
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            totalSecondsRemaining -= 1
            if totalSecondsRemaining <= 0 {
                endEarly()
            }
        }
        RunLoop.main.add(phaseTimer!, forMode: .common)
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func updateCircleScaleForPhase() {
        switch phaseName {
        case "Inhale": circleScale = 1.0
        case "Hold": break
        case "Exhale": circleScale = 0.6
        default: break
        }
    }

    private func endEarly() {
        timer?.invalidate()
        phaseTimer?.invalidate()
        timer = nil
        phaseTimer = nil
        isActive = false
        isPaused = false
        circleScale = 0.6
    }
}

// MARK: - Grounding prompts (one at a time, Next)

private struct GroundingSectionView: View {
    private static let prompts = [
        "Name 5 things you can see",
        "Place your feet flat on the floor and feel the ground",
        "Relax your shoulders and unclench your jaw",
        "Notice your breathing without changing it"
    ]

    @State private var currentIndex = 0

    private var currentPrompt: String { Self.prompts[currentIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ground yourself")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text(currentPrompt)
                .font(.body)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)

            Button {
                currentIndex = (currentIndex + 1) % Self.prompts.count
            } label: {
                Text("Next prompt")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Affirmations (random one, refresh on appear or button)

private struct AffirmationsSectionView: View {
    private static let lines = [
        "You're doing your best.",
        "It's okay to pause.",
        "Caregiving is hard, and you're not weak.",
        "This moment will pass."
    ]

    @State private var currentLine: String = AffirmationsSectionView.lines[0]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A gentle reminder")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text(currentLine)
                .font(.title3)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)

            Button {
                refreshAffirmation()
            } label: {
                Label("Another reminder", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderless)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .onAppear {
            refreshAffirmation()
        }
    }

    private func refreshAffirmation() {
        currentLine = Self.lines.randomElement() ?? Self.lines[0]
    }
}
