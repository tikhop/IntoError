import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct IntoErrorPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        IntoErrorMacro.self,
    ]
}
