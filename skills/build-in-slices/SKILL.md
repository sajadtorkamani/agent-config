---
name: build-in-slices
description: Build a large change as a numbered list of small slices - show the list first, then do one slice at a time, keeping the tests passing and stopping to report after each. Only runs when the user types /build-in-slices [task].
disable-model-invocation: true
---

# Build in slices

Build a large change as small slices the user can review one at a time, instead of in one go.

The task is the arguments passed to /build-in-slices. If there are none, use the task already
agreed in the conversation. If there isn't one, ask what to build.

## 1. Plan the slices

Don't write any code yet.

1. Read enough of the code to know what the change touches.
2. Split the work into small numbered slices. Each slice must:
   - leave the tests passing, so the work could stop after any slice
   - be reviewable on its own, with one purpose that fits in a sentence
   - come before any slice that depends on it
3. Show the list. For each slice give one line on what it does.
4. Say up front if a slice will leave something broken until a later slice (for example the
   frontend while the API changes), and offer a different order if that would avoid it.
5. Wait for the user to agree the list before starting. They may reorder, merge or cut slices.

If the work turns out to fit in one small slice, say so and just do it.

## 2. Build one slice at a time

For each slice:

1. Do only that slice. If you find something that belongs to a later slice, leave it for that
   slice. If you find something the list missed, add a slice and say so.
2. Test it: run the tests the slice touches, and add tests for new behaviour.
3. Stop and report:
   - what changed, with the key files
   - what you tested and the result, including anything you couldn't test
   - anything the user needs to decide
   - which slice is next
4. Don't start the next slice until the user says so.

## Rules

- Don't commit unless the user asks. If they want commits, make one per slice.
- If a slice can't be finished with the tests passing, stop and say why instead of carrying
  the breakage into the next slice.
- Keep the numbered list up to date. When a slice is added, split or dropped, show the new
  list in the next report.
