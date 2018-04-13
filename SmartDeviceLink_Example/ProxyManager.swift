//
//  ProxyManager.swift
//  SmartDeviceLink-ExampleSwift
//
//  Copyright © 2017 smartdevicelink. All rights reserved.
//

import UIKit
import SmartDeviceLink

class ProxyManager: NSObject {
    fileprivate var sdlManager: SDLManager!
    fileprivate var buttonManager: ButtonManager!
    fileprivate var firstHMILevelState: SDLHMILevelFirstState
    weak var delegate: ProxyManagerDelegate?

    // Singleton
    static let sharedManager = ProxyManager()
    private override init() {
        firstHMILevelState = .none
        super.init()
    }
}

// MARK: - SDL Configuration

extension ProxyManager {
    /// Configures the SDL Manager that handles data transfer beween this app and the car's head unit and starts searching for a connection to a head unit. There are two possible types of transport layers to use: TCP is used to connect wirelessly to SDL Core and is only available for debugging; iAP is used to connect to MFi (Made for iPhone) hardware and is must be used for production builds.
    ///
    /// - Parameter connectionType: The type of transport layer to use.
    func start(with connectionType: SDLConnectionType) {
        delegate?.didChangeProxyState(SDLProxyState.searching)
        sdlManager = SDLManager(configuration: connectionType == .iAP ? ProxyManager.connectIAP() : ProxyManager.connectTCP(), delegate: self)
        startManager()
    }

    /// Attempts to close the connection between the this app and the car's head unit. The `SDLManagerDelegate`'s `managerDidDisconnect()` is called when connection is actually closed.
    func resetConnection() {
        sdlManager.stop()
    }
}

// MARK: - SDL Configuration Helpers

private extension ProxyManager {
    /// Configures an iAP transport layer.
    ///
    /// - Returns: A SDLConfiguration object
    class func connectIAP() -> SDLConfiguration {
        let lifecycleConfiguration = SDLLifecycleConfiguration(appName: ExampleAppName, appId: ExampleAppId)
        return setupManagerConfiguration(with: lifecycleConfiguration)
    }


    /// Configures a TCP transport layer with the IP address and port of the remote SDL Core instance.
    ///
    /// - Returns: A SDLConfiguration object
    class func connectTCP() -> SDLConfiguration {
        let lifecycleConfiguration = SDLLifecycleConfiguration(appName: ExampleAppName, appId: ExampleAppId, ipAddress: AppUserDefaults.shared.ipAddress!, port: UInt16(AppUserDefaults.shared.port!)!)
        return setupManagerConfiguration(with: lifecycleConfiguration)
    }

    /// Helper method for setting additional configuration parameters for both TCP and iAP transport layers.
    ///
    /// - Parameter lifecycleConfiguration: The transport layer configuration
    /// - Returns: A SDLConfiguration object
    class func setupManagerConfiguration(with lifecycleConfiguration: SDLLifecycleConfiguration) -> SDLConfiguration {
        lifecycleConfiguration.shortAppName = ExampleAppNameShort
        let appIcon = UIImage(named: ExampleAppLogoName)
        lifecycleConfiguration.appIcon = appIcon != nil ? SDLArtwork(image: appIcon!, persistent: true, as: .PNG) : nil
        lifecycleConfiguration.appType = .media

        let lockScreenConfiguration = appIcon != nil ? SDLLockScreenConfiguration.enabledConfiguration(withAppIcon: appIcon!, backgroundColor: nil) : SDLLockScreenConfiguration.enabled()
        return SDLConfiguration(lifecycle: lifecycleConfiguration, lockScreen: lockScreenConfiguration, logging: logConfiguration())
    }

