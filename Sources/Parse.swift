//
//  File.swift
//  
//
//  Created by Jakub Florek on 21/02/2024.
//

import Foundation
import SwiftParser
import SwiftSyntax

@main
struct Parse {
    static func main() {
        let content = 
        """
            func f(a: Int, b: Int?) -> Int {
                if let b = b {
                    return a + c
                }
            
                return a
            }
        """

        let formattedCode = Parser.parse(source: content)
        
        DeclarationReferenceVisitor(viewMode: .sourceAccurate).walk(formattedCode)
    }
}

/// Prints the declaration syntax for each DeclarationReferenceSyntax node.
final class DeclarationReferenceVisitor: SyntaxVisitor {
    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        print("Variable: \(node.baseName)\nRefers to:")
        print(node.declaration?.syntax)
        print("---------------------")
        return super.visit(node)
    }
}
