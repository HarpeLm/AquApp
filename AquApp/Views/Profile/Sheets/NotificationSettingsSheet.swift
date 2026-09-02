import SwiftUI
import UserNotifications

// MARK: - NotificationSettingsSheet

struct NotificationSettingsSheet: View {
    @Binding var notificationsOn: Bool
    @Binding var isPresented: Bool

    @AppStorage("notifStartHour")    private var startHour:    Int = 8
    @AppStorage("notifEndHour")      private var endHour:      Int = 22
    @AppStorage("notifIntervalHour") private var intervalHour: Int = 2

    @State private var localOn:       Bool = false
    @State private var localStart:    Int  = 8
    @State private var localEnd:      Int  = 22
    @State private var localInterval: Int  = 2
    @State private var showPermissionAlert = false

    let intervals: [Int] = [1, 2, 3, 4, 6]

    var previewTimes: [String] {
        var times: [String] = []
        var hour = localStart
        while hour <= localEnd {
            times.append(String(format: "%02dh00", hour))
            hour += localInterval
        }
        return times
    }

    var body: some View {
        VStack(spacing: 0) {

            RoundedRectangle(cornerRadius: 3)
                .fill(Color(UIColor.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            HStack {
                HStack(spacing: 8) {
                    Text(String(localized: "notif.settings.title"))
                        .font(.system(size: 22, weight: .bold))
                    Image(systemName: "bell.fill")
                        .accessibilityHidden(true)
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }
                Spacer()
                Button { isPresented = false } label: {
                    ZStack {
                        Circle().fill(Color(UIColor.systemGray5)).frame(width: 32, height: 32)
                        Image(systemName: "xmark")
                            .accessibilityHidden(true)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityLabel(String(localized: "goal.editor.close"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 14) {

                    // Toggle principal
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "notif.settings.enable"))
                                .font(.system(size: 15, weight: .semibold))
                            Text(String(localized: "notif.settings.enable_sub"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $localOn)
                            .tint(Color(hex: "4DA8F5"))
                            .accessibilityLabel(String(localized: "notif.settings.enable"))
                            .accessibilityHint(String(localized: "notif.settings.enable_sub"))
                    }
                    .padding(16)
                    .background(Color("AppCardBackground"))
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)

                    if localOn {

                        // Plage horaire
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "notif.settings.time_range"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)

                            HStack(spacing: 12) {
                                VStack(spacing: 6) {
                                    Text(String(localized: "notif.settings.start"))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    HourPicker(hour: $localStart, range: 0...23, color: Color(hex: "4DA8F5"))
                                }
                                .frame(maxWidth: .infinity)

                                Image(systemName: "arrow.right")
                                    .accessibilityHidden(true)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)

                                VStack(spacing: 6) {
                                    Text(String(localized: "notif.settings.end"))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    HourPicker(hour: $localEnd, range: 0...23, color: .orange)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(16)
                            .background(Color("AppCardBackground"))
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                        }

                        // Fréquence
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "notif.settings.frequency"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)

                            VStack(spacing: 10) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .accessibilityHidden(true)
                                        .foregroundColor(Color(hex: "4DA8F5"))
                                        .frame(width: 24)
                                    Text(String(localized: "notif.settings.every"))
                                        .font(.system(size: 15))
                                    Spacer()
                                    Text(localInterval == 1
                                         ? String(localized: "notif.settings.one_hour")
                                         : String(format: String(localized: "notif.settings.n_hours"), localInterval))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: "4DA8F5"))
                                }

                                HStack(spacing: 8) {
                                    ForEach(intervals, id: \.self) { value in
                                        Button {
                                            withAnimation(.spring()) { localInterval = value }
                                        } label: {
                                            Text(String(format: String(localized: "notif.hours_format"), value))
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(localInterval == value ? .white : Color(hex: "4DA8F5"))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(localInterval == value ? Color(hex: "4DA8F5") : Color(hex: "EEF4FF"))
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color("AppCardBackground"))
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                        }

                        // Aperçu des horaires
                        if !previewTimes.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(String(localized: "notif.settings.preview"))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: String(localized: "notif.settings.count"), previewTimes.count))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "4DA8F5"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: "EEF4FF"))
                                        .cornerRadius(8)
                                }
                                .padding(.leading, 4)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(previewTimes, id: \.self) { time in
                                            HStack(spacing: 4) {
                                                Image(systemName: "bell.fill")
                                                    .accessibilityHidden(true)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.orange)
                                                Text(time)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.primary)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color("AppCardBackground"))
                                            .cornerRadius(8)
                                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }

                    // Bouton enregistrer
                    Button { saveAndSchedule() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .accessibilityHidden(true)
                                .font(.system(size: 18))
                            Text(String(localized: "notif.settings.save"))
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(LinearGradient(
                            colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .cornerRadius(16)
                    }
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color("AppBackground"))
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            localOn       = notificationsOn
            localStart    = startHour
            localEnd      = endHour
            localInterval = intervalHour
        }
        .alert(String(localized: "notif.permission.denied_title"), isPresented: $showPermissionAlert) {
            Button(String(localized: "notif.permission.open_settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(String(localized: "notif.permission.cancel"), role: .cancel) {
                localOn = false
            }
        } message: {
            Text(String(localized: "notif.permission.denied_message"))
        }
    }

    private func saveAndSchedule() {
        startHour       = localStart
        endHour         = localEnd
        intervalHour    = localInterval
        notificationsOn = localOn

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        guard localOn else { isPresented = false; return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                guard granted else {
                    showPermissionAlert = true
                    notificationsOn = false
                    return
                }
                scheduleNotifications()
                isPresented = false
            }
        }
    }

    private func scheduleNotifications() {
        let messages = L10n.notifReminderMessages
        var hour = localStart
        var index = 0
        while hour <= localEnd {
            var components    = DateComponents()
            components.hour   = hour
            components.minute = 0
            let content       = UNMutableNotificationContent()
            content.title     = String(localized: "notif.reminder_title")
            content.body      = messages[index % messages.count]
            content.sound     = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "aquapp_reminder_\(hour)",
                content: content, trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
            hour  += localInterval
            index += 1
        }
    }
}

// MARK: - HourPicker

private struct HourPicker: View {
    @Binding var hour: Int
    let range: ClosedRange<Int>
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if hour > range.lowerBound { hour -= 1 }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .accessibilityHidden(true)
                    .font(.system(size: 24))
                    .foregroundColor(hour > range.lowerBound ? color : Color(UIColor.systemGray4))
            }
            .accessibilityLabel(String(localized: "notif.hour_picker.decrease"))
            .accessibilityValue(String(format: "%02dh00", hour))
            .accessibilityHint(String(localized: "notif.hour_picker.decrease_hint"))
            .disabled(hour <= range.lowerBound)

            Text(String(format: "%02dh00", hour))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: 60)
                .accessibilityHidden(true)

            Button {
                if hour < range.upperBound { hour += 1 }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .accessibilityHidden(true)
                    .font(.system(size: 24))
                    .foregroundColor(hour < range.upperBound ? color : Color(UIColor.systemGray4))
            }
            .accessibilityLabel(String(localized: "notif.hour_picker.increase"))
            .accessibilityValue(String(format: "%02dh00", hour))
            .accessibilityHint(String(localized: "notif.hour_picker.increase_hint"))
            .disabled(hour >= range.upperBound)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    NotificationSettingsSheet(notificationsOn: .constant(true), isPresented: .constant(true))
}
