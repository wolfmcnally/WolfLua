//
//  LuaOperator.swift
//  WolfLua
//
//  Created by Wolf McNally on 4/22/18.
//

public enum LuaOperator: LuaInt {
    case add = 0                // addition (+)
    case subtract = 1           // subtration (-)
    case multiply = 2           // multiplication (*)
    case divide = 5             // floating-point division (/)
    case integerDivide = 6      // floor division (//)
    case modulus = 3            // modulo (%)
    case power = 4              // exponentiation (^)
    case unaryMinus = 12        // mathematical negation (unary -)

    case unaryBitwiseNOT = 13   // bitwise NOT (unary ~)
    case bitwiseAND = 7         // bitwise AND (&)
    case bitwiseOR = 8          // bitwise OR (|)
    case bitwiseXOR = 9         // bitwise XOR (~)
    case bitwiseShiftLeft = 10  // left shift (<<)
    case bitwiseShiftRight = 11 // right shift (>>)

    public var isUnary: Bool {
        return self == .unaryMinus || self == .unaryBitwiseNOT
    }
}

public enum LuaComparison: LuaInt {
    case equal = 0              // compares for equality (==)
    case lessThan = 1           // compares for less than (<)
    case lessThanOrEqual = 2    // compares for less or equal (<=)
}
