//
//  LuaTypes.swift
//  WolfLua
//
//  Created by Wolf McNally on 4/22/18.
//

import CLua

public typealias LuaInt = Int32
public typealias LuaState = UnsafeMutablePointer<lua_State>
public typealias LuaCFunction = @convention(c) (LuaState?) -> LuaInt
public typealias LuaContinuationContext = Int
public typealias LuaContinuationFunction = @convention(c) (LuaState?, LuaInt, LuaContinuationContext) -> LuaInt
public typealias LuaUserData = UnsafeMutableRawPointer
public typealias LuaPointer = UnsafeRawPointer

//public typealias LuaFunction = (Lua) throws -> LuaInt

public enum LuaType: LuaInt {
    case none = -1
    case luaNil = 0
    case boolean = 1
    case lightUserData = 2
    case number = 3
    case string = 4
    case table = 5
    case function = 6
    case userData = 7
    case thread = 8
}
