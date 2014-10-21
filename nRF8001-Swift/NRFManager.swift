//
//  NRFManager.swift
//  nRF8001-Swift
//
//  Created by Michael Teeuw on 31-07-14.
//  Copyright (c) 2014 Michael Teeuw. All rights reserved.
//

import Foundation
import CoreBluetooth


public enum ConnectionMode {
    case None
    case PinIO
    case UART
}

public enum ConnectionStatus {
    case Disconnected
    case Scanning
    case Connected
}



/*!
*  @class NRFManager
*
*  @discussion The manager for nRF8001 connections.
*
*/

// Mark: NRFManager Initialization
public class NRFManager:NSObject, CBCentralManagerDelegate, UARTPeripheralDelegate {
    

    //Private Properties
    private let bluetoothManager:CBCentralManager!
    private var currentPeripheral: UARTPeripheral? {
        didSet {
            if let p = currentPeripheral {
                p.verbose = self.verbose
            }
        }
    }
    
    //Public Properties
    public var verbose = false
    public var autoConnect = true
    public var delegate:NRFManagerDelegate?

    //callbacks
    public var connectionCallback:(()->())?
    public var disconnectionCallback:(()->())?
    public var dataCallback:((data:NSData?, string:String?)->())?
    
    public private(set) var connectionMode = ConnectionMode.None
    public private(set) var connectionStatus:ConnectionStatus = ConnectionStatus.Disconnected {
        didSet {
            if connectionStatus != oldValue {
                switch connectionStatus {
                    case .Connected:
                        
                        connectionCallback?()
                        delegate?.nrfDidConnect?(self)
                    
                    default:

                        disconnectionCallback?()
                        delegate?.nrfDidDisconnect?(self)
                }
            }
        }
    }


    
    
    

    public class var sharedInstance : NRFManager {
        struct Static {
            static let instance : NRFManager = NRFManager()
        }
        return Static.instance
    }
 
    public init(delegate:NRFManagerDelegate? = nil, onConnect connectionCallback:(()->())? = nil, onDisconnect disconnectionCallback:(()->())? = nil, onData dataCallback:((data:NSData?, string:String?)->())? = nil, autoConnect:Bool = true)
    {
        super.init()
        self.delegate = delegate
        self.autoConnect = autoConnect
        bluetoothManager = CBCentralManager(delegate: self, queue: nil)
        self.connectionCallback = connectionCallback
        self.disconnectionCallback = disconnectionCallback
        self.dataCallback = dataCallback
    }
    
}

// MARK: - Private Methods
extension NRFManager {
    
    private func scanForPeripheral()
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
    
    private func alertBluetoothPowerOff() {
        log("Bluetooth disabled");
        disconnect()
    }
    
    private func alertFailedConnection() {
        log("Unable to connect");
    }

    private func log(logMessage: String) {
        if (verbose) {
            println("NRFManager: \(logMessage)")
        }
    }
}

// MARK: - Public Methods
extension NRFManager {
    
    public func connect() {
        if currentPeripheral != nil && connectionStatus == .Connected {
            log("Asked to connect, but already connected!")
            return
        }
        
        scanForPeripheral()
    }
    
    public func disconnect()
    {
        if currentPeripheral == nil {
            log("Asked to disconnect, but no current connection!")
            return
        }
        
        log("Disconnect ...")
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
        log("Can't send string. No connection!")
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
        log("Can't send data. No connection!")
        return false
    }

}

// MARK: - CBCentralManagerDelegate Methods
extension NRFManager {

        public func centralManagerDidUpdateState(central: CBCentralManager!)
        {
            log("Central Manager Did UpdateState")
            if central.state == .PoweredOn {
                //respond to powered on
                log("Powered on!")
                if (autoConnect) {
                    connect()
                }
                
            } else if central.state == .PoweredOff {
                log("Powered off!")
                connectionStatus = ConnectionStatus.Disconnected
                connectionMode = ConnectionMode.None
            }
        }
    
