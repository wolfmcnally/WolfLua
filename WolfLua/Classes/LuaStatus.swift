//
//  LuaStatus.swift
//  WolfLua
//
//  Created by Wolf McNally on 4/22/18.
//

public enum LuaStatus: LuaInt {
    case ok = 0
    case yield = 1
    case errorRun = 2
    case errorSyntax = 3
    case errorMem = 4
    case errorGCMM = 5
    case error = 6
}