    /// Sets the type of SDL debug logs that are visible and where to port the logs. There are 4 levels of logs, verbose, debug, warning and error, which verbose printing all SDL logs and error printing only the error logs. Adding SDLLogTargetFile to the targest will log to a text file on the iOS device. This file can be accessed via: iTunes > Your Device Name > File Sharing > Your App Name. Make sure `UIFileSharingEnabled` has been added to the application's info.plist and is set to `true`.
    ///
    /// - Returns: A SDLLogConfiguration object
    class func logConfiguration() -> SDLLogConfiguration {
        let logConfig = SDLLogConfiguration.default()
        let exampleLogFileModule = SDLLogFileModule(name: "SDL Example", files: ["ProxyManager"])
        logConfig.modules = logConfig.modules.union([exampleLogFileModule])
        logConfig.targets = NSSet(array: [SDLLogTargetFile.logger()]) as! Set<AnyHashable> // Logs to file
        logConfig.globalLogLevel = .verbose // Filters the logs
        return logConfig
    }

    /// Searches for a connection to a SDL enabled accessory. When a connection has been established, the ready handler is called. Even though a connection has been established, it does not mean that RPCs can be immediately sent to the accessory as there is no guarentee that Core is ready to receive RPCs for this app.
    func startManager() {
        sdlManager.start(readyHandler: { [unowned self] (success, error) in
            guard success else {
                print("There was an error while starting up: \(String(describing: error))")
                self.resetConnection()
                return
            }

            // A connection has been established between the app and a SDL enabled accessory
            self.delegate?.didChangeProxyState(SDLProxyState.connected)

            // Do some setup
            self.buttonManager = ButtonManager(sdlManager: self.sdlManager, updateScreenHandler: self.updateScreenHandler)
            self.setupPermissionsCallbacks(with: self.sdlManager)

            print("SDL file manager storage: \(self.sdlManager.fileManager.bytesAvailable / 1024 / 1024) mb")
        })
    }
}

// MARK: - SDLManagerDelegate

extension ProxyManager: SDLManagerDelegate {
    /// Called when the connection beween this app and SDL Core has closed.
    func managerDidDisconnect() {
        delegate?.didChangeProxyState(SDLProxyState.stopped)
        self.firstHMILevelState = .none

        // If desired, automatically start searching for a new connection to Core
        if ExampleAppShouldRestartSDLManagerOnDisconnect.boolValue {
            startManager()
        }
    }

    /// Called when the state of the SDL app has changed. The state limits the type of RPC that can be sent. Refer to the class documentation for each RPC to determine what state(s) the RPC can be sent.
    ///
    /// - Parameters:
    ///   - oldLevel: The old SDL HMI Level
    ///   - newLevel: The new SDL HMI Level
    func hmiLevel(_ oldLevel: SDLHMILevel, didChangeToLevel newLevel: SDLHMILevel) {
        if newLevel != .none && firstHMILevelState == .none {
            // This is our first time in a non-NONE state
            firstHMILevelState = .nonNone

            // Send static menu items. Menu related RPCs can be sent at all `hmiLevel`s except `NONE`
            prepareRemoteSystem()
        }

        if newLevel == .full && firstHMILevelState != .full {
            // This is our first time in a `FULL` state.
            firstHMILevelState = .full
        }

        switch newLevel {
        case .full:                // The SDL app is in the foreground
            // Always try to show the initial state to guard against some possible weird states. Duplicates will be ignored by Core.
            showInitialData()
        case .limited: break        // The SDL app's menu is open
        case .background: break     // The SDL app is not in the foreground
        case .none: break           // The SDL app is not yet running
        default: break
        }
    }

