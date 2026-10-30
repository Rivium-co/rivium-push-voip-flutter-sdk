/**
 * RiviumPush VoIP Flutter Plugin — Self-Contained
 *
 * Handles PushKit + CallKit independently from the main Push SDK.
 * Works when app is killed: PushKit wakes app → CallKit shows → user accepts → Flutter starts
 *
 * Architecture:
 * - Registers for PushKit VoIP pushes directly (no dependency on main Push SDK for VoIP)
 * - Shows CallKit natively when VoIP push arrives
 * - Sends VoIP token to Rivium server using the API key
 * - When Flutter is running: forwards events via method channel
 * - When app is killed: stores accepted call → Flutter reads via getInitialCall()
 */
import Flutter
import UIKit
import PushKit
import RiviumPushVoip

public class RiviumPushVoipPlugin: NSObject, FlutterPlugin {
    private static var instance: RiviumPushVoipPlugin?
    private var channel: FlutterMethodChannel?
    private static var voipRegistry: PKPushRegistry?

    // Config persistence keys
    private static let configKey = "rivium_push_voip_config"
    private static let apiKeyKey = "rivium_push_voip_api_key"
    private static let deviceIdKey = "rivium_push_voip_device_id"
    private static let serverUrlKey = "rivium_push_voip_server_url"

    // Push SDK device ID key (to match token with correct device record)
    private static let pushSdkDeviceIdKey = "co.rivium.push.deviceId"

    // Server URL
    private static let defaultServerUrl = "https://push-api.rivium.co"

