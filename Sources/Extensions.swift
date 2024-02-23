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

extension FunctionDeclSyntax {
    /// Scope of this function.
    var scope: FunctionScope {
        FunctionScope(self)
    }
}

extension IfExprSyntax {
    /// Scope of this if expression.
    var scope: IfExpressionScope {
        IfExpressionScope(self)
    }
}

extension DeclReferenceExprSyntax {
    /// Variable declaration this reference refers to.
    var declaration: Declaration? {
        return parentScope?.getDeclaration(of: self)
    }
    
    /// Scope this reference references.
    var parentScope: Scope? {
        return getParentScope(syntax: parent)
    }
    
    /// Recursively finds parent scope of this syntax.
    private func getParentScope(syntax: Syntax?) -> Scope? {
        guard let syntax else { return nil }
        
        if let scope = syntax.as(FunctionDeclSyntax.self)?.scope {
            return scope
        } else if let scope = syntax.as(IfExprSyntax.self)?.scope {
            return scope
        } else if let scope = syntax.as(SourceFileSyntax.self)?.scope {
            return scope
        }
        
        return getParentScope(syntax: syntax.parent)
    }
}

extension ReturnStmtSyntax {
    /// Scope this return keyword returns from.
    var returnsFrom: Scope? {
        return returnsFrom(syntax: parent)
    }
    
    /// Recursively finds the scope this return keyword returns from
    private func returnsFrom(syntax: Syntax?) -> Scope? {
        guard let syntax else { return nil }
        
        if let scope = syntax.as(FunctionDeclSyntax.self)?.scope { // Check if the current looked up syntax is a function declaration.
            return scope
        }
        
        return returnsFrom(syntax: syntax.parent) // Syntax not a function declaration. Continue up-search in the tree.
    }
}