    func manticoreTest() {
        print("Waiting 10 seconds to send the CICS")
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 10.0) {
            print("Sending the CICS")
            self.sdlManager.send(MenuManager.createChoiceSets(), progressHandler: { (request, response, error, progress) in
                print("Create Interaction Choice Set RPC sent, Response: \(response?.resultCode == .success ? "successful" : "not successful"), Percent Complete: \(progress), Error: \(String(describing: error?.localizedDescription))")
            }, completionHandler: { (success) in
                print("All Create Interaction Choice Set RPCs send successfully: \(success ? "YES" : "NO")")
            })
        }
    }

    func audioStreamingState(_ oldState: SDLAudioStreamingState?, didChangeToState newState: SDLAudioStreamingState) {
        // The audio state only needs to be monitored if the app is streaming audio
        switch newState {
        case .audible: break        // The SDL app's audio can be heard
        case .notAudible: break     // The SDL app's audio cannot be heard
        case .attenuated: break     // The SDL app's audio volume has been lowered to let the system speak over the audio. This usually happens with voice recognition commands.
        default: break
        }
    }

    func managerShouldUpdateLifecycle(toLanguage language: SDLLanguage) -> SDLLifecycleConfigurationUpdate? {
        var appName = ""
        switch language {
        case .enUs:
            appName = ExampleAppName
        case .esMx:
            appName = ExampleAppNameSpanish
        case .frCa:
            appName = ExampleAppNameFrench
        default:
            return nil
        }

        return SDLLifecycleConfigurationUpdate(appName: appName, shortAppName: nil, ttsName: [SDLTTSChunk(text: appName, type: .text)], voiceRecognitionCommandNames: nil)
    }
}

// MARK: - SDL UI

private extension ProxyManager {
    var updateScreenHandler: updateScreenHandler? {
        return { [weak self] () in
            self?.updateScreen()
        }
    }

    func showInitialData() {
        let nonMediaTemplate = SDLSetDisplayLayout(predefinedLayout: .nonMedia)
        if sdlManager.registerResponse?.displayCapabilities?.templatesAvailable?.contains(nonMediaTemplate.displayLayout) ?? false {
            sdlManager.send(request: nonMediaTemplate, responseHandler: nil)
        }

        updateScreen()
        sdlManager.screenManager.softButtonObjects = buttonManager.screenSoftButtons(with: sdlManager)
    }

    func updateScreen() {
        guard sdlManager.hmiLevel == .full else { return }
        let screenManager = sdlManager.screenManager
        let isTextVisible = buttonManager.textEnabled
        let areImagesVisible = buttonManager.imagesEnabled

        screenManager.beginUpdates()
        screenManager.textAlignment = .left
        screenManager.textField1 = isTextVisible ? SmartDeviceLinkText : nil
        screenManager.textField2 = isTextVisible ? "Swift \(ExampleAppText)" : nil
        screenManager.primaryGraphic = areImagesVisible ? SDLArtwork(image: UIImage(named: ExampleAppLogoName)!, persistent: false, as: .PNG) : nil
        screenManager.endUpdates(completionHandler: { (error) in
            print("Updated text and graphics. Error? \(String(describing: error))")
        })
    }
}

// MARK: - SDL Remote Initial Setup

