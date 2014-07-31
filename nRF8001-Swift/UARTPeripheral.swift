//
//  UARTPeripheral.swift
//  nRF8001-Swift
//
//  Created by Michael Teeuw on 31-07-14.
//  Copyright (c) 2014 Michael Teeuw. All rights reserved.
//

import Foundation
import CoreBluetooth




class UARTPeripheral:NSObject, CBPeripheralDelegate {
    
    var peripheral:CBPeripheral
    var delegate:UARTPeripheralDelegate
    
    var uartService:CBService?
    var rxCharacteristic:CBCharacteristic?
    var txCharacteristic:CBCharacteristic?
    
    init(peripheral:CBPeripheral, delegate:UARTPeripheralDelegate)
    {

        self.peripheral = peripheral
        self.delegate = delegate
        
        super.init()
        
        self.peripheral.delegate = self
    }
    
    func didConnect()
    {
        println("Did connect")
        if peripheral.services {
            println("Skipping service discovery for: \(peripheral.name)")
            peripheral(peripheral, didDiscoverServices: nil)
            return
        }
        
        println("Start service discovery: \(peripheral.name)")
        peripheral.discoverServices([UARTPeripheral.uartServiceUUID(), UARTPeripheral.deviceInformationServiceUUID()])
    }
    
    func didDisconnect()
    {
        println("Peripheral disconnected")
    }
    
    func writeString(string:String)
    {
        println("Write string: \(string)")
        let data = NSData(bytes: string, length: countElements(string))
        writeRawData(data)
    }
    
    func writeRawData(data:NSData)
    {
        println("Write data: \(data)")
        
        if let txCharacteristic = self.txCharacteristic {
            if (txCharacteristic.properties.getLogicValue() & CBCharacteristicProperties.WriteWithoutResponse.getLogicValue()) != 0 {
                peripheral.writeValue(data, forCharacteristic: txCharacteristic, type: .WithoutResponse)
            } else if (txCharacteristic.properties.getLogicValue() & CBCharacteristicProperties.Write.getLogicValue()) != 0  {
                peripheral.writeValue(data, forCharacteristic: txCharacteristic, type: .WithResponse)
            } else {
                println("No write property on TX characteristics: \(txCharacteristic.properties)")
            }
        }
    }
    
    func compareID(firstID:CBUUID, toID secondID:CBUUID)->Bool {
        return firstID.UUIDString == secondID.UUIDString
         
    }
    
    func setupPeripheralForUse(peripheral:CBPeripheral)
    {
        println("Set up peripheral for use");
        for s:CBService in peripheral.services as [CBService] {
            for c:CBCharacteristic in s.characteristics as [CBCharacteristic] {
                if compareID(c.UUID, toID: UARTPeripheral.rxCharacteristicsUUID()) {
                    println("Found RX Characteristics")
                    rxCharacteristic = c
                    peripheral.setNotifyValue(true, forCharacteristic: rxCharacteristic)
                } else if compareID(c.UUID, toID: UARTPeripheral.txCharacteristicsUUID()) {
                    println("Found TX Characteristics")
                    txCharacteristic = c
                } else if compareID(c.UUID, toID: UARTPeripheral.hardwareRevisionStringUUID()) {
                    println("Found Hardware Revision String characteristic")
                    peripheral.readValueForCharacteristic(c)
                }
            }
        }
    }
    
    
}

// MARK: CBPeripheral Delegate methods
extension UARTPeripheral {
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error:NSError!) {
        println("Did Discover Services");
        if !error {
            for s:CBService in peripheral.services as [CBService] {
                if s.characteristics {
                    var e = NSError()
                    //peripheral(peripheral, didDiscoverCharacteristicsForService: s, error: e)
                } else if compareID(s.UUID, toID: UARTPeripheral.uartServiceUUID()) {
                    println("Found correct service")
                    uartService = s
                    peripheral.discoverCharacteristics([UARTPeripheral.txCharacteristicsUUID(),UARTPeripheral.rxCharacteristicsUUID()], forService: uartService)
                } else if compareID(s.UUID, toID: UARTPeripheral.deviceInformationServiceUUID()) {
                    peripheral.discoverCharacteristics([UARTPeripheral.hardwareRevisionStringUUID()], forService: s)
                }
            }
        } else {
            println("Error discovering characteristics: \(error)")
            delegate.uartDidEncounterError("Error discovering services")
            return
        }
    }
  
   
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!)
    {
        println("Did Discover Characteristics For Service")
        if !error {
            let services:[CBService] = peripheral.services as [CBService]
            let s = services[services.count - 1]
            if compareID(service.UUID, toID: s.UUID) {
                setupPeripheralForUse(peripheral)
            }
        } else {
            println("Error discovering characteristics: \(error)")
            delegate.uartDidEncounterError("Error discovering characteristics")
            return
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!)
    {
        println("Did Update Value For Characteristic")
        if !error {
            if characteristic == rxCharacteristic {
                println("Recieved: \(characteristic.value)")
                delegate.didReceiveData(characteristic.value)
            } else if compareID(characteristic.UUID, toID: UARTPeripheral.hardwareRevisionStringUUID()){
                println("Did read hardware revision string")
                // FIX ME: This is not how the original thing worked.
                delegate.didReadHardwareRevisionString(NSString(CString:characteristic.description, encoding: NSUTF8StringEncoding))
            }
        } else {
            println("Error receiving notification for characteristic: \(error)")
            delegate.uartDidEncounterError("Error receiving notification for characteristic")
            return
        }
    }

}

// MARK: Class Methods
extension UARTPeripheral {
    class func uartServiceUUID() -> CBUUID {
        return CBUUID.UUIDWithString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    }
    
    class func txCharacteristicsUUID() -> CBUUID {
        return CBUUID.UUIDWithString("6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    }
    
    class func rxCharacteristicsUUID() -> CBUUID {
        return CBUUID.UUIDWithString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    }
    
    class func deviceInformationServiceUUID() -> CBUUID{
        return CBUUID.UUIDWithString("180A")
    }
    
    class func hardwareRevisionStringUUID() -> CBUUID{
        return CBUUID.UUIDWithString("2A27")
    }
}

protocol  UARTPeripheralDelegate {
    
    func didReceiveData(newData:NSData)
    func didReadHardwareRevisionString(string:String)
    func uartDidEncounterError(error:String)

}



