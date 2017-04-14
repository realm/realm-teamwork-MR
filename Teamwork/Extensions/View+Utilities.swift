////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation
import UIKit

extension UIView {
    /**
     Shake the current view
     
     - parameter offset: offset in pixels
     - parameter count: number of times to shake
     */
    func shakeWithOffset(offset:CGFloat, count: Float) {
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.duration = 0.05
        animation.repeatCount = count
        animation.autoreverses = true
        animation.fromValue = self.center.x - offset
        animation.toValue = self.center.x + offset
        
        self.layer.add(animation, forKey: "position.x")
    }
    
    
    /**
     Ramp up (fade in) the alpha of the view over the user provided duration
     
     - parameter duration: duration in seconds, defaults to 1.0
     */
    func fadeIn(duration: TimeInterval = 0.5) {
        UIView.animate(withDuration: duration, delay: 0.0, options: UIViewAnimationOptions.curveEaseIn, animations: {
            self.alpha = 1.0 // Instead of a specific instance of, say, birdTypeLabel, we simply set [thisInstance] (ie, self)'s alpha
            }, completion: nil)
    }
    
    /**
     Ramp down (fade out) the alpha of the view over the user provided duration
     
     - parameter duration: duration in seconds, defaults to 1.0
     */
    func fadeOut(duration: TimeInterval = 1.0) {
        UIView.animate(withDuration: duration, delay: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
            self.alpha = 0.0
            }, completion: nil)
    }
    
    
    /**
     Apply a gradient of the supplied colors in even bands to a given view
     */
    func gradientLayerForView(colors:[CGColor]) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = self.bounds
        gradientLayer.colors = colors
        let interval = Float(self.bounds.size.height) / Float(gradientLayer.colors!.count)
        var locations: [NSNumber]?
        
        locations = stride(from:0.0, through: Double(bounds.size.height), by: Double(interval)).map{NSNumber(value: $0)}  // was CGFloat
        // Swift 2.3:
        //for index in Float(0).stride(through: Float(self.bounds.size.height) , by: interval) {
        //    locations?.append(NSNumber(index))
        //}
        gradientLayer.locations = locations
        self.layer.addSublayer(gradientLayer)
        
    }
    
    
    
    
}