    /// SDK identity sent with the VoIP token registration.
    /// Keep `sdkVersion` in sync with pubspec.yaml and rivium_push_voip.podspec.
    static let sdkName = "flutter-voip"
    static let sdkVersion = "0.1.3"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "co.rivium.push/voip", binaryMessenger: registrar.messenger())
        let instance = RiviumPushVoipPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)

        RiviumPushVoipPlugin.instance = instance

        // Auto-initialize VoIP SDK if previously configured (for cold start)
        if let savedConfig = UserDefaults.standard.dictionary(forKey: configKey) {
            instance.autoInitialize(savedConfig: savedConfig)
        }

        print("[RiviumPushVoipPlugin] Plugin registered")
    }

    // MARK: - Auto-Initialize (Cold Start)

    private func autoInitialize(savedConfig: [String: Any]) {
        let appName = savedConfig["appName"] as? String ?? "App"
        guard !appName.isEmpty else { return }

        let config = VoipConfig(
            appName: appName,
            callTimeout: savedConfig["callTimeout"] as? Int ?? savedConfig["timeoutSeconds"] as? Int ?? 30,
            supportsVideo: savedConfig["supportsVideo"] as? Bool ?? true
        )

        RiviumPushVoip.shared.initialize(config: config)
        RiviumPushVoip.shared.delegate = self
        registerPushKit()

        print("[RiviumPushVoipPlugin] Auto-initialized for cold start: \(appName)")
    }

    // MARK: - PushKit Registration

    private func registerPushKit() {
        if RiviumPushVoipPlugin.voipRegistry == nil {
            RiviumPushVoipPlugin.voipRegistry = PKPushRegistry(queue: .main)
            RiviumPushVoipPlugin.voipRegistry?.delegate = self
            RiviumPushVoipPlugin.voipRegistry?.desiredPushTypes = [.voIP]
            print("[RiviumPushVoipPlugin] PushKit registered for VoIP")
        }
    }

    /// Resolve the device ID: check VoIP-specific key, then Push SDK key, then system fallback
    private func resolveDeviceId() -> String {
        if let id = UserDefaults.standard.string(forKey: RiviumPushVoipPlugin.deviceIdKey), !id.isEmpty {
            return id
        }
        if let id = UserDefaults.standard.string(forKey: RiviumPushVoipPlugin.pushSdkDeviceIdKey), !id.isEmpty {
            return id
        }
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    private func sendVoipTokenToServer(_ token: String) {
        guard let apiKey = UserDefaults.standard.string(forKey: RiviumPushVoipPlugin.apiKeyKey), !apiKey.isEmpty else {
            print("[RiviumPushVoipPlugin] No API key saved, skipping token registration")
            return
        }

        let deviceId = resolveDeviceId()
        let serverUrl = UserDefaults.standard.string(forKey: RiviumPushVoipPlugin.serverUrlKey) ?? RiviumPushVoipPlugin.defaultServerUrl
        let appIdentifier = Bundle.main.bundleIdentifier ?? "unknown"

        guard let url = URL(string: "\(serverUrl)/devices/register") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("\(RiviumPushVoipPlugin.sdkName)/\(RiviumPushVoipPlugin.sdkVersion)", forHTTPHeaderField: "X-Rivium-SDK")

        let body: [String: Any] = [
            "deviceId": deviceId,
            "platform": "ios",
            "pushToken": token,
            "appIdentifier": appIdentifier,
            "sdkName": RiviumPushVoipPlugin.sdkName,
            "sdkVersion": RiviumPushVoipPlugin.sdkVersion,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                print("[RiviumPushVoipPlugin] VoIP token sent: \(http.statusCode)")
            }
        }.resume()
    }

    // MARK: - Flutter Method Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isConfigured":
            let hasConfig = UserDefaults.standard.dictionary(forKey: RiviumPushVoipPlugin.configKey) != nil
            result(hasConfig)

        case "init":
            if let args = call.arguments as? [String: Any] {
                initVoip(config: args)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Config is required", details: nil))
            }

        case "getInitialCall":
            if let initialCall = RiviumPushVoip.shared.getInitialCall() {
                RiviumPushVoip.shared.clearInitialCall()
                result(initialCall.toDictionary())
            } else {
                result(nil)
            }

        case "endCall":
            if let args = call.arguments as? [String: Any],
               let callId = args["callId"] as? String {
                RiviumPushVoip.shared.endCall(callId: callId)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "callId is required", details: nil))
            }

        case "reportCallConnected":
            if let args = call.arguments as? [String: Any],
               let callId = args["callId"] as? String {
                RiviumPushVoip.shared.reportCallConnected(callId: callId)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "callId is required", details: nil))
            }

        case "showIncomingCall":
            if let args = call.arguments as? [String: Any] {
                let callData = mapToCallData(args)
                RiviumPushVoip.shared.showIncomingCall(callData: callData)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "callData is required", details: nil))
            }

        case "setApiKey":
            if let args = call.arguments as? [String: Any] {
                let apiKey = args["apiKey"] as? String ?? ""
                let deviceId = args["deviceId"] as? String ?? ""
                let serverUrl = args["serverUrl"] as? String ?? RiviumPushVoipPlugin.defaultServerUrl
                UserDefaults.standard.set(apiKey, forKey: RiviumPushVoipPlugin.apiKeyKey)
                UserDefaults.standard.set(deviceId, forKey: RiviumPushVoipPlugin.deviceIdKey)
                UserDefaults.standard.set(serverUrl, forKey: RiviumPushVoipPlugin.serverUrlKey)
                print("[RiviumPushVoipPlugin] API key saved for VoIP token registration")

                // Re-send VoIP token now that we have the API key + device ID
                if let token = RiviumPushVoipPlugin.voipRegistry?.pushToken(for: .voIP) {
                    let tokenStr = token.map { String(format: "%02x", $0) }.joined()
                    sendVoipTokenToServer(tokenStr)
                }

                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "apiKey is required", details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initVoip(config: [String: Any]) {
        let voipConfig = VoipConfig(
            appName: config["appName"] as? String ?? "App",
            vibrate: config["vibrate"] as? Bool ?? true,
            callTimeout: config["callTimeout"] as? Int ?? config["timeoutSeconds"] as? Int ?? 30,
            supportsVideo: config["supportsVideo"] as? Bool ?? true,
            ringtoneName: config["ringtoneSound"] as? String,
            callIdKey: config["callIdKey"] as? String ?? "call_id",
            callerNameKey: config["callerNameKey"] as? String ?? "callerName",
            callerIdKey: config["callerIdKey"] as? String ?? "callerId",
            callerAvatarKey: config["callerAvatarKey"] as? String ?? "callerAvatar",
            callTypeKey: config["callTypeKey"] as? String ?? "callType"
        )

        RiviumPushVoip.shared.initialize(config: voipConfig)
        RiviumPushVoip.shared.delegate = self

        // Save config for cold start auto-initialization
        let safeConfig = config.compactMapValues { $0 is NSNull ? nil : $0 }
        UserDefaults.standard.set(safeConfig, forKey: RiviumPushVoipPlugin.configKey)

        // Register PushKit for VoIP pushes
        registerPushKit()

        // Deliver pending initial call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let pendingCall = RiviumPushVoip.shared.getInitialCall() {
                print("[RiviumPushVoipPlugin] Delivering pending call: \(pendingCall.callId)")
                self?.invokeFlutterMethod("onCallAccepted", arguments: pendingCall.toDictionary())
            }
        }

        print("[RiviumPushVoipPlugin] Initialized with config: \(voipConfig.appName)")
    }

    private func invokeFlutterMethod(_ method: String, arguments: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod(method, arguments: arguments)
        }
    }

    private func mapToCallData(_ map: [String: Any]) -> VoipCallData {
        return VoipCallData(
            callId: map["callId"] as? String ?? "",
            callerName: map["callerName"] as? String ?? "Unknown",
            callerId: map["callerId"] as? String,
            callerAvatar: map["callerAvatar"] as? String,
            callType: map["mediaType"] as? String ?? "audio",
            payload: map["extra"] as? [String: Any],
            timestamp: map["receivedAt"] as? TimeInterval ?? Date().timeIntervalSince1970 * 1000
        )
    }
}

