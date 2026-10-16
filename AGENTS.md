# Global instructions

Personal instructions that apply to every project on this machine.

## General coding style
- Prefer longer descriptive names for variables, functions, etc over shorter, cryptic names. Avoid single-letter variable names.

## React
- Always write in TypeScript instead of plain JavaScript where possible and ensure it aligns with the project's tsconfig.json.
- Avoid React.useEffect if possible as it easily introduces bugs and makes the code harder to reason about. See https://react.dev/learn/you-might-not-need-an-effect.
- When a component shows exactly one of several states (e.g. error, empty or content), render each state with an early return instead of sibling `{condition && ...}` blocks, so it's clear only one can render. Check the states in order: error, then empty, then content. If the states sit inside a larger component, extract them into a sub-component rather than an inline `renderX()` function. Keep `{condition && <Component />}` for optional pieces that can appear alongside other content.

## TypeScript
- Avoid any return types.

## PHP / Symfony

- No Yoda conditions — write `if ($status === self::ACTIVE)`, not `if (self::ACTIVE === $status)`.
- Avoid nesting array functions (e.g. `array_values(array_filter(...))`, `usort` on the result of `array_map`) as they're hard to read. Use a chained collection instead:
  - Prefer Doctrine collections (`$entity->getItems()->filter(...)->map(...)->getValues()`, or `new ArrayCollection($array)` for a plain array).
  - Fall back to Illuminate's `collect()` only when the project has `illuminate/collections` and Doctrine can't do it (e.g. sorting with `sortBy()`).
  - A single array function on its own (e.g. one `array_map`) is fine.
- Don't escape single quotes inside single-quoted strings — use a double-quoted string instead, e.g. `"You don't have permission"`, not `'You don\'t have permission'`.

## Python
- Always add type hints to functions and variables.
