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

extension UIColor {
    
    class func fromHex(hexString: String, alpha : Float = 1.0) -> UIColor {
        var newColor = UIColor.clear // this compensates for a bug in Swift2.x
        let scan = Scanner(string: hexString)
        var hexValue : UInt32 = 0
        if scan.scanHexInt32(&hexValue) {
            let r : CGFloat = CGFloat( hexValue >> 16 & 0x0ff) / 255.0
            let g : CGFloat = CGFloat( hexValue >> 8 & 0x0ff) / 255.0
            let b : CGFloat = CGFloat( hexValue      & 0x0ff) / 255.0
            newColor = UIColor(red: r , green: g,	blue:  b , alpha: CGFloat(alpha))
        }
        
        return newColor
    }
    
    func colorByAdjustingSaturation(factor : CGFloat) -> UIColor{
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var alpha:CGFloat = 0
        
        // get the old HSB
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &alpha )
        // apply the new S
        let newColor = UIColor(hue: h, saturation: s * factor, brightness: b, alpha: alpha)
        
        return newColor
    }
    
    func colorByAdjustingBrightness(factor : CGFloat) -> UIColor{
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var alpha:CGFloat = 0
        
        // get the old HSB
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &alpha )
        // apply the new B
        let newColor = UIColor(hue: h, saturation: s, brightness: b * factor, alpha: alpha)
        
        return newColor
    }
    
    func colorByAdjustingHue(factor : CGFloat) -> UIColor{
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var alpha:CGFloat = 0
        
        // get the old HSB
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &alpha )
        // apply the new H
        let newColor = UIColor(hue: h * factor, saturation: s, brightness: b , alpha: alpha)
        
        return newColor
    }
    
    func hexString() -> String {
        let components = self.cgColor.components
        
        let red = Float(components![0])
        let green = Float(components![1])
        let blue = Float(components![2])
        return String(format: "#%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255))
    }

    
}
