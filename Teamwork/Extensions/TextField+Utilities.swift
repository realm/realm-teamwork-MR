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

extension UITextField {
    func innerShadowWithTint(tint: UIColor, backgroundColor: UIColor, radius: CGFloat, opacity: Float) {
        let shadowLayer = CALayer()
        shadowLayer.frame = CGRect(x: 0, y: self.frame.size.height + 2, width: self.frame.size.width, height: 2.0) // was: CGRectMake(0, self.frame.size.height + 2, self.frame.size.width, 2.0)
        shadowLayer.backgroundColor = backgroundColor.cgColor
        shadowLayer.shadowColor = tint.cgColor
        shadowLayer.shadowOffset = CGSize.zero
        shadowLayer.shadowRadius = radius
        shadowLayer.shadowOpacity = opacity
        self.layer.addSublayer(shadowLayer)
    }

    func setBorderWithColor(color: UIColor, width: CGFloat, cornerRadius: CGFloat) {
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = width
        self.layer.cornerRadius = cornerRadius
    }

}
