//
//  Interpreter.swift
//  slox
//
//  Created by Alejandro Martinez on 30/05/2017.
//  Copyright © 2017 Alejandro Martinez. All rights reserved.
//

import Foundation

enum InterpreterError: Error {
    case runtime(Token, String) // TODO: Instead of string we could have different cases for each error.
}

enum Result<T> {
    case success(T)
    case error(Error)

    func map<R>(_ f: ((T) -> R)) -> Result<R> {
        switch self {
        case .error(let e):
            return .error(e)
        case .success(let r):
            return .success(f(r))
        }
    }
}

final class Interpreter: Visitor {
    typealias Return = Result<Any>?

    func interpret(_ expression: Expr) {
        guard let value = evaluate(expr: expression) else {
            print(stringify(value: nil))
            return
        }
        switch value {
        case .success(let v):
            print(stringify(value: v))
        case .error(let error):
            runtimeError(error: error)
        }
    }

    private func stringify(value: Any?) -> String {
        guard let v = value else { return "nil" }

        // TODO: Consider number formatting
        return String(describing: v)
    }

    // MARK: Visitor

    func visitLiteralExpr(_ expr: Expr.Literal) -> Result<Any>? {
        guard let value = expr.value else {
            return nil
        }
        return .success(value)
    }

    func visitGroupingExpr(_ expr: Expr.Grouping) -> Result<Any>? {
        return .success(evaluate(expr: expr.expression))
    }

    func visitUnaryExpr(_ expr: Expr.Unary) -> Result<Any>? {
        let right = evaluate(expr: expr.right)

        switch expr.op.type {
        case .bang:
            return .success(!isTrue(object: right))
        case .minus:
            let casted = castNumberOperand(op: expr.op, operand: right)
            return casted.map(-)

        case .leftParen, .rightParen: fallthrough
        case .leftBrace, .rightBrace: fallthrough
        case .comma: fallthrough
        case .dot: fallthrough
        case .plus: fallthrough
        case .semicolon: fallthrough
        case .slash: fallthrough
        case .star: fallthrough
        case .bangEqual: fallthrough
        case .equal: fallthrough
        case .equalEqual: fallthrough
        case .greater, .greaterEqual: fallthrough
        case .less, .lessEqual: fallthrough
        case .identifier: fallthrough
        case .string: fallthrough
        case .number: fallthrough
        case .and: fallthrough
        case .Class: fallthrough
        case .Else: fallthrough
        case .False: fallthrough
        case .fun: fallthrough
        case .For: fallthrough
        case .If: fallthrough
        case .Nil: fallthrough
        case .or: fallthrough
        case .print: fallthrough
        case .Return: fallthrough
        case .Super: fallthrough
        case .this: fallthrough
        case .True: fallthrough
        case .Var: fallthrough
        case .While: fallthrough
        case .eof:
            // Unreachable.
            fatalError()
        }
    }

    func visitBinaryExpr(_ expr: Expr.Binary) -> Result<Any>? {
        let left = evaluate(expr: expr.left)
        let right = evaluate(expr: expr.right)

        switch expr.op.type {
        case .minus:
            return castNumberOperands(op: expr.op, left: expr.left, right: expr.right).map({ $0.0 - $0.1 })
        case .slash:
            return castNumberOperands(op: expr.op, left: expr.left, right: expr.right).map({ $0.0 / $0.1 })
        case .star:
            return castNumberOperands(op: expr.op, left: expr.left, right: expr.right).map({ $0.0 * $0.1 })
        case .plus:

            guard let left = left, let right = right else {
                return .error(InterpreterError.runtime(expr.op, "Operands must be two numbers or two strings."))
            }

            guard case let .success(ls) = left, case let .success(rs) = right else {
                return .error(InterpreterError.runtime(expr.op, "Operands must be two numbers or two strings."))
            }

            if let lDouble = ls as? Double, let rDouble = rs as? Double {
                return .success(lDouble + rDouble)
            }

            if let lString = ls as? String, let rString = rs as? String {
                return .success(lString + rString)
            }

            return .error(InterpreterError.runtime(expr.op, "Operands must be two numbers or two strings."))

        case .greater:
            return castNumberOperands(op: expr.op, left: expr.left, right: expr.right).map({ $0.0 > $0.1 })
        case .greaterEqual:
            return castNumberOperands(op: expr.op, left: expr.left, right: expr.right).map({ $0.0 >= $0.1 })
        case .less:
            return castNumberOperands(op: expr.op, left: expr.left, right: expr.right).map({ $0.0 < $0.1 })
        case .lessEqual:
            return castNumberOperands(op: expr.op, left: expr.left, right: expr.right).map({ $0.0 <= $0.1 })

        case .bangEqual:
            return .success(!isEqualAny(left: left, right: right))
        case .equalEqual:
            return .success(isEqualAny(left: left, right: right))

        case .leftParen, .rightParen: fallthrough
        case .leftBrace, .rightBrace: fallthrough
        case .comma: fallthrough
        case .dot: fallthrough
        case .semicolon: fallthrough
        case .bang: fallthrough
        case .equal: fallthrough
        case .identifier: fallthrough
        case .string: fallthrough
        case .number: fallthrough
        case .and: fallthrough
        case .Class: fallthrough
        case .Else: fallthrough
        case .False: fallthrough
        case .fun: fallthrough
        case .For: fallthrough
        case .If: fallthrough
        case .Nil: fallthrough
        case .or: fallthrough
        case .print: fallthrough
        case .Return: fallthrough
        case .Super: fallthrough
        case .this: fallthrough
        case .True: fallthrough
        case .Var: fallthrough
        case .While: fallthrough
        case .eof:
            // Unreachable.
            fatalError()
        }
    }

    private func evaluate(expr: Expr) -> Result<Any>? {
        return expr.accept(visitor: self)
    }

    private func isTrue(object: Any?) -> Bool {
        if object == nil {
            return false
        }

        if let b = object as? Bool {
            return b
        }

        return true
    }

    private func isEqualAny(left: Any?, right: Any?) -> Bool {
        // nil is only equal to nil.
        if left == nil && right == nil {
            return true
        }

        if left == nil {
            return false
        }

        /*
         guard left.self == right.self else {
         // Types are different.
         return false
         }*/

        if let l = left as? String, let r = right as? String {
            return l == r
        }

        if let l = left as? Bool, let r = right as? Bool {
            return l == r
        }

        if let l = left as? Double, let r = right as? Double {
            return l == r
        }

        fatalError("Unsupported equatable type. /n \(String(describing: left)) or \(String(describing: right))/nOR TYPES ARE JUST DIFFERET")
    }

    // MARK: Runtime checks

    private func castNumberOperands(op: Token, left: Any?, right: Any?) -> Result<(Double, Double)> {
        if let l = left as? Double, let r = right as? Double {
            return .success(l, r)
        }

        return .error(InterpreterError.runtime(op, "Operands must be numbers."))
    }

    private func castNumberOperand(op: Token, operand: Any?) -> Result<Double> {
        if let res = operand as? Double {
            return .success(res)
        }

        return .error(InterpreterError.runtime(op, "Operand must be a number."))
    }
}