private extension ProxyManager {
    func setupPermissionsCallbacks(with manager: SDLManager) {
        // Gets the current permissions for a single RPC
        let isShowRPCAvailable = manager.permissionManager.isRPCAllowed("Show")
        print("Show RPC allowed? \(String(describing: isShowRPCAvailable))")

        // Get the current permissions of a group of RPCs
        let rpcGroup = ["AddCommand", "PerformInteraction"]
        let commandPICSStatus = manager.permissionManager.groupStatus(ofRPCs: rpcGroup)
        let commandPICSStatusDict = manager.permissionManager.status(ofRPCs: rpcGroup)
        print("The group status for \(rpcGroup) is: \(String(describing: commandPICSStatus)). The status for each RPC in the group is: \(String(describing: commandPICSStatusDict))")

        // Sets up a block for observing permission changes for a group of RPCs. Since the `groupType` is set to `SDLPermissionGroupTypeAllAllowed`, this block is called when the group permissions changes from all allowed to all not allowed. This block is called immediately when created.
        let observedRPCGroup = ["Show", "Alert"]
        let permissionAllAllowedObserverId = manager.permissionManager.addObserver(forRPCs: observedRPCGroup, groupType: .allAllowed, withHandler: { (individualStatuses, groupStatus) in
            print("The group status for \(observedRPCGroup) has changed to: \(groupStatus)")
            for (rpcName, rpcAllowed) in individualStatuses {
                print("\(rpcName as String) allowed? \(rpcAllowed.boolValue ? "yes" : "no")")
            }
        })

        // To stop observing permissions changes for a group of RPCs, remove the observer.
        manager.permissionManager.removeObserver(forIdentifier: permissionAllAllowedObserverId)

        // Sets up a block for observing permission changes for a group of RPCs. Since the `groupType` is set to `SDLPermissionGroupTypeAllAny`, this block is called when the permission status changes for any of the RPCs being observed. This block is called immediately when created.
        let _ = manager.permissionManager.addObserver(forRPCs: observedRPCGroup, groupType: .any, withHandler: { (individualStatuses, groupStatus) in
            print("The group status for \(observedRPCGroup) has changed to: \(groupStatus)")
            for (rpcName, rpcAllowed) in individualStatuses {
                print("\(rpcName as String) allowed? \(rpcAllowed.boolValue ? "yes" : "no")")
            }
        })

        // To stop observing permissions changes for a group of RPCs, remove the observer.
        // manager.permissionManager.removeObserver(forIdentifier: permissionAnyObserverId!)
    }

    func printRPCPermissions(rpcs: [String], groupPermissionStatus: SDLPermissionGroupType, individualPermissionStatuses: [String:Bool]) {
        print("The group status for \(rpcs) has changed to: \(groupPermissionStatus)")
        for (rpcName, rpcAllowed) in individualPermissionStatuses {
            print("\(rpcName as String) allowed? \(rpcAllowed ? "yes" : "no")")
        }
    }

    func prepareRemoteSystem() {
        sdlManager.send(MenuManager.allAddCommands(with: sdlManager) + [MenuManager.createInteractionChoiceSet()], progressHandler: { (request, response, error, percentComplete) in
            print("\(request), was sent \(response?.resultCode == .success ? "successfully" : "unsuccessfully"), error: \(error != nil ? error!.localizedDescription : "no error")")
        }, completionHandler: { (success) in
            print("All prepare remote system requests sent \(success ? "successfully" : "unsuccessfully")")
        })
    }
}

extension ProxyManager {
    class func sendGetVehicleData(with manager: SDLManager) {
        guard manager.permissionManager.isRPCAllowed("GetVehicleData") else {
            let warningAlert = AlertManager.alertWithMessageAndCloseButton("This app does not have the required permissions to access vehicle data")
            manager.send(request: warningAlert)
            return
        }

        let getVehicleData = SDLGetVehicleData(accelerationPedalPosition: true, airbagStatus: true, beltStatus: true, bodyInformation: true, clusterModeStatus: true, deviceStatus: true, driverBraking: true, eCallInfo: true, emergencyEvent: true, engineTorque: true, externalTemperature: true, fuelLevel: true, fuelLevelState: true, gps: true, headLampStatus: true, instantFuelConsumption: true, myKey: true, odometer: true, prndl: true, rpm: true, speed: true, steeringWheelAngle: true, tirePressure: true, vin: true, wiperStatus: true)

        manager.send(request: getVehicleData) { (request, response, error) in
            guard let response = response, error == nil else { return }

            var alertMessage = ""
            switch response.resultCode {
            case .rejected:
                alertMessage = "The request for vehicle data was rejected by Core."
            case .disallowed:
                alertMessage = "The app is not allowed to access vehicle data"
            case .success:
                alertMessage = "Vehicle data returned successfully"
            default: break
            }

            let alert = AlertManager.alertWithMessageAndCloseButton(alertMessage)
            manager.send(request: alert)

            // TODO create a PICS
            guard let getVehicleDataResponse = response as? SDLGetVehicleDataResponse else { return }
            let prndl = getVehicleDataResponse.prndl
            print("prndl: \(String(describing: prndl))")
        }
    }
}