// MARK: - PKPushRegistryDelegate
extension RiviumPushVoipPlugin: PKPushRegistryDelegate {
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("[RiviumPushVoipPlugin] VoIP token: \(String(token.prefix(20)))...")
        sendVoipTokenToServer(token)
    }

    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }

        print("[RiviumPushVoipPlugin] VoIP push received!")

        // Let VoIP SDK handle it (shows CallKit synchronously)
        let handled = RiviumPushVoip.shared.handlePushPayload(payload.dictionaryPayload)

        if !handled {
            // Fallback: must report a call to CallKit (Apple requirement since iOS 13)
            let data = payload.dictionaryPayload
            let nestedData = data["data"] as? [String: Any] ?? [:]
            let effectiveData = nestedData.isEmpty ? data as? [String: Any] ?? [:] : nestedData

            let callData = VoipCallData(
                callId: effectiveData["callId"] as? String ?? UUID().uuidString,
                callerName: effectiveData["callerName"] as? String ?? "Unknown",
                callerId: effectiveData["callerId"] as? String,
                callerAvatar: effectiveData["callerAvatar"] as? String,
                callType: effectiveData["callType"] as? String ?? "audio"
            )
            RiviumPushVoip.shared.showIncomingCall(callData: callData)
        }

        completion()
    }

    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("[RiviumPushVoipPlugin] VoIP token invalidated")
    }
}

// MARK: - RiviumPushVoipDelegate
extension RiviumPushVoipPlugin: RiviumPushVoipDelegate {
    public func voip(_ voip: RiviumPushVoip, didAcceptCall callData: VoipCallData) {
        print("[RiviumPushVoipPlugin] Call accepted: \(callData.callId)")
        if channel != nil {
            invokeFlutterMethod("onCallAccepted", arguments: callData.toDictionary())
        } else {
            // Flutter not running — store for later
            RiviumPushVoip.shared.setInitialCall(callData)
        }
    }

    public func voip(_ voip: RiviumPushVoip, didDeclineCall callData: VoipCallData) {
        print("[RiviumPushVoipPlugin] Call declined: \(callData.callId)")
        invokeFlutterMethod("onCallDeclined", arguments: callData.toDictionary())
    }

    public func voip(_ voip: RiviumPushVoip, didTimeoutCall callData: VoipCallData) {
        print("[RiviumPushVoipPlugin] Call timeout: \(callData.callId)")
        invokeFlutterMethod("onCallTimeout", arguments: callData.toDictionary())
    }

    public func voip(_ voip: RiviumPushVoip, didFailWithError error: String) {
        print("[RiviumPushVoipPlugin] Error: \(error)")
        invokeFlutterMethod("onError", arguments: error)
    }

    public func voip(_ voip: RiviumPushVoip, didReceiveIncomingCall callData: VoipCallData) {
        print("[RiviumPushVoipPlugin] Incoming call (no CallKit): \(callData.callId)")
        invokeFlutterMethod("onCallAccepted", arguments: callData.toDictionary())
    }
}
