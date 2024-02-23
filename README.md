# Lexical Scopes Demo
This package demonstrates how lexical scopes could be implemented to Swift Syntax. After running, it prints declaration each `DeclReferenceExprSyntax` refers to in the input source code.
Right now, the implementation works with:
- Variable declarations (`VariableDeclSyntax`, not yet with tuples)
- If expression optional bindings (`OptionalBindingConditionSyntax`)
- Function parameters (`FunctionParameterSyntax`)

## Idea
The main goal of this implementation is to modularize the API for easier future maintainance and adding potential new scopes. Some inspiration was taken from the [C++ implementation of scopes](https://github.com/apple/swift/blob/main/include/swift/AST/ASTScope.h).

## How to run?
Simply clone the repository and run the swift package with `swift run` command or Xcode. The console should print for each reference it's declaration. To change the input code, adjust the `content` variable in the `main()` function of the `Parse` class.

## Demo implementation
This demo allows for looking up declarations of variables referenced in `DeclReferenceExprSyntax` (the class got extended with two properties `declaration` and `parentScope`). Additionally it's possible to look up all the variables in scope. In this demo, it's available through the property `scope` in `SourceFileSyntax`, `FunctionDeclSyntax` and `IfExprSyntax`.

### struct `Declaration`
Represents a declaration in the source code. It consists of two properties:
- `syntax` - holding the AST syntax representation of the declaration.
- `name` - holding the name of the declaration.

### protocol `Scope`
It's a general abstraction of any scope available in swift language. Each scope has:
- `parent` - parent scope of the scope.
- `getAllDeclarations(before:)` - returns all declarations available before specified `AbsolutePosition`.
- `getDeclaration(of:)` - returns the declaration a specified `DeclReferenceExprSyntax` refers to.

### class `GlobalScope`
It's always the root of the scope tree. Represented and associated in the AST by `SourceFileSyntax`. Implements the scope protocol. It has one additional property:
- `localDeclarations` - contains all declarations in inside the global scope.

### class `BlockScope`
Represents the scope within brackets. Represented and associated in the AST by `CodeBlockSyntax`. Should be subclassed before use. It has several additional properties and methods:
- `startDeclarations` - contains all declarations passed from the parent scope.
- `localDeclarations` - contains all declarations in the represented scope.
- `introducedVariables()` - is a class that should be overriden after subclassing. Returns all variable declarations introduced by the scope like e.g. function parameters, optional bindings, newValue in a getter etc. Used for determining variable shadowing.

### class `FunctionScope` and `IfExpressionScope`
Are example subclasses of `BlockScope`. They both have `parameters` and `optionalBindings` properties respectively, each holding the variables introduced by the scope. Both of the classes override the `introducedVariables()` method and return the introduced variables.

## Introducing new scopes
On top of this foundation, it should be fairly straight forward to implement new scope types. Doing such would require:
1. Subclassing `BlockScope`
2. overriding `introducedVariables()` and returning the introduced variables.
3.  Updating `getParent(syntax:)` and `getParentScope(syntax:)` of `BlockScope` and `DeclReferenceExprSyntax` respectively
