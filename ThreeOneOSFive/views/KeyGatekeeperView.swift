import SwiftUI
import UIKit

struct KeyValidationResult {
    let isValid: Bool
    let duration: String
    let expiryText: String
    let expiryDateString: String
    let role: String
}

class KeyAuthManager: ObservableObject {
    static let shared = KeyAuthManager()

    private let keyStorageKey = "PHUCVN_SAVED_LICENSE_KEY"
    private let expiryStorageKey = "PHUCVN_SAVED_LICENSE_EXPIRY"
    private let expiryTextStorageKey = "PHUCVN_SAVED_LICENSE_EXPIRY_TEXT"
    private let serverUrlStorageKey = "PHUCVN_SAVED_SERVER_URL"

    @Published var serverUrl: String {
        didSet {
            UserDefaults.standard.set(serverUrl, forKey: serverUrlStorageKey)
        }
    }

    @Published var isAuthorized: Bool = false
    @Published var currentKey: String = ""
    @Published var expiryText: String = ""
    @Published var role: String = "VIP"
    @Published var errorMessage: String? = nil
    @Published var isVerifying: Bool = false

    var deviceHWID: String {
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            return id
        }
        return "IPHONE-3105-\(AppInfo.machineName)"
    }

    init() {
        let savedServer = UserDefaults.standard.string(forKey: "PHUCVN_SAVED_SERVER_URL")
        self.serverUrl = savedServer ?? "https://phuciosvn.com/serverkey/api.php"

        let savedKey = UserDefaults.standard.string(forKey: "PHUCVN_SAVED_LICENSE_KEY") ?? ""
        let savedExpiryText = UserDefaults.standard.string(forKey: "PHUCVN_SAVED_LICENSE_EXPIRY_TEXT") ?? ""
        let savedExpiry = UserDefaults.standard.string(forKey: "PHUCVN_SAVED_LICENSE_EXPIRY") ?? ""

        if !savedKey.isEmpty {
            self.currentKey = savedKey
            self.expiryText = savedExpiryText

            if !savedExpiry.isEmpty && savedExpiry != "permanent" {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                if let expDate = formatter.date(from: savedExpiry), expDate < Date() {
                    self.isAuthorized = false
                    self.errorMessage = "Key bản quyền đã hết hạn sử dụng. Vui lòng mua Key mới tại Shop phuciosvn.com!"
                    return
                }
            }

            self.isAuthorized = true
            verifyWithServer(key: savedKey, isSilent: true)
        }
    }

    func activate(key: String, completion: ((Bool) -> Void)? = nil) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedKey.isEmpty else {
            self.errorMessage = "Vui lòng nhập mã Key bản quyền!"
            completion?(false)
            return
        }

        // Kiểm tra định dạng cấu trúc Key bản quyền PHUCVN
        let validation = validateKeyStructure(trimmedKey)
        guard validation.isValid else {
            self.errorMessage = "Mã Key không hợp lệ! Vui lòng mua Key chính hãng tại Shop: phuciosvn.com"
            completion?(false)
            return
        }

        self.isVerifying = true
        self.errorMessage = nil

        verifyWithServer(key: trimmedKey, validationFallback: validation, isSilent: false) { [weak self] success in
            self?.isVerifying = false
            completion?(success)
        }
    }

    func unlinkKey() {
        UserDefaults.standard.removeObject(forKey: keyStorageKey)
        UserDefaults.standard.removeObject(forKey: expiryStorageKey)
        UserDefaults.standard.removeObject(forKey: expiryTextStorageKey)
        self.currentKey = ""
        self.expiryText = ""
        self.isAuthorized = false
        self.errorMessage = nil
    }

    private func verifyWithServer(
        key: String,
        validationFallback: KeyValidationResult? = nil,
        isSilent: Bool,
        completion: ((Bool) -> Void)? = nil
    ) {
        let fallbackInfo = validationFallback ?? validateKeyStructure(key)

        guard var urlComponents = URLComponents(string: serverUrl) else {
            fallbackOrError("Địa chỉ Server không hợp lệ!", fallback: fallbackInfo, isSilent: isSilent, completion: completion)
            return
        }

        var queryItems = urlComponents.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "action" }) {
            queryItems.append(URLQueryItem(name: "action", value: "verify_key"))
            urlComponents.queryItems = queryItems
        }

        guard let targetUrl = urlComponents.url else {
            fallbackOrError("Không tạo được URL kết nối!", fallback: fallbackInfo, isSilent: isSilent, completion: completion)
            return
        }

        var request = URLRequest(url: targetUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceHWID, forHTTPHeaderField: "X-Device-HWID")
        request.timeoutInterval = 6

        let body: [String: Any] = [
            "key": key,
            "hwid": deviceHWID
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                // Khi server chưa online hoặc mất kết nối mạng
                if error != nil {
                    if fallbackInfo.isValid {
                        self.saveSuccessfulLicense(
                            key: key,
                            expiry: fallbackInfo.expiryDateString,
                            expiryText: fallbackInfo.expiryText,
                            role: fallbackInfo.role
                        )
                        completion?(true)
                        return
                    }

                    if !isSilent {
                        self.handleVerificationError("Mã Key không hợp lệ hoặc máy chủ không khả dụng!", isSilent: isSilent, completion: completion)
                    }
                    return
                }

                // Kiểm tra HTTP Status
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode >= 400 {
                    if fallbackInfo.isValid {
                        self.saveSuccessfulLicense(
                            key: key,
                            expiry: fallbackInfo.expiryDateString,
                            expiryText: fallbackInfo.expiryText,
                            role: fallbackInfo.role
                        )
                        completion?(true)
                        return
                    }
                }

                guard let data = data,
                      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                    if fallbackInfo.isValid {
                        self.saveSuccessfulLicense(
                            key: key,
                            expiry: fallbackInfo.expiryDateString,
                            expiryText: fallbackInfo.expiryText,
                            role: fallbackInfo.role
                        )
                        completion?(true)
                        return
                    }
                    self.handleVerificationError("Phản hồi từ máy chủ không hợp lệ!", isSilent: isSilent, completion: completion)
                    return
                }

                let success = (json["success"] as? Bool) == true
                let valid = (json["valid"] as? Bool) == true

                if success && valid {
                    let expiry = (json["expiry"] as? String) ?? fallbackInfo.expiryDateString
                    let expiryText = (json["expiry_text"] as? String) ?? fallbackInfo.expiryText
                    let role = (json["role"] as? String) ?? fallbackInfo.role

                    self.saveSuccessfulLicense(key: key, expiry: expiry, expiryText: expiryText, role: role)
                    completion?(true)
                } else {
                    let errorMsg = (json["error"] as? String) ?? (json["message"] as? String) ?? "Mã Key không hợp lệ hoặc đã hết hạn!"
                    if isSilent {
                        self.unlinkKey()
                    } else {
                        self.handleVerificationError(errorMsg, isSilent: isSilent, completion: completion)
                    }
                }
            }
        }.resume()
    }

    private func fallbackOrError(_ msg: String, fallback: KeyValidationResult, isSilent: Bool, completion: ((Bool) -> Void)?) {
        if fallback.isValid {
            saveSuccessfulLicense(key: currentKey, expiry: fallback.expiryDateString, expiryText: fallback.expiryText, role: fallback.role)
            completion?(true)
        } else {
            handleVerificationError(msg, isSilent: isSilent, completion: completion)
        }
    }

    private func saveSuccessfulLicense(key: String, expiry: String, expiryText: String, role: String) {
        UserDefaults.standard.set(key, forKey: keyStorageKey)
        UserDefaults.standard.set(expiry, forKey: expiryStorageKey)
        UserDefaults.standard.set(expiryText, forKey: expiryTextStorageKey)

        self.currentKey = key
        self.expiryText = expiryText
        self.role = role
        self.isAuthorized = true
        self.errorMessage = nil
    }

    // Xác thực cấu trúc mã Key bản quyền chuẩn PHUCVN
    func validateKeyStructure(_ key: String) -> KeyValidationResult {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // 1. Danh sách Master Keys
        if clean == "PHUCVN-LIFE-TEST-0001" || clean == "PHUCVN-VIP-9999" {
            return KeyValidationResult(isValid: true, duration: "permanent", expiryText: "Vĩnh Viễn", expiryDateString: "permanent", role: "VIP")
        }
        if clean == "PHUCVN-30D-TEST-0001" {
            let exp = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
            return KeyValidationResult(isValid: true, duration: "30d", expiryText: "30 Ngày", expiryDateString: formatDate(exp), role: "VIP")
        }
        if clean == "PHUCVN-7D-TEST-0001" {
            let exp = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            return KeyValidationResult(isValid: true, duration: "7d", expiryText: "7 Ngày", expiryDateString: formatDate(exp), role: "VIP")
        }
        if clean == "PHUCVN-1D-TEST-0001" {
            let exp = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            return KeyValidationResult(isValid: true, duration: "1d", expiryText: "24 Giờ", expiryDateString: formatDate(exp), role: "VIP")
        }
        if clean == "PHUCVN-1H-TEST-0001" {
            let exp = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            return KeyValidationResult(isValid: true, duration: "1h", expiryText: "1 Giờ", expiryDateString: formatDate(exp), role: "VIP")
        }

        // 2. Khớp định dạng sinh key tự động: PHUCVN-(LIFE|30D|7D|1D|1H|VIP)-[A-Z0-9]{3,8}-[A-Z0-9]{3,8}
        let pattern = "^PHUCVN-(LIFE|30D|7D|1D|1H|VIP)-[A-Z0-9]{3,8}-[A-Z0-9]{3,8}$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)),
           let typeRange = Range(match.range(at: 1), in: clean) {
            let type = String(clean[typeRange])
            switch type {
            case "LIFE", "VIP":
                return KeyValidationResult(isValid: true, duration: "permanent", expiryText: "Vĩnh Viễn", expiryDateString: "permanent", role: "VIP")
            case "30D":
                let exp = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
                return KeyValidationResult(isValid: true, duration: "30d", expiryText: "30 Ngày", expiryDateString: formatDate(exp), role: "VIP")
            case "7D":
                let exp = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                return KeyValidationResult(isValid: true, duration: "7d", expiryText: "7 Ngày", expiryDateString: formatDate(exp), role: "VIP")
            case "1D":
                let exp = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                return KeyValidationResult(isValid: true, duration: "1d", expiryText: "24 Giờ", expiryDateString: formatDate(exp), role: "VIP")
            case "1H":
                let exp = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
                return KeyValidationResult(isValid: true, duration: "1h", expiryText: "1 Giờ", expiryDateString: formatDate(exp), role: "VIP")
            default:
                break
            }
        }

        return KeyValidationResult(isValid: false, duration: "", expiryText: "", expiryDateString: "", role: "")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func handleVerificationError(_ msg: String, isSilent: Bool, completion: ((Bool) -> Void)?) {
        if !isSilent {
            self.errorMessage = msg
        }
        completion?(false)
    }
}