        public func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!)
        {
            log("Did discover peripheral: \(peripheral.name)")
            bluetoothManager.stopScan()
            connectPeripheral(peripheral)
        }
    
        public func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!)
        {
            log("Did Connect Peripheral")
            if currentPeripheral?.peripheral == peripheral {
                if (peripheral.services) != nil {
                    log("Did connect to existing peripheral: \(peripheral.name)")
                    currentPeripheral?.peripheral(peripheral, didDiscoverServices: nil)
                } else {
                    log("Did connect peripheral: \(peripheral.name)")
                    currentPeripheral?.didConnect()
                }
            }
        }
    
        public func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!)
        {
            log("Peripheral Disconnected: \(peripheral.name)")
            
            if currentPeripheral?.peripheral == peripheral {
                connectionStatus = ConnectionStatus.Disconnected
                connectionMode = ConnectionMode.None
                currentPeripheral = nil
            }
            
            if autoConnect {
                connect()
            }
        }
    
        //optional func centralManager(central: CBCentralManager!, willRestoreState dict: [NSObject : AnyObject]!)
        //optional func centralManager(central: CBCentralManager!, didRetrievePeripherals peripherals: [AnyObject]!)
        //optional func centralManager(central: CBCentralManager!, didRetrieveConnectedPeripherals peripherals: [AnyObject]!)
        //optional func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!)
}

// MARK: - UARTPeripheralDelegate Methods
extension NRFManager {
    
    public func didReceiveData(newData:NSData)
    {
        if connectionStatus == .Connected || connectionStatus == .Scanning {
            log("Data: \(newData)");
            
            let string = NSString(data: newData, encoding:NSUTF8StringEncoding)
            log("String: \(string)")
            
            dataCallback?(data: newData, string: string)
            delegate?.nrfReceivedData?(self, data:newData, string: string)
            
        }
    }
    
    public func didReadHardwareRevisionString(string:String)
    {
        log("HW Revision: \(string)")
        connectionStatus = .Connected
    }
    
    public func uartDidEncounterError(error:String)
    {
        log("Error: error")
    }
    
}


// MARK: NRFManagerDelegate Definition
@objc public protocol NRFManagerDelegate {
    optional func nrfDidConnect(nrfManager:NRFManager)
    optional func nrfDidDisconnect(nrfManager:NRFManager)
    optional func nrfReceivedData(nrfManager:NRFManager, data:NSData?, string:String?)
}


/*!
*  @class UARTPeripheral
*
*  @discussion The peripheral object used by NRFManager.
*
*/

// MARK: UARTPeripheral Initialization
private class UARTPeripheral:NSObject, CBPeripheralDelegate {
    
    private var peripheral:CBPeripheral
    private var uartService:CBService?
    private var rxCharacteristic:CBCharacteristic?
    private var txCharacteristic:CBCharacteristic?
    
    private var delegate:UARTPeripheralDelegate
    private var verbose = false
    
    private init(peripheral:CBPeripheral, delegate:UARTPeripheralDelegate)
    {
        
        self.peripheral = peripheral
        self.delegate = delegate
        
        super.init()
        
        self.peripheral.delegate = self
    }
}

// MARK: Private Methods
extension UARTPeripheral {
    
    private func compareID(firstID:CBUUID, toID secondID:CBUUID)->Bool {
        return firstID.UUIDString == secondID.UUIDString
        
    }
    
    private func setupPeripheralForUse(peripheral:CBPeripheral)
    {
        log("Set up peripheral for use");
        for s:CBService in peripheral.services as [CBService] {
            for c:CBCharacteristic in s.characteristics as [CBCharacteristic] {
                if compareID(c.UUID, toID: UARTPeripheral.rxCharacteristicsUUID()) {
                    log("Found RX Characteristics")
                    rxCharacteristic = c
                    peripheral.setNotifyValue(true, forCharacteristic: rxCharacteristic)
                } else if compareID(c.UUID, toID: UARTPeripheral.txCharacteristicsUUID()) {
                    log("Found TX Characteristics")
                    txCharacteristic = c
                } else if compareID(c.UUID, toID: UARTPeripheral.hardwareRevisionStringUUID()) {
                    log("Found Hardware Revision String characteristic")
                    peripheral.readValueForCharacteristic(c)
                }
            }
        }
    }
    
    private func log(logMessage: String) {
        if (verbose) {
            println("UARTPeripheral: \(logMessage)")
        }
    }

