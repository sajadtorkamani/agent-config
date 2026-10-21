# Roam Research workflow

Notes on how I use Roam Research while writing code and working on features.

## Todo items

- A Roam todo item is a block that starts with `{{[[TODO]]}}` (or the short form `{{TODO}}`), Roam's equivalent of a markdown `- [ ]` checkbox. A done item starts with `{{[[DONE]]}}`, the equivalent of `- [x]`.
- When an item is finished, or moved out of an in-progress block (e.g. from `IN PROGRESS` to `QA` or `DONE`), change `{{[[TODO]]}}` or `{{TODO}}` to `{{[[DONE]]}}`. Do the same for any todo sub-items that came with it. Leave the rest of the block's text as it is.
- Only change items that are todo items. Plain blocks without a todo marker stay as they are.

## Task pages

- I manage tasks with the `RQ task` template on the `Templates` page. Each task page has `Notes`, `Links` and `Subtasks` blocks, and `Subtasks` has one child block per status: `DONE`, `QA`, `IN PROGRESS` and `TODO`.
- I break a task down into small subtasks, each a block under one of those status blocks. A subtask's child blocks (sub-steps, screenshots, notes) belong to it and move with it.
- The `TODO` block ends with a `---` divider followed by my standard wrap-up steps (tests, QA, tidying the diff, summary). Feature subtasks go above the divider.

## Moving a subtask to QA

- When I ask you to move something to QA, move that subtask (with its child blocks) from `TODO` or `IN PROGRESS` to the end of `QA`.
- Then mark it and any todo sub-items done, as described in [Todo items](#todo-items).
