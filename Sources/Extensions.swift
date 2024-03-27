//
//  Extensions.swift
//
//
//  Created by Jakub Florek on 20/02/2024.
//

import Foundation
import SwiftParser
import SwiftSyntax

extension SourceFileSyntax {
    /// Scope of this source file.
    var scope: GlobalScope {
        GlobalScope(self)
    }
}

extension CodeBlockSyntax {
    var scope: CodeBlockScope? {
        if let functionDeclaration = parent?.as(FunctionDeclSyntax.self) {
            return FunctionScope(functionDeclaration)
        } else if let ifExpression = parent?.as(IfExprSyntax.self) {
            return IfExpressionScope(ifExpression)
        } else {
            return nil
        }
    }
}

extension DeclReferenceExprSyntax {
    /// Variable declaration this reference refers to.
    var declaration: Declaration? {
        return parentScope?.getDecl(of: self)
    }
    
    /// Scope this reference references.
    var parentScope: Scope? {
        return getParentScope(syntax: parent)
    }
    
    /// Recursively finds parent scope of this syntax.
    private func getParentScope(syntax: Syntax?) -> Scope? {
        guard let syntax else { return nil }
        
        if let blockScope = syntax.as(CodeBlockSyntax.self)?.scope {
            return blockScope
        } else if let globalScope = syntax.as(SourceFileSyntax.self)?.scope {
            return globalScope
        }
        
        return getParentScope(syntax: syntax.parent)
    }
}
