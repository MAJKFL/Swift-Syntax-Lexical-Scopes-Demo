# Lexical Scopes Demo
This package demonstrates how lexical scopes could be implemented to Swift Syntax. After running, it prints declaration each `DeclReferenceExprSyntax` refers to in the input source code.
Right now, the implementation works with:
- Variable declarations (`VariableDeclSyntax`)
- If expression optional bindings (`OptionalBindingConditionSyntax`)
- Function parameters (`FunctionParameterSyntax`)

## Idea
The main goal of this implementation is to modularize the API for easier future maintainance and adding potential new scopes. Some inspiration was taken from the [C++ implementation of scopes](https://github.com/apple/swift/blob/main/include/swift/AST/ASTScope.h).

## How to run?
Simply clone the repository and run the swift package with `swift run` command or Xcode. The console should print for each reference it's declaration. To change the input code, adjust the `content` variable in the `main()` function of the `Parse` class.

## Demo implementation
This demo allows for looking up declarations of variables referenced in `DeclReferenceExprSyntax` and scopes of the references through two new properties: `declaration` and `parentScope`. In this demo, `CodeBlockSyntax` got extended with one additional property `scope` of type `BlockScope`. It contains all information about the variables available and introduced in the scope. Additionally there's `GlobalScope` associated with `SourceFileSyntax`.

### struct `Declaration`
Represents a declaration in the source code. Serves as an abstraction over `Syntax` for easier name lookup. It consists of three properties and two methods:
- `syntax` - holding the AST syntax representation of the declaration.
- `names` - containing all identifiers of the declaration.
- `position` - holding the `AbsolutePosition` of the `syntax`
- `refersTo(name:)` - checking if passed name refers to one of the declarations within the syntax
- `refersTo(names:)` - checking whether one of the passed names refers to one of the names within the syntax 

### protocol `Scope`
It's a general abstraction of any scope available in swift language. Each scope has:
- `parent` - parent scope of the scope.
- `introducedVariables` - is a class that should be overriden after subclassing. Returns all variable declarations introduced by the scope like e.g. function parameters, optional bindings, newValue in a getter etc. Used for determining variable shadowing.
- `getAllDecl(before:)` - returns all declarations available before specified `AbsolutePosition`.
- `getDecl(of:)` - returns the declaration a specified `DeclReferenceExprSyntax` refers to.

### class `GlobalScope`
It's always the root of the scope tree. Represented and associated in the AST by `SourceFileSyntax`. Implements the scope protocol. It doesn't have any additional properties.

### protocol `BlockScope`
Represents the scope within brackets where order of the declarations matters. Represented and associated in the AST by `CodeBlockSyntax`. Should be subclassed before use. It has several additional properties and methods:
- `startDeclarations` - contains all declarations passed from the parent scope.
- `localDeclarations` - contains all declarations in the represented scope.

### class `FunctionScope` and `IfExpressionScope`
Are example implementation of `BlockScope` protocol. They both fill in `introducedVariables` with the variables introduced by the scope.

## Introducing new scopes
On top of this foundation, it should be fairly straight forward to implement new scope types. Doing such would require:
1. Subclassing `BlockScope`
2. Filling in `introducedVariables` accrodingly
3. Updating `scope` computed property of `CodeBlockSyntax`
