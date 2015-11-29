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
                (data:NSData?, string:String?)->() in
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
    func nrfDidConnect(nrfManager:NRFManager)
    {
        self.log("D: ★ Connected")
    }
    
    func nrfDidDisconnect(nrfManager:NRFManager)
    {
        self.log("D: ★ Disconnected")
    }
    
    func nrfReceivedData(nrfManager:NRFManager, data: NSData?, string: String?) {
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
        feedbackView.editable = false
        
        let connectButton:UIButton =  UIButton(type: .System)
        view.addSubview(connectButton)
        connectButton.setTitle("Connect", forState: UIControlState.Normal)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.addTarget(nrfManager, action: "connect", forControlEvents: UIControlEvents.TouchUpInside)
        
        let disconnectButton:UIButton = UIButton(type: .System)
        view.addSubview(disconnectButton)
        disconnectButton.setTitle("Disconnect", forState: UIControlState.Normal)
        disconnectButton.translatesAutoresizingMaskIntoConstraints = false
        disconnectButton.addTarget(nrfManager, action: "disconnect", forControlEvents: UIControlEvents.TouchUpInside)
        
        let sendButton:UIButton = UIButton(type: .System)
        view.addSubview(sendButton)
        sendButton.setTitle("Send Data", forState: UIControlState.Normal)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: "sendData", forControlEvents: UIControlEvents.TouchUpInside)
        
        
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-[f]-|", options: [], metrics: nil, views: ["f":feedbackView]))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-[c]-|", options: [], metrics: nil, views: ["c":connectButton]))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-[d]-|", options: [], metrics: nil, views: ["d":disconnectButton]))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-[s]-|", options: [], metrics: nil, views: ["s":sendButton]))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-20-[f]-[c]-[d]-[s]-20-|", options: [], metrics: nil, views: ["f":feedbackView,"c":connectButton,"d":disconnectButton,"s":sendButton]))
    }
    
    func log(string:String)
    {
        print(string)
        feedbackView.text = feedbackView.text + "\(string)\n"
        feedbackView.scrollRangeToVisible(NSMakeRange(feedbackView.text.characters.count , 1))
    }
    
}

