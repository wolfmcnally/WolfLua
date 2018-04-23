//
//  LuaStringExtensions.swift
//  WolfLua
//
//  Created by Wolf McNally on 4/22/18.
//

extension String {
    public init(luaString: UnsafePointer<Int8>) {
        self = String(utf8String: luaString)!
    }

    public var luaString: [CChar] {
        return cString(using: .utf8)!
    }
}
