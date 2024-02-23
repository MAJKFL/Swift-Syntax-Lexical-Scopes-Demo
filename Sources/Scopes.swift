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
    
    /// Returns all the declarations available in the scope berore the specified absolute position. Sorted by position.
    func getAllDeclarations(before position: AbsolutePosition) -> [Declaration]
    
    /// Returns the declaration, the reference refers to.
    func getDeclaration(of declarationReference: DeclReferenceExprSyntax) -> Declaration?
}

extension Scope {
    /// Returns the declaration, the reference refers to.
    func getDeclaration(of declarationReference: DeclReferenceExprSyntax) -> Declaration? {
        return getAllDeclarations(before: declarationReference.position)
            .first { declaration in
                declaration.name == declarationReference.baseName.text
            }
    }
}

/// Global scope. Root of all other scopes.
class GlobalScope: Scope {
    /// Source file this scope represents.
    let sourceFileSyntax: SourceFileSyntax
    
    /// Global scope doesn't have a parent.
    var parent: Scope? = nil
    
    /// Initializes a global scope.
    init(_ sourceFileSyntax: SourceFileSyntax) {
        self.sourceFileSyntax = sourceFileSyntax
    }
    
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
    
    /// Returns all the declarations available in the scope berore the specified absolute position. Sorted by position.
    func getAllDeclarations(before position: AbsolutePosition) -> [Declaration] {
        return localDeclarations
            .filter { declaration in
                declaration.position < position
            }
            .sorted(by: { $0.position < $1.position })
    }
}

/// Represents scope within brackets. Should be further subclassed to provide specific functionality
class BlockScope: Scope {
    /// Code block represented by this scope.
    var codeBlockSyntax: CodeBlockSyntax?
    
    /// Syntax this code block is part of. Could be function declaration, if expression etc.
    var scopeSyntax: Syntax?
    
    /// Parent of this scope.
    var parent: Scope? {
        getParent(syntax: scopeSyntax?.parent)
    }
    
    /// Initializes a block scope.
    init(codeBlockSyntax: CodeBlockSyntax?, scopeSyntax: some SyntaxProtocol) {
        self.codeBlockSyntax = codeBlockSyntax
        self.scopeSyntax = Syntax(scopeSyntax)
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
    
    /// Variables passed from the parent scope and any declarations made before it's execution like e.g. funciton parameters..
    var startDeclarations: [Declaration] {
        guard let codeBlockSyntax, let parent else { return [] }
        
        return parent.getAllDeclarations(before: codeBlockSyntax.position)
    }
    
    /// Variables declared inside the scope.
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
    
    /// Returns all the declarations available in the scope berore the specified absolute position. Sorted by position.
    func getAllDeclarations(before position: AbsolutePosition) -> [Declaration] {
        return (startDeclarations.filter({ startDeclaration in
            !introducedVariables().contains(where: { parameter in
                startDeclaration.name == parameter.name
            })
        }) + introducedVariables() +
            localDelcarations.filter({ $0.position < position })).sorted(by: { $0.position < $1.position })
    }
    
    /// Variables introduced by this scope. Should be overriden by subclass. Could be function parameters, optional bindings, implicit newValue in a setter etc.
    func introducedVariables() -> [Declaration] {
        []
    }
}

/// Scope inside of a function.
class FunctionScope: BlockScope {
    /// Syntax of the function.
    var functionDeclarationSyntax: FunctionDeclSyntax
    
    /// Initializes a new function scope.
    init(_ functionDeclarationSyntax: FunctionDeclSyntax) {
        self.functionDeclarationSyntax = functionDeclarationSyntax
        super.init(codeBlockSyntax: functionDeclarationSyntax.body, scopeSyntax: functionDeclarationSyntax)
    }
    
    /// Parameters introduced in the function signature.
    var parameters: [Declaration] {
        functionDeclarationSyntax.signature.parameterClause.parameters.map({ Declaration($0) })
    }
    
    /// Returns variables introduced by this scope (parameters).
    override func introducedVariables() -> [Declaration] {
        parameters
    }
}

/// Scope inside of an if expression.
class IfExpressionScope: BlockScope {
    /// Syntax of the expression.
    var ifExpression: IfExprSyntax
    
    /// Initializes a new if expression scope.
    init(_ ifExpression: IfExprSyntax) {
        self.ifExpression = ifExpression
        super.init(codeBlockSyntax: ifExpression.body, scopeSyntax: ifExpression)
    }
    
    /// Optional bindings introduced by the if expression.
    var optionalBindings: [Declaration] {
        ifExpression.conditions
            .compactMap { conditionSyntax in
                guard let condition = conditionSyntax.condition.as(OptionalBindingConditionSyntax.self) else { return nil }
                
                return Declaration(condition)
            }
    }
    
    /// Returns variables introduced by this scope (optional bindings).
    override func introducedVariables() -> [Declaration] {
        optionalBindings
    }
}

/// Represents a variable declaration.
struct Declaration {
    /// Syntax that represents this declaration.
    let syntax: Syntax
    /// Name of the variable.
    let name: String
    
    /// Creates a new declaration for function parameter.
    init(_ parameter: FunctionParameterSyntax) {
        self.syntax = Syntax(parameter)
        self.name = parameter.secondName?.text ?? parameter.firstName.text
    }
    
    /// Creates a new declaration for optional binding.
    init?(_ optionalBinding: OptionalBindingConditionSyntax) {
        guard let name = optionalBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { return nil }
        
        self.syntax = Syntax(optionalBinding)
        self.name = name
    }
    
    /// Creates a new declaration for variable declaration.
    init?(_ variableDeclaration: VariableDeclSyntax) { // Won't work with tuples as for now
        guard let name = variableDeclaration.bindings
            .compactMap({ patternBinding in
                (patternBinding as PatternBindingSyntax).pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            }).first else { return nil }
        
        self.syntax = Syntax(variableDeclaration)
        self.name = name
    }
    
    /// Absolute position of this declaration.
    var position: AbsolutePosition {
        syntax.position
    }
}
