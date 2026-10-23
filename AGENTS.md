# Global instructions

Personal instructions that apply to every project on this machine.

## General coding style
- Prefer longer descriptive names for variables, functions, etc over shorter, cryptic names. Avoid single-letter variable names.

## Pull requests

- Write PR descriptions for non-technical readers first, in this order:
  1. `## Summary`: a few plain-language lines on what the change lets people do
     and why, with the ticket link and any deploy order (e.g. "deploy the API PR
     first").
  2. A `<details open>` toggle titled "What's changing": the behaviour changes
     from the user's point of view. No class, component, endpoint or field
     names here.
  3. A `<details>` toggle (collapsed) titled "Implementation details": how it
     works, key files and components, API fields, error codes, decisions made,
     migrations, tests run, and cleanup after merging (e.g. a screenshots branch).
  4. `## Related`: the ticket and any linked PRs.
- Leave a blank line after each `<summary>` line and before `</details>` so the
  markdown inside renders.
- Screenshots are optional. Only add them when I ask or provide them, each with
  a one-line plain-language caption, and don't say how they were produced (e.g.
  a temporary Storybook story or sample data).
- When a PR depends on another PR, use the same "What's changing" content in
  both.

## GitHub comments

- Prefix every comment I post on GitHub (PR comments, review replies, issue
  comments) with `🤖 Claude (<model>): `, e.g. `🤖 Claude (Opus 5.5): Fixed in abc123.`,
  so it's clear Claude wrote it even though it posts under my account.

## React
- Always write in TypeScript instead of plain JavaScript where possible and ensure it aligns with the project's tsconfig.json.
- Avoid React.useEffect if possible as it easily introduces bugs and makes the code harder to reason about. See https://react.dev/learn/you-might-not-need-an-effect.
- Prefer the `function foo()` syntax over `const foo = () => {}` for regular functions and hooks. React components are the exception: declare them as `const Foo: React.FC<Props> = (...) => ...` so they can use the `React.FC` type.
- Prefer `{condition && <Component />}` over ternaries where the false branch would be `null`.
- When a component shows exactly one of several states (e.g. error, empty or content), render each state with an early return instead of sibling `{condition && ...}` blocks, so it's clear only one can render. Check the states in order: error, then empty, then content. If the states sit inside a larger component, extract them into a sub-component rather than an inline `renderX()` function. Keep `{condition && <Component />}` for optional pieces that can appear alongside other content.

## Next.js
- Put components used by only one route in a `components` folder next to its `page.tsx`, e.g. `app/shopping-list/components/add-item-form.tsx`. Keep `page.tsx` and the route's other special files (e.g. `layout.tsx`) in the route folder itself. Folders under `app/` without a `page` or `route` file aren't routable, so no underscore prefix is needed.
- Put each server action in its own file in an `actions` folder next to the route that uses it, named after the action in kebab case, e.g. `app/shopping-list/actions/add-shopping-list-item.ts` for `addShoppingListItem`. Don't group several actions in one `actions.ts`.
- Keep only server actions in the `actions` folder. Put helpers and types the actions share (e.g. input parsing, form state types) in a `helpers.ts` next to the folder, e.g. `app/shopping-list/helpers.ts`. A `'use server'` file can only export async functions anyway.
- Import each action from its own file rather than through an `index.ts` that re-exports them.

## TypeScript
- Avoid any return types.
- Don't add `void` return types for functions that don't return anything.
- Prefer a truthy check over `!== null` / `!== undefined` when the value can't be falsy in any other way, e.g. `if (summary)` for an object. Keep the strict comparison for strings, numbers and booleans, where `''`, `0` or `false` would be skipped by mistake.
- When code passes or compares a value of a string union type defined in the project, reference a `Record<Type, Type>` constant instead of a string literal, adding one if it doesn't exist (e.g. `useIsBreakpoint(BREAKPOINTS.md)`, not `useIsBreakpoint('md')`).

## PHP / Symfony

- No Yoda conditions — write `if ($status === self::ACTIVE)`, not `if (self::ACTIVE === $status)`.
- Avoid nesting array functions (e.g. `array_values(array_filter(...))`, `usort` on the result of `array_map`) as they're hard to read. Use a chained collection instead:
  - Prefer Doctrine collections (`$entity->getItems()->filter(...)->map(...)->getValues()`, or `new ArrayCollection($array)` for a plain array).
  - Fall back to Illuminate's `collect()` only when the project has `illuminate/collections` and Doctrine can't do it (e.g. sorting with `sortBy()`).
  - A single array function on its own (e.g. one `array_map`) is fine.
- Don't escape single quotes inside single-quoted strings — use a double-quoted string instead, e.g. `"You don't have permission"`, not `'You don\'t have permission'`.
- In `#[Groups([...])]` attributes, put each group on the line directly after the previous one, with no blank lines between them. When adding a group to an existing list, don't add blank lines around it, and remove any blank line between the groups either side of it.
- Prefer a truthy check over comparing with `null` when the value can't be falsy in any other way, e.g. `if ($invitedFrom)` for a `?\DateTimeImmutable`, not `if ($invitedFrom !== null)`. It's quicker to read. This is safe for nullable objects and arrays of objects. Keep the strict comparison when a falsy value is a real value that would be skipped by mistake: strings (`'0'` and `''`), integers and floats (`0`), booleans and arrays (`[]`), e.g. `if ($search !== '')`, `if ($count !== null)`.

## Python
- Always add type hints to functions and variables.

## Roam Research
- When reading or editing my Roam Research graph, follow the workflow notes in `~/code/agent-config/roam-research-workflow.md`.
