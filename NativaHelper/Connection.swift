//
//  Connection.swift
//  Nativa
//
//  Created by Solomenchuk, Vlad on 8/26/15.
//  Copyright © 2015 Aramzamzam LLC. All rights reserved.
//

import Foundation

protocol Connection {
    func request(_ data: Data, response: @escaping (Result<Data>) -> Void)
}
