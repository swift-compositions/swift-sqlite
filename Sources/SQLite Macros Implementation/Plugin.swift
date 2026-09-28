import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SQLitePlugin: CompilerPlugin {
  let providingMacros: [any Macro.Type] = [
    DatabaseCollationMacro.self,
    DatabaseFunctionMacro.self,
    IsolationCheckMacro.self,
    MainActorIsolationCheckMacro.self,
  ]
}
