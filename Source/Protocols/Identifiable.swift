//
//  Created by Pierluigi Cifani on 28/04/16.
//  Copyright © 2016 Blurred Software SL. All rights reserved.
//

import Foundation

public typealias Identity = String

public protocol Identifiable {
    var identity: Identity { get }
}

extension Equatable where Self : Identifiable {
    
}

public func ==(lhs: Identifiable, rhs: Identifiable) -> Bool {
    return lhs.identity == rhs.identity
}
