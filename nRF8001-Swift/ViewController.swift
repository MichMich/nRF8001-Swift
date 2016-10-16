//
//  ViewController.swift
//  nRF8001-Swift
//
//  Created by Michael Teeuw on 31-07-14.
//  Copyright (c) 2014 Michael Teeuw. All rights reserved.
//

import UIKit

class ViewController: UIViewController, NRFManagerDelegate {
    
    var nrfManager:NRFManager!
    var feedbackView = UITextView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        nrfManager = NRFManager(
            onConnect: {
                self.log("C: ★ Connected")
            },
            onDisconnect: {
                self.log("C: ★ Disconnected")
            },
            onData: {
                (data:Data?, string:String?)->() in
                self.log("C: ⬇ Received data - String: \(string) - Data: \(data)")
            },
            autoConnect: false
        )
        
        nrfManager.verbose = true
        nrfManager.delegate = self
        
        setupUI()
    }
    
    func sendData()
    {
        let string = "Whoot!"
        let result = self.nrfManager.writeString(string)
        log("⬆ Sent string: \(string) - Result: \(result)")
    }
}

// MARK: - NRFManagerDelegate Methods
extension ViewController
{
    func nrfDidConnect(_ nrfManager:NRFManager)
    {
        self.log("D: ★ Connected")
    }
    
    func nrfDidDisconnect(_ nrfManager:NRFManager)
    {
        self.log("D: ★ Disconnected")
    }
    
    func nrfReceivedData(_ nrfManager:NRFManager, data: Data?, string: String?) {
        self.log("D: ⬇ Received data - String: \(string) - Data: \(data)")
    }
}

// MARK: - Various stuff
extension ViewController {
    func setupUI()
    {
        view.addSubview(feedbackView)
        feedbackView.translatesAutoresizingMaskIntoConstraints = false
        feedbackView.layer.borderWidth = 1
        feedbackView.isEditable = false
        
        let connectButton:UIButton =  UIButton(type: .system)
        view.addSubview(connectButton)
        connectButton.setTitle("Connect", for: UIControlState())
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.addTarget(nrfManager, action: Selector(("connect")), for: UIControlEvents.touchUpInside)
        
        let disconnectButton:UIButton = UIButton(type: .system)
        view.addSubview(disconnectButton)
        disconnectButton.setTitle("Disconnect", for: UIControlState())
        disconnectButton.translatesAutoresizingMaskIntoConstraints = false
        disconnectButton.addTarget(nrfManager, action: Selector(("disconnect")), for: UIControlEvents.touchUpInside)
        
        let sendButton:UIButton = UIButton(type: .system)
        view.addSubview(sendButton)
        sendButton.setTitle("Send Data", for: UIControlState())
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(ViewController.sendData), for: UIControlEvents.touchUpInside)
        
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[f]-|", options: [], metrics: nil, views: ["f":feedbackView]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[c]-|", options: [], metrics: nil, views: ["c":connectButton]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[d]-|", options: [], metrics: nil, views: ["d":disconnectButton]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[s]-|", options: [], metrics: nil, views: ["s":sendButton]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-20-[f]-[c]-[d]-[s]-20-|", options: [], metrics: nil, views: ["f":feedbackView,"c":connectButton,"d":disconnectButton,"s":sendButton]))
    }
    
    func log(_ string:String)
    {
        print(string)
        feedbackView.text = feedbackView.text + "\(string)\n"
        feedbackView.scrollRangeToVisible(NSMakeRange(feedbackView.text.characters.count , 1))
    }
    
}

