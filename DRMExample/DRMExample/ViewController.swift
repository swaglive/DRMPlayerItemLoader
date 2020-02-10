//
//  ViewController.swift
//  drm
//
//  Created by peter on 2020/1/8.
//  Copyright © 2020 SWAG. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    
    var playerVC: PlayerViewController?
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let vc = PlayerViewController()
        present(vc, animated: false, completion: nil)
        playerVC = vc
        
    }


}

