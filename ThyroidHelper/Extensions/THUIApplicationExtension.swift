//
//  THUIApplicationExtension.swift
//  ThyroidHelper
//
//  Created by gdliu on 2025/9/15.
//

import UIKit

extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
