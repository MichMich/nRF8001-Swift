//
//  ViewController.swift
//  nRF8001-Swift
//
//  Created by Michael Teeuw on 31-07-14.
//  Copyright (c) 2014 Michael Teeuw. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var nrfManager:NRFManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        nrfManager = NRFManager(
            onConnect: {
                println("!!! Connected")
                
                let result = self.nrfManager.writeString("Whoopa!")
            },
            onDisconnect: {
                println("!!! Disconnected")
            },
            onData: {
                (string:String, data:NSData)->() in
                println("!!! Recieved data !!!")
                println("String: \(string)")
                println("Data: \(data)")
            }
        )


    }

}

