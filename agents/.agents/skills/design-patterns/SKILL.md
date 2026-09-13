---
name: design-patterns
description: Analyze software design problems and apply Gang of Four patterns only when they reduce real complexity. Use for pattern selection, architecture and refactoring decisions, code-smell analysis, decoupling, extensibility, object creation, interchangeable behavior, incompatible interfaces, undo or state transitions. Inspect the existing code before recommending a pattern and avoid triggering for routine edits that need no structural design decision.
---

# Design Patterns

Identify the concrete design pressure first, then select and implement the
simplest structure that addresses it.

## Workflow

1. Read the relevant code, tests, repository instructions, and nearby
   abstractions.
2. State the specific design problem in codebase terms.
3. Decide whether a named pattern provides a measurable benefit over a direct
   solution.
4. Compare plausible alternatives when more than one pattern fits.
5. Explain the selected pattern's benefit, cost, and migration impact.
6. Implement the smallest coherent change when the user asks for code changes.
7. Run focused tests and inspect the final diff.

Do not introduce a pattern only to make the code resemble a catalog example.
Preserve established repository conventions unless they are part of the
problem.

## Select a Pattern

### Object creation

- Use **Factory Method** when creation must vary without coupling callers to
  concrete classes.
- Use **Abstract Factory** when families of related objects must remain
  compatible.
- Use **Builder** when construction has meaningful stages or many optional
  values.
- Use **Singleton** only when process-wide uniqueness is an actual invariant;
  prefer dependency injection for access and testability.

Read [references/creational.md](references/creational.md) when the problem is
primarily about object creation.

### Behavior and algorithms

- Use **Strategy** for interchangeable algorithms or policies.
- Use **State** when behavior changes with explicit state transitions.
- Use **Observer** for one-to-many event notification with clear lifecycle
  ownership.
- Use **Command** when operations need queuing, logging, retry, or undo.
- Use **Memento** when state snapshots must be restored without exposing
  internals.
- Use **Template Method** when a stable algorithm skeleton has controlled
  variation points and inheritance is already appropriate.

Read [references/behavioral.md](references/behavioral.md) when the problem is
primarily about behavior, events, operations, or state.

### Structure and interfaces

- Use **Adapter** to bridge incompatible interfaces.
- Use **Decorator** to add composable responsibilities without changing the
  wrapped implementation.
- Use **Facade** to expose a narrow interface over a complex subsystem.

Read [references/structural.md](references/structural.md) when the problem is
primarily about composition, wrapping, or interface boundaries.

## Analyze Trade-offs

Before recommending or applying a pattern:

- Identify the coupling, duplication, conditional growth, lifecycle issue, or
  change axis being addressed.
- Explain why a direct function, module, interface, or composition is
  insufficient.
- Account for added abstractions, indirection, debugging cost, and onboarding
  cost.
- Check ownership and cleanup for observers, decorators, commands, and
  snapshots.
- Avoid speculative extension points that have no current consumer.

If the evidence does not justify a pattern, recommend the simpler design and
say what future pressure would justify revisiting the decision.

## Implement in the Repository's Language

Treat the bundled TypeScript examples as conceptual references. Adapt names,
interfaces, ownership, error handling, and test style to the repository's
language and conventions. Do not introduce TypeScript or object-oriented
classes into a codebase solely because the examples use them.

When changing code:

1. Keep the change within the user's requested scope.
2. Preserve public behavior unless a behavior change is requested.
3. Add or update tests around the design pressure and failure modes.
4. Prefer incremental migration over a broad rewrite.
5. Remove obsolete branches or abstractions only when their replacement is
   verified.

## Common Failure Modes

- Pattern for pattern's sake: use the direct solution.
- Singleton as service location: inject the dependency.
- Deep decorator chains: simplify composition or introduce an explicit
  pipeline.
- Factory with one stable product: instantiate directly.
- Observer without unsubscribe or ownership: define lifecycle cleanup.
- State pattern for a tiny fixed conditional: keep the conditional.
- Pattern stacking: solve one design pressure at a time.

## Verify

- Confirm the original problem is reduced rather than relocated.
- Confirm responsibilities and ownership are clear.
- Confirm the implementation follows existing codebase conventions.
- Run focused tests, then broader validation when the change warrants it.
- Review modified files for regressions, security issues, uncovered edge cases,
  and missing tests.
- Report remaining trade-offs and any unverified assumptions.

## References

- [Creational patterns](references/creational.md)
- [Structural patterns](references/structural.md)
- [Behavioral patterns](references/behavioral.md)
- [Refactoring.Guru pattern catalog](https://refactoring.guru/design-patterns/catalog)

Adapted for Codex from the original MIT-licensed LobeHub package.
