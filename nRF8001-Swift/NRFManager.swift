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




class NRFManager:NSObject, CBCentralManagerDelegate, UARTPeripheralDelegate {
    
    
    
    
    
    let bluetoothManager:CBCentralManager!
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
    var currentPeripheral: UARTPeripheral?
    
    
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
    
    func scanForPeripherals()
    {
        let connectedPeripherals = bluetoothManager.retrieveConnectedPeripheralsWithServices([UARTPeripheral.uartServiceUUID()])
        
        println(connectedPeripherals)
        if connectedPeripherals.count > 0 {
            println("Already connected ...")
            connectPeripheral(connectedPeripherals[0] as CBPeripheral)
        } else {
            println("Scan for Peripherials")
            
            bluetoothManager.scanForPeripheralsWithServices([UARTPeripheral.uartServiceUUID()], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        }
    }
    
    func connectPeripheral(peripheral:CBPeripheral) {
        println("Connect to Peripheral: \(peripheral)")
        
        //clear pending connections
        bluetoothManager.cancelPeripheralConnection(peripheral)
        
        //connect
        currentPeripheral = UARTPeripheral(peripheral: peripheral, delegate: self)
        
        bluetoothManager.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey:false])
    }
    
    func disconnect()
    {
        println("Disconnected ...")
    
        connectionStatus = ConnectionStatus.Disconnected
        connectionMode = ConnectionMode.None
        
        bluetoothManager.cancelPeripheralConnection(currentPeripheral?.peripheral)
        
        scanForPeripherals()
    }
    
    func peripheralDidDisconnect()
    {
        println("Peripheral Disconnected.")
        disconnect()
    }
    
    
    func alertBluetoothPowerOff() {
        println("Bluetooth disabled");
        disconnect()
    }
    
    
    func alertFailedConnection() {
        println("Unable to connect");
    }


}

// MARK: - Public Methods
extension NRFManager {
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
            println("Central Manager Did UpdateState")
            if central.state == .PoweredOn {
                //respond to powered on
                println("Powered on!")
                scanForPeripherals()
                
            } else if central.state == .PoweredOff {
                println("Powered off!")
                connectionStatus = ConnectionStatus.Disconnected
                connectionMode = ConnectionMode.None
            }
        }
    

    
        func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!)
        {
            println("Did discover peripheral: \(peripheral.name)")
            bluetoothManager.stopScan()
            connectPeripheral(peripheral)
        }
    
        func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!)
        {
            println("Did Connect Peripheral")
            if currentPeripheral?.peripheral.isEqual(peripheral) {
                if (peripheral.services) {
                    println("Did connect to existing peripheral: \(peripheral.name)")
                    currentPeripheral?.peripheral(peripheral, didDiscoverServices: nil)
                } else {
                    println("Did connect peripheral: \(peripheral.name)")
                    currentPeripheral?.didConnect()
                }
            }
        }
    

    
        func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!)
        {
            println("Did disconnect peripheral: \(peripheral.name)")
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
            println("Data: \(newData)");
            
            let string = NSString(data: newData, encoding:NSUTF8StringEncoding)
            println("String: \(string)")
            
            if let dataCallback = self.dataCallback {
                dataCallback(string: string, data: newData)
            }
            
        }
    }
    func didReadHardwareRevisionString(string:String)
    {
        println("HW Revision: \(string)")
        connectionStatus = .Connected
    }
    
    
    func uartDidEncounterError(error:String)
    {
        println("Error: error")
    }
    
    
}
