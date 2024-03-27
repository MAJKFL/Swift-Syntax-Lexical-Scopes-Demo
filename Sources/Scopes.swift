//
//  File.swift
//  
//
//  Created by Jakub Florek on 23/02/2024.
//

import Foundation
import SwiftSyntax
import SwiftParser

/// Protocol describing a general scope.
protocol Scope {
    /// Parent scope
    var parent: Scope? { get }
    
    /// Variables introduced by this scope. Should be overriden by subclass. Could be function parameters, optional bindings, implicit newValue in a setter etc.
    var introducedVariables: [Declaration] { get }
    
    /// Returns all the declarations available in the scope berore the specified absolute position. Sorted by position.
    func getAllDecl(before position: AbsolutePosition) -> [Declaration]
    
    /// Returns the declaration, the reference refers to.
    func getDecl(of declarationReference: DeclReferenceExprSyntax) -> Declaration?
}

extension Scope {
    /// Returns the declaration, the reference refers to.
    func getDecl(of declarationReference: DeclReferenceExprSyntax) -> Declaration? {
        return getAllDecl(before: declarationReference.position)
            .first { declaration in
                declaration.refersTo(name: declarationReference.baseName.text)
            }
    }
}

/// Global scope. Root of all other scopes.
class GlobalScope: Scope {
    /// No introduced variables before global scope.
    var introducedVariables: [Declaration] = []
    
    /// Source file this scope represents.
    let sourceFileSyntax: SourceFileSyntax
    
    /// Global scope doesn't have a parent.
    var parent: Scope? = nil
    
    /// Declarations made in the body of the global scope.
    var localDeclarations: [Declaration] {
        sourceFileSyntax.statements.compactMap { statement in
            if let variableDeclarationSyntax = statement.item.as(VariableDeclSyntax.self) {
                return Declaration(variableDeclarationSyntax)
            } else {
                return nil
            }
        }
    }
    
    /// Initializes a global scope.
    init(_ sourceFileSyntax: SourceFileSyntax) {
        self.sourceFileSyntax = sourceFileSyntax
    }
    
    /// Returns all the declarations available in the scope berore the specified absolute position. Sorted by position.
    func getAllDecl(before position: AbsolutePosition) -> [Declaration] {
        return localDeclarations
            .filter { declaration in
                declaration.position < position
            }
            .sorted(by: { $0.position < $1.position })
    }
    
}

/// Represents scope within brackets. Should be further subclassed to provide specific functionality
protocol CodeBlockScope: Scope {
    /// Code block represented by this scope.
    var codeBlockSyntax: CodeBlockSyntax? { get }
    
    /// Variables passed from the parent scope and any declarations made before it's execution like e.g. funciton parameters..
    var startDeclarations: [Declaration] { get }
    
    /// Variables declared inside the scope.
    var localDelcarations: [Declaration] { get }
}

extension CodeBlockScope {
    /// Parent of the scope.
    var parent: Scope? {
        getParent(syntax: codeBlockSyntax?.parent)
    }
    
    /// Variables passed from the parent scope and any declarations made before it's execution like e.g. funciton parameters..
    var startDeclarations: [Declaration] {
        guard let codeBlockSyntax, let parent else { return [] }
        
        return parent.getAllDecl(before: codeBlockSyntax.position)
    }
    
    /// Declarations made within the scope.
    var localDelcarations: [Declaration] {
        guard let codeBlockSyntax else { return [] }
        
        return codeBlockSyntax.statements.compactMap { statement in
            if let variableDeclarationSyntax = statement.item.as(VariableDeclSyntax.self) {
                return Declaration(variableDeclarationSyntax)
            } else {
                return nil
            }
        }
    }
    
    /// Recursively finds parent of this scope.
    private func getParent(syntax: Syntax?) -> Scope? {
        guard let syntax else { return nil }
        
        if let blockScope = syntax.as(CodeBlockSyntax.self)?.scope {
            return blockScope
        } else if let globalScope = syntax.as(SourceFileSyntax.self)?.scope {
            return globalScope
        }
        
        return getParent(syntax: syntax.parent)
    }
    
    /// Returns all the declarations available in the scope berore the specified absolute position. Sorted by position.
    func getAllDecl(before position: AbsolutePosition) -> [Declaration] {
        return (startDeclarations.filter({ startDeclaration in
            !introducedVariables.contains(where: { parameter in
                startDeclaration.refersTo(names: parameter.names)
            })
        }) + introducedVariables +
            localDelcarations.filter({ $0.position < position })).sorted(by: { $0.position < $1.position })
    }
}

/// Scope inside of a function.
class FunctionScope: CodeBlockScope {
    /// Syntax of the scope.
    var codeBlockSyntax: CodeBlockSyntax?
    
    /// Syntax of the function.
    var functionDeclarationSyntax: FunctionDeclSyntax
    
    /// Parameters introduced in the function signature.
    var introducedVariables: [Declaration] {
        functionDeclarationSyntax.signature.parameterClause.parameters.map({ Declaration($0) })
    }
    
    /// Initializes a new function scope.
    init(_ functionDeclarationSyntax: FunctionDeclSyntax) {
        self.codeBlockSyntax = functionDeclarationSyntax.body
        self.functionDeclarationSyntax = functionDeclarationSyntax
    }
}

/// Scope inside of an if expression.
class IfExpressionScope: CodeBlockScope {
    /// Syntax of the scope.
    var codeBlockSyntax: CodeBlockSyntax?
    
    /// Syntax of the expression.
    var ifExpression: IfExprSyntax
    
    /// Optional bindings introduced by the if expression.
    var introducedVariables: [Declaration] {
        ifExpression.conditions
            .compactMap { conditionSyntax in
                guard let condition = conditionSyntax.condition.as(OptionalBindingConditionSyntax.self) else { return nil }
                
                return Declaration(condition)
            }
    }
    
    /// Initializes a new if expression scope.
    init(_ ifExpression: IfExprSyntax) {
        self.ifExpression = ifExpression
        self.codeBlockSyntax = ifExpression.body
    }
}

/// Represents a variable declaration.
struct Declaration {
    /// Syntax that represents this declaration.
    let syntax: Syntax
    /// Name of the variable.
    let names: [String]
    
    /// Creates a new declaration for function parameter.
    init(_ parameter: FunctionParameterSyntax) {
        self.syntax = Syntax(parameter)
        self.names = [parameter.secondName?.text ?? parameter.firstName.text]
    }
    
    /// Creates a new declaration for optional binding.
    init?(_ optionalBinding: OptionalBindingConditionSyntax) {
        guard let name = optionalBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { return nil }
        
        self.syntax = Syntax(optionalBinding)
        self.names = [name]
    }
    
    /// Creates a new declaration for variable declaration.
    init?(_ variableDeclaration: VariableDeclSyntax) {
        self.syntax = Syntax(variableDeclaration)
        self.names = variableDeclaration.bindings
            .compactMap({ patternBinding in
                (patternBinding as PatternBindingSyntax).pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            })
    }
    
    /// Absolute position of this declaration.
    var position: AbsolutePosition {
        syntax.position
    }
    
    /// Name comparison
    func refersTo(name: String) -> Bool {
        return names.contains(name)
    }
    
    /// Name comparison for tuples
    func refersTo(names: [String]) -> Bool {
        return self.names.allSatisfy { name in
            names.contains(name)
        }
    }
}
