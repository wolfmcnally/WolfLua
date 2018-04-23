//
//  LuaError.swift
//  WolfLua
//
//  Created by Wolf McNally on 4/22/18.
//

public struct LuaError: Error {
    let status: LuaStatus
    let message: String
}