struct KeyGatekeeperView: View {
    @ObservedObject var keyAuth = KeyAuthManager.shared
    @State private var inputKey: String = ""
    @State private var copiedHWID = false

    var body: some View {
        ZStack {
            AppPageBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 20)

                    // Logo & Branding Header
                    VStack(spacing: 12) {
                        AppLogo(size: 72)

                        Text(AppBrand.name)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text("XÁC THỰC BẢN QUYỀN HỆ THỐNG")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(2.0)
                            .foregroundStyle(AppTheme.accentSoft)
                    }

                    // Card nhập Key
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.accent)
                            Text("NHẬP MÃ LICENSE KEY")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(AppTheme.accentSoft)
                            Spacer()
                        }

                        // Input field
                        HStack(spacing: 10) {
                            TextField("VD: PHUCVN-LIFE-XXXX-XXXX", text: $inputKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(AppTheme.pageBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                                }

                            Button {
                                if let paste = UIPasteboard.general.string {
                                    inputKey = paste.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                }
                            } label: {
                                Image(systemName: "doc.on.clipboard.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 48, height: 48)
                                    .background(AppTheme.pageBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                                    }
                            }
                        }

                        // Error message
                        if let error = keyAuth.errorMessage {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppTheme.danger)
                                    .font(.system(size: 13))
                                Text(error)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.danger)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }

                        // Submit Button
                        Button {
                            keyAuth.activate(key: inputKey)
                        } label: {
                            HStack(spacing: 8) {
                                if keyAuth.isVerifying {
                                    ProgressView()
                                        .tint(.black)
                                        .controlSize(.small)
                                    Text("ĐANG KIỂM TRA...")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("KÍCH HOẠT VÀ TIẾP TỤC")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(keyAuth.isVerifying)
                        .buttonStyle(AppPressableStyle())
                    }
                    .padding(20)
                    .background(AppTheme.consoleBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay { AppCardBorder(cornerRadius: 24) }
                    .shadow(color: .black.opacity(0.25), radius: 15, y: 7)

                    // Device Info HWID Card
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("MÃ THIẾT BỊ (HWID)")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.0)
                                .foregroundStyle(AppTheme.subduedText)
                            Text(keyAuth.deviceHWID)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button {
                            UIPasteboard.general.string = keyAuth.deviceHWID
                            copiedHWID = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedHWID = false
                            }
                        } label: {
                            Image(systemName: copiedHWID ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(copiedHWID ? AppTheme.success : AppTheme.accentSoft)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.06), in: Circle())
                        }
                    }
                    .padding(14)
                    .background(AppTheme.consoleBackground, in: RoundedRectangle(cornerRadius: 16))
                    .overlay { AppCardBorder(cornerRadius: 16) }

                    // Link vào Shop mua Key: https://phuciosvn.com/
                    Link(destination: URL(string: "https://phuciosvn.com/")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Chưa có Key? Mua Key tại Shop ngay")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.accent)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 22)
                        .background(Color.white.opacity(0.06), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(AppTheme.accent.opacity(0.35), lineWidth: 1)
                        }
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, AppTheme.pageInset)
            }
        }
    }
}
