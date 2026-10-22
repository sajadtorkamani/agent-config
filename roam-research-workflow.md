# Roam Research workflow

Notes on how I use Roam Research while writing code and working on features.

## Todo items

- A Roam todo item is a block that starts with `{{[[TODO]]}}` (or the short form `{{TODO}}`), Roam's equivalent of a markdown `- [ ]` checkbox. A done item starts with `{{[[DONE]]}}`, the equivalent of `- [x]`.
- When an item is finished, or moved out of an in-progress block (e.g. from `IN PROGRESS` to `QA` or `DONE`), change `{{[[TODO]]}}` or `{{TODO}}` to `{{[[DONE]]}}`. Do the same for any todo sub-items that came with it. Leave the rest of the block's text as it is.
- Only change items that are todo items. Plain blocks without a todo marker stay as they are.

## Task pages

- I manage tasks with the `Task` template on the `Templates` page. Each task page has `Notes`, `Links` and `Subtasks` blocks, and `Subtasks` has one child block per status: `DONE`, `QA`, `IN PROGRESS` and `TODO`.
- I break a task down into small subtasks, each a block under one of those status blocks. A subtask's child blocks (sub-steps, screenshots, notes) belong to it and move with it.
- The `TODO` block ends with a `---` divider followed by my standard wrap-up steps (tests, QA, tidying the diff, summary). Feature subtasks go above the divider.

## Moving a subtask to QA

- When I ask you to move something to QA, move that subtask (with its child blocks) from `TODO` or `IN PROGRESS` to the end of `QA`.
- Then mark it and any todo sub-items done, as described in [Todo items](#todo-items).

## Roam API

- Call the Roam backend API with `~/code/agent-config/scripts/roam-api.sh`. It reads the token from `~/.config/roam/token` and only puts it in the request header. Never print the token or the contents of `~/.config/roam/`.
- Pass the graph name first, e.g. `roam-api.sh -g <graph> outline "<page title>"`. My private instructions name the graph to use.
- `outline "<page title>"` prints a page as an outline, with each block's uid in square brackets.
- `write <body.json>` sends writes. Send a run's changes as one `{"action": "batch-actions", "actions": [...]}` body. The actions:
  - `{"action": "create-block", "location": {"parent-uid": "<uid>", "order": "last"}, "block": {"string": "...", "uid": "<optional 9-character uid>"}}`. Give a new block a uid when you need to add children under it in the same batch.
  - `{"action": "update-block", "block": {"uid": "<uid>", "string": "..."}}`
  - `{"action": "delete-block", "block": {"uid": "<uid>"}}`, which also deletes the block's children.
- `q <body.json>` runs a Datalog query: `{"query": "[:find ...]", "args": [...]}`.
- Fetch a page again just before writing to it, since I may have edited it in the meantime, and read it back afterwards to check the result.

## QA results

When I ask you to QA items (see the `qa-roam-tasks` skill), record the result under each top-level item in `QA` as a child block:

```
- {{[[DONE]]}} <the QA item>
  - QA result: Passed ✅
    - Evidence
      - <each step you took to check it, with the data you used and what you saw>
```

- The statuses are:
  - `QA result: Passed ✅`: you saw it work, in the app or through a test or API call that covers it.
  - `QA result: Failed ❌`: under `Evidence`, the steps that led to the failure, what you expected and what happened.
  - `QA result: Partly verified 🟡`: you could only check part of it (e.g. no local data for a case). Say what's unchecked and the smallest change that would let me check it.
  - `QA result: Problematic task ⚠️`: the item doesn't make sense, contradicts a later decision or is out of date with the code. Use a `Why` child instead of `Evidence`, saying why and suggesting a rewrite.
- Say how each step was checked when it wasn't in the app, e.g. "checked with the RQ-API test `testPaginates`".
- An item has at most one `QA result` block. When QAing again, update it and replace its `Evidence` or `Why` child rather than adding another.
