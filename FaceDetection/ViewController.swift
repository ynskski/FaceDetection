//
//  ViewController.swift
//  FaceDetection
//
//  Created by YunosukeSakai on 2020/10/13.
//

import UIKit

class ViewController: UIViewController {
    private var previewView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    private func setupPreviewView() {
        previewView = UIView()
        previewView?.backgroundColor = .black
        previewView?.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView!)
        
        previewView?.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        previewView?.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        previewView?.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        previewView?.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}

