---
name: plan-linear-issue
description: Propose an implementation plan for a Linear issue — reads the issue, its sub-issues and comments, studies the codebase, drafts a plan that says how each sub-issue will be built, and after the user approves it posts the plan as a single comment on the given issue (editing its earlier plan comment if there is one). Use when the user runs /plan-linear-issue <issue ID or URL>.
argument-hint: <issue ID or URL, e.g. SAJ-18>
disable-model-invocation: true
---

# Plan Linear issue

The user writes requirements in Linear as a parent issue for the feature, usually with a
sub-issue for each behaviour or edge case (often agreed in `/review-linear-issue`). Turn those
requirements into an implementation plan and post it as a comment on the issue, so whoever
builds it (the user or an agent) has an agreed plan to follow.

This is planning, not building. Don't write code, create branches or change the issue itself.
The only change to Linear is the plan comment, made once the user approves it (step 5).

## Steps

1. **Get the issue.** Take the issue ID (e.g. `SAJ-18`) or URL from the arguments. For a URL
   such as `https://linear.app/<workspace>/issue/SAJ-18/<slug>`, the ID is the segment after
   `/issue/`. If there isn't one, ask for it and stop. Using the Linear MCP tools, fetch:
   - the issue (`get_issue`, with relations), including its project
   - its sub-issues (`list_issues` with `parentId`), and their sub-issues if they have any
   - comments on the issue and sub-issues (`list_comments`), including any earlier plan
     comment (see step 5)
   - images in descriptions (`extract_images`), if any. Mockups often hold requirements.
   - the parent issue, if the given issue is itself a sub-issue, for context

   The plan covers the given issue only. If it's a parent, plan it and every sub-issue under
   it. If it's a sub-issue, plan just that sub-issue (and any sub-issues of its own), using the
   parent for context.

2. **Find the codebase.** Check that the current repo matches the issue's Linear project (e.g.
   by its name, remote or README). If it doesn't, or you can't tell, ask the user for the repo
   path before going on.

3. **Study the code.** Find the code behind the feature or page the issue touches, the
   conventions nearby (how similar features are structured, named and tested), and anything
   the change could affect. Read enough to name the actual files and functions the plan will
   change. Check every claim in the plan against the code.

   If a requirement is unclear or contradicts another, don't guess. Ask the user, and suggest
   running `/review-linear-issue` first if there are several open questions.

4. **Draft the plan.** Write it in Markdown for a Linear comment, in this shape:

   ```markdown
   ## Implementation plan

   <2–4 sentences: the overall approach and why, and any decision every sub-issue relies on.>

   ### Shared changes
   <Changes that several sub-issues build on, e.g. a helper or data the page needs. Leave this
   section out if there are none.>

   ### SAJ-19: <sub-issue title>
   <How it'll be built: what changes, in which files (`path/to/file.php`), and anything to
   watch out for. A few bullets, not code.>

   ### SAJ-20: <sub-issue title>
   ...

   ### Testing
   <How the change will be checked: automated tests to add or run, and the manual checks
   (browsers, devices, edge cases).>

   ### Order of work
   <Only if the order matters, e.g. which sub-issues depend on the shared changes.>
   ```

   - Give every sub-issue its own section, in a sensible build order, headed by its ID and
     title. If one sub-issue falls out of another's work with nothing extra to build, still
     give it a section and say so in a line.
   - Name real files, functions and existing helpers to reuse. Reference files by repo-relative
     path, not `file:line`, since line numbers drift.
   - Keep it at the level of a plan: what and where, not the code itself. A short snippet is
     fine only when it's the clearest way to pin down an interface or a tricky bit.
   - Be decisive. Where there's a real choice, pick one and give the reason in a clause. List
     anything the plan assumes that the issue doesn't say under a final `### Assumptions`.

5. **Show it, then post it.** Show the user the full plan in the terminal and ask whether to
   post it. Change it as they ask and show it again. Post only once they approve.
   - Post it with `save_comment` on the issue from step 1, never on its sub-issues or parent.
   - If the issue already has a plan comment (a comment starting with `## Implementation plan`
     that the user wrote, or that was posted on their behalf), edit that comment instead of
     posting a new one (`save_comment` with its `id`), so the issue has one current plan. Say in the preview that you'll be
     replacing it.
   - Reply with the comment's link.

## Rules

- Read-only (code and Linear) until the user approves posting the plan in step 5.
- Don't change the issue or its sub-issues (titles, descriptions, status, assignee, priority,
  labels). If planning shows a requirement should change, tell the user instead.
- Post one comment on the given issue, covering every sub-issue in it.
