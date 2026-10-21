---
name: grill-me-before-starting-roam-task
description: Before implementing the current 'IN PROGRESS' item on a Roam task page (my 'Task' template), check whether it makes sense, ask about anything ambiguous however small, then describe the plan with the assumptions behind it. Use when the user runs /grill-me-before-starting-roam-task, or asks to be grilled / questioned about the in-progress Roam item before starting it.
---

# Grill me before starting a Roam task

Before writing any code for the current `IN PROGRESS` item on a Roam task page, tell me
whether it makes sense, ask about anything unclear, and then describe the plan with every
assumption behind it. Don't implement it in this skill: stop once the plan is described, and
wait for me to say go.

Follow `~/code/agent-config/roam-research-workflow.md` for how task pages and todo items work.

## Steps

1. **Find the task page.** Use the Roam task page already discussed in this session: one
   built from the `Task` template, with `DONE`, `QA`, `IN PROGRESS` and `TODO` blocks under
   `Subtasks`.
   - If no such page has come up in this session, say so and stop. Don't guess which page I
     mean, and don't search the graph for one.

2. **Re-read the `IN PROGRESS` block.** Fetch the page again rather than relying on an earlier
   read, since I may have moved or edited items since. Read every child block under the
   in-progress item, including notes and screenshots (download and look at the images).
   - If `IN PROGRESS` is empty, or has more than one item and it's unclear which I mean,
     say so and ask.

3. **Check it against the code.** Look at the code the item touches before judging it, so the
   questions are grounded. Note where the item's wording doesn't match the code, e.g. field,
   class or method names that differ, or a suggested approach that would be slow or awkward.

4. **Answer two questions:**
   - **Does it make sense?** Say plainly whether it does, and summarise how you'd build it.
   - **Is anything ambiguous?** List every point that needs a decision, even small ones
     (naming, edge cases, empty states, rounding, permissions, which date or status to use).
     Don't hold back a question because it seems minor.

5. **Ask.** Put the questions that need my call in `AskUserQuestion`: up to 4 per call, each
   with a recommended option first.

6. **Describe the plan.** Once I've answered, restate what we agreed in a short list, then
   list the **assumptions you're making about the implementation** that I should know about,
   under a heading like "Defaults I'll use unless you say otherwise:".
   - Number them, each with a short bold label and one or two plain sentences, e.g.
     "**Where the box lives:** I'll move it from the page into the table component, which
     knows whether there's any data. A side effect is that it won't show during the first
     load."
   - Cover anything you'd otherwise decide silently: styling, which existing component or
     pattern you'll reuse, where new code goes, how existing behaviour changes, side effects
     and trade-offs, edge cases, and how you'll check it works (including which local data or
     company you'll test with).
   - Only list real choices. Skip anything the item or my answers already settle.

## Rules

- Don't change code, Roam, or anything else in this skill. It's questions and a plan only.
- Don't move the item between status blocks.
