import SwiftUI
import CoreLocation

// MARK: - Location required (after login when user has no coordinates)

struct LocationCaptureView: View {
    var onComplete: () -> Void
    /// When set, show a Cancel button (e.g. for "Update Location" sheet).
    var onSkip: (() -> Void)? = nil

    @StateObject private var locationManager = LocationManager.shared
    @State private var isRequesting = true
    @State private var showCitySheet = false
    @State private var cityInput = ""
    @State private var cityError: String?
    @State private var isSavingCity = false

    var body: some View {
        ZStack {
            AppTheme.screenGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                if onSkip != nil {
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            onSkip?()
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding()
                    }
                }
                Text(onSkip == nil ? "Set your location" : "Update location")
                    .font(AppTextStyle.sectionTitle)
                    .foregroundStyle(.white)
                Text("CareCircle shows requests and posts within 50km. Your location is stored once and not shared beyond distance filtering.")
                    .font(AppTextStyle.secondary)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if isRequesting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.2)
                        .tint(.white)
                        .padding(.top, 24)
                } else {
                    Button("Use my location") {
                        Task { await requestAndSave() }
                    }
                    .buttonStyle(PrimaryGreenButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.top, 16)

                    Button("Enter city instead") {
                        showCitySheet = true
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 8)
                }
            }
        }
        .task {
            if onSkip == nil {
                await requestAndSave()
            } else {
                isRequesting = false
            }
        }
        .sheet(isPresented: $showCitySheet) {
            EnterCitySheet(
                city: $cityInput,
                error: $cityError,
                isSaving: $isSavingCity,
                onSave: {
                    Task { await saveCityAndComplete() }
                },
                onCancel: {
                    showCitySheet = false
                }
            )
        }
    }

    private func requestAndSave() async {
        isRequesting = true
        let coord = await locationManager.requestLocationAndGetCoordinates()
        isRequesting = false
        if let coord {
            do {
                try await UserService.shared.updateUserLocation(latitude: coord.latitude, longitude: coord.longitude)
                onComplete()
            } catch {
                cityError = error.localizedDescription
                showCitySheet = true
            }
        } else {
            showCitySheet = true
        }
    }

    private func saveCityAndComplete() async {
        let trimmed = cityInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cityError = "Please enter a city name."
            return
        }
        isSavingCity = true
        cityError = nil
        do {
            let coord = try await locationManager.geocode(city: trimmed)
            try await UserService.shared.updateUserLocation(latitude: coord.latitude, longitude: coord.longitude)
            showCitySheet = false
            onComplete()
        } catch {
            cityError = error.localizedDescription
        }
        isSavingCity = false
    }
}

// MARK: - Enter city (when permission denied)

struct EnterCitySheet: View {
    @Binding var city: String
    @Binding var error: String?
    @Binding var isSaving: Bool
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("City name", text: $city)
                        .textContentType(.addressCity)
                } header: {
                    Text("Enter Your City")
                } footer: {
                    Text("We'll use this to show you requests and posts within 50km.")
                }
                if let error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button {
                        onSave()
                    } label: {
                        if isSaving {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else {
                            Text("Save Location")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    .disabled(city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .tint(AppTheme.primaryGreen)
                    Button("Cancel", role: .cancel) {
                        onCancel()
                    }
                    .foregroundStyle(AppTheme.primaryGreen)
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Enter Your City")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.primaryGreen)
        }
    }
}