    private func didConnect()
    {
        log("Did connect")
        if peripheral.services != nil {
            log("Skipping service discovery for: \(peripheral.name)")
            peripheral(peripheral, didDiscoverServices: nil)
            return
        }
        
        log("Start service discovery: \(peripheral.name)")
        peripheral.discoverServices([UARTPeripheral.uartServiceUUID(), UARTPeripheral.deviceInformationServiceUUID()])
    }
    
    private func writeString(string:String)
    {
        log("Write string: \(string)")
        let data = NSData(bytes: string, length: countElements(string))
        writeRawData(data)
    }
    
    private func writeRawData(data:NSData)
    {
        log("Write data: \(data)")
        
        if let txCharacteristic = self.txCharacteristic {
            
            if txCharacteristic.properties & .WriteWithoutResponse != nil {
                peripheral.writeValue(data, forCharacteristic: txCharacteristic, type: .WithoutResponse)
            } else if txCharacteristic.properties & .Write != nil {
                peripheral.writeValue(data, forCharacteristic: txCharacteristic, type: .WithResponse)
            } else {
                log("No write property on TX characteristics: \(txCharacteristic.properties)")
            }
            
        }
    }
}

// MARK: CBPeripheral Delegate methods
extension UARTPeripheral {
    private func peripheral(peripheral: CBPeripheral, didDiscoverServices error:NSError!) {
        if error == nil {
            for s:CBService in peripheral.services as [CBService] {
                if s.characteristics != nil {
                    var e = NSError()
                    //peripheral(peripheral, didDiscoverCharacteristicsForService: s, error: e)
                } else if compareID(s.UUID, toID: UARTPeripheral.uartServiceUUID()) {
                    log("Found correct service")
                    uartService = s
                    peripheral.discoverCharacteristics([UARTPeripheral.txCharacteristicsUUID(),UARTPeripheral.rxCharacteristicsUUID()], forService: uartService)
                } else if compareID(s.UUID, toID: UARTPeripheral.deviceInformationServiceUUID()) {
                    peripheral.discoverCharacteristics([UARTPeripheral.hardwareRevisionStringUUID()], forService: s)
                }
            }
        } else {
            log("Error discovering characteristics: \(error)")
            delegate.uartDidEncounterError("Error discovering services")
            return
        }
    }
    
    private func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!)
    {
        if error  == nil {
            log("Did Discover Characteristics For Service: \(service.description)")
            let services:[CBService] = peripheral.services as [CBService]
            let s = services[services.count - 1]
            if compareID(service.UUID, toID: s.UUID) {
                setupPeripheralForUse(peripheral)
            }
        } else {
            log("Error discovering characteristics: \(error)")
            delegate.uartDidEncounterError("Error discovering characteristics")
            return
        }
    }
    
   private func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!)
    {
        log("Did Update Value For Characteristic")
        if error == nil {
            if characteristic == rxCharacteristic {
                log("Recieved: \(characteristic.value)")
                delegate.didReceiveData(characteristic.value)
            } else if compareID(characteristic.UUID, toID: UARTPeripheral.hardwareRevisionStringUUID()){
                log("Did read hardware revision string")
                // FIX ME: This is not how the original thing worked.
                delegate.didReadHardwareRevisionString(NSString(CString:characteristic.description, encoding: NSUTF8StringEncoding) ?? "")
            }
        } else {
            log("Error receiving notification for characteristic: \(error)")
            delegate.uartDidEncounterError("Error receiving notification for characteristic")
            return
        }
    }
}

// MARK: Class Methods
extension UARTPeripheral {
    class func uartServiceUUID() -> CBUUID {
        return CBUUID(string:"6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    }
    
    class func txCharacteristicsUUID() -> CBUUID {
        return CBUUID(string:"6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    }
    
    class func rxCharacteristicsUUID() -> CBUUID {
        return CBUUID(string:"6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    }
    
    class func deviceInformationServiceUUID() -> CBUUID{
        return CBUUID(string:"180A")
    }
    
    class func hardwareRevisionStringUUID() -> CBUUID{
        return CBUUID(string:"2A27")
    }
}

// MARK: UARTPeripheralDelegate Definition
private protocol UARTPeripheralDelegate {
    func didReceiveData(newData:NSData)
    func didReadHardwareRevisionString(string:String)
    func uartDidEncounterError(error:String)
}



