# Indentation Helper Notes

## Macro conveniences
- `@println_indented io expr...`: expand to `TimestampedPathsPretty.println_indented(io, expr...)` so callers can drop the module prefix.
- `@show_block io "Label" begin ... end`: desugars to `show_block(io, "Label") do inner_io ... end`, handling context creation and cleanup.

## Functor shorthand
- `Indenter(io; extra=0)` returns a callable that shifts the indent once and exposes `ind("label: ", value)` semantics.

## Struct boilerplate generator
- `@define_shower StructType`: introspect `StructType` fields at macro-expansion time and emit a `show` method that iterates its fields using the helpers (mind parametric type support).

## Trade-offs
- Macros trim repetitive syntax but hide behavior—keep expansions small and explicit for maintainability.
- Functor aliases stay in ordinary function space, good when you need to capture additional state with the `io`.
