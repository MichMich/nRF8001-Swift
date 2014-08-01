//
//  NRFManager.swift
//  nRF8001-Swift
//
//  Created by Michael Teeuw on 31-07-14.
//  Copyright (c) 2014 Michael Teeuw. All rights reserved.
//

import Foundation
import CoreBluetooth


enum ConnectionMode {
    case None
    case PinIO
    case UART
}

enum ConnectionStatus {
    case Disconnected
    case Scanning
    case Connected
}


// Mark: Initialization
class NRFManager:NSObject, CBCentralManagerDelegate, UARTPeripheralDelegate {
    
    // Should we log to the console?
    public var verbose = true
    
    private let bluetoothManager:CBCentralManager!
    
    var connectionMode = ConnectionMode.None
    var connectionStatus:ConnectionStatus = ConnectionStatus.Disconnected {
        didSet {
            switch connectionStatus {
                case .Connected:
                    if let connectionCallback = self.connectionCallback {
                        connectionCallback()
                    }
                default:
                    if let disconnectionCallback = self.disconnectionCallback {
                        disconnectionCallback()
                    }
            }
        }
    }
    
    var currentPeripheral: UARTPeripheral? {
        didSet {
            if let p = currentPeripheral {
                p.verbose = self.verbose
            }
        }
    }
    
    //callbacks
    var connectionCallback:(()->())?
    var disconnectionCallback:(()->())?
    var dataCallback:((string:String, data:NSData)->())?

    class var sharedInstance : NRFManager {
        struct Static {
            static let instance : NRFManager = NRFManager()
        }
        return Static.instance
    }
 
    init()
    {
        super.init()
        bluetoothManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    convenience init(onConnect connectionCallback:(()->())?, onDisconnect disconnectionCallback:(()->())?, onData dataCallback:((string:String, data:NSData)->())?)
    {
        self.init()
        self.connectionCallback = connectionCallback
        self.disconnectionCallback = disconnectionCallback
        self.dataCallback = dataCallback
    }
    
}

// MARK: - Private Methods
extension NRFManager {
    
    private func scanForPeripherals()
    {
        let connectedPeripherals = bluetoothManager.retrieveConnectedPeripheralsWithServices([UARTPeripheral.uartServiceUUID()])

        if connectedPeripherals.count > 0 {
            log("Already connected ...")
            connectPeripheral(connectedPeripherals[0] as CBPeripheral)
        } else {
            log("Scan for Peripherials")
            bluetoothManager.scanForPeripheralsWithServices([UARTPeripheral.uartServiceUUID()], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        }
    }
    
    private func connectPeripheral(peripheral:CBPeripheral) {
        log("Connect to Peripheral: \(peripheral)")
        
        bluetoothManager.cancelPeripheralConnection(peripheral)
        
        currentPeripheral = UARTPeripheral(peripheral: peripheral, delegate: self)
        
        bluetoothManager.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey:false])
    }
    
    private func peripheralDidDisconnect()
    {
        log("Peripheral Disconnected.")
        disconnect()
        connect()
    }
    
    private func alertBluetoothPowerOff() {
        log("Bluetooth disabled");
        disconnect()
    }
    
    private func alertFailedConnection() {
        log("Unable to connect");
    }

    private func log(logMessage: String) {
        if (verbose) {
            println(logMessage)
        }
    }
}

// MARK: - Public Methods
extension NRFManager {
    
    public func connect() {
        log("Connect!")
        
        scanForPeripherals()
    }
    
    public func disconnect()
    {
        log("Disconnect ...")
        
        connectionStatus = ConnectionStatus.Disconnected
        connectionMode = ConnectionMode.None
        
        bluetoothManager.cancelPeripheralConnection(currentPeripheral?.peripheral)
    }
    
    public func writeString(string:String) -> Bool
    {
        if let currentPeripheral = self.currentPeripheral {
            if connectionStatus == .Connected {
                currentPeripheral.writeString(string)
                return true
            }
        }
        return false
    }
    
    public func writeData(data:NSData) -> Bool
    {
        if let currentPeripheral = self.currentPeripheral {
            if connectionStatus == .Connected {
                currentPeripheral.writeRawData(data)
                return true
            }
        }
        return false
    }

}

// MARK: - CBCentralManagerDelegate Methods
extension NRFManager {

        func centralManagerDidUpdateState(central: CBCentralManager!)
        {
            log("Central Manager Did UpdateState")
            if central.state == .PoweredOn {
                //respond to powered on
                log("Powered on!")
                scanForPeripherals()
                
            } else if central.state == .PoweredOff {
                log("Powered off!")
                connectionStatus = ConnectionStatus.Disconnected
                connectionMode = ConnectionMode.None
            }
        }
    
        func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!)
        {
            log("Did discover peripheral: \(peripheral.name)")
            bluetoothManager.stopScan()
            connectPeripheral(peripheral)
        }
    
        func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!)
        {
            log("Did Connect Peripheral")
            if currentPeripheral?.peripheral.isEqual(peripheral) {
                if (peripheral.services) {
                    log("Did connect to existing peripheral: \(peripheral.name)")
                    currentPeripheral?.peripheral(peripheral, didDiscoverServices: nil)
                } else {
                    log("Did connect peripheral: \(peripheral.name)")
                    currentPeripheral?.didConnect()
                }
            }
        }
    
        func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!)
        {
            log("Did disconnect peripheral: \(peripheral.name)")
            peripheralDidDisconnect()
            if currentPeripheral?.peripheral.isEqual(peripheral) {
                currentPeripheral?.didDisconnect()
            }
        }
    
        //optional func centralManager(central: CBCentralManager!, willRestoreState dict: [NSObject : AnyObject]!)
        //optional func centralManager(central: CBCentralManager!, didRetrievePeripherals peripherals: [AnyObject]!)
        //optional func centralManager(central: CBCentralManager!, didRetrieveConnectedPeripherals peripherals: [AnyObject]!)
        //optional func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!)
}

// MARK: - UARTPeripheralDelegate Methods
extension NRFManager {
    
    func didReceiveData(newData:NSData)
    {
        if connectionStatus == .Connected || connectionStatus == .Scanning {
            log("Data: \(newData)");
            
            let string = NSString(data: newData, encoding:NSUTF8StringEncoding)
            log("String: \(string)")
            
            if let dataCallback = self.dataCallback {
                dataCallback(string: string, data: newData)
            }
            
        }
    }
    func didReadHardwareRevisionString(string:String)
    {
        log("HW Revision: \(string)")
        connectionStatus = .Connected
    }
    
    func uartDidEncounterError(error:String)
    {
        log("Error: error")
    }
    
}
