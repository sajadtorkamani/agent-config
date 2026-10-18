---
name: review-linear-issue
description: Review a Linear issue's requirements before any planning or implementation — reads the issue, its sub-issues and comments, checks them against the codebase, asks about anything unclear or ambiguous, and flags requirements that could break or clash with existing functionality. Offers to write the answers back to Linear. Use when the user runs /review-linear-issue <issue ID or URL>.
argument-hint: <issue ID or URL, e.g. SAJ-18>
disable-model-invocation: true
---

# Review Linear issue

The user writes requirements in Linear before handing them to an agent: a parent issue for the
feature, and often sub-issues for each behaviour or edge case. Review those requirements as a
careful colleague would before anyone starts building: find what's unclear, ambiguous,
contradictory or missing, and anything that could cause problems for the rest of the app.

This is a requirements review, not planning. Don't propose an implementation, write code or
create branches. Only change Linear when the user agrees to it (step 6).

## Steps

1. **Get the issue.** Take the issue ID (e.g. `SAJ-18`) or URL from the arguments. If there
   isn't one, ask for it and stop. Using the Linear MCP tools, fetch:
   - the issue (`get_issue`, with relations), including its project
   - its sub-issues (`list_issues` with `parentId`), and their sub-issues if they have any
   - comments on the issue and sub-issues (`list_comments`)
   - images in descriptions (`extract_images`), if any. Mockups often hold requirements.
   - the parent issue, if the given issue is itself a sub-issue, for context

   Each sub-issue is part of the requirements. Read the titles carefully, as they're often the
   whole requirement.

2. **Find the codebase.** The review needs the code the issue applies to. Check that the
   current repo matches the issue's Linear project (e.g. by its name, remote or README). If it
   doesn't, or you can't tell, ask the user for the repo path before going on.

3. **Understand the current behaviour.** Find the code behind the feature or page the issue
   touches, and anything nearby that the change could affect. If the issue links to a live
   page and looking at it would help, look at it. Read enough to judge the requirements; this
   isn't the planning stage.

4. **Review the requirements.** Look for:
   - **Mistakes**: typos or wording that says something other than what's obviously meant
     (e.g. "the left arrow goes to the next photo"), and sub-issues that contradict each other
     or the parent.
   - **Ambiguity**: requirements that could reasonably be built two ways. Say what the two
     ways are.
   - **Gaps**: cases the issue doesn't cover but the build will have to handle, e.g. empty
     or single-item states, mobile and touch, accessibility, loading and error states, what
     happens at the ends of a list, and whether something should wrap around.
   - **Conflicts**: places where the requirement could break or clash with existing
     behaviour, e.g. a key or gesture the page or browser already uses, shared components
     used elsewhere, routes, SEO, caching or performance. Cite `file:line` for each one.

   Only raise things that would change what gets built or that the user would want to decide.
   Skip nitpicks and things with an obvious default; mention the default you'd assume instead.

5. **Report, then ask.** Keep it short:
   - One bold verdict line: **Ready to implement**, **Ready once the questions below are
     answered**, or **Needs rework** (with why).
   - Short lists under **Mistakes**, **Conflicts with existing functionality** and
     **Assumptions I'd make**. Leave out any list that's empty. Refer to sub-issues by ID.
   - Then ask the open questions. Use `AskUserQuestion` for questions with clear options
     (up to 4 per call, recommended option first) and plain text for open-ended ones.

6. **Offer to update Linear.** Once the user has answered, offer to record the outcome in
   Linear so the issue stays the single source of truth: fix mistakes in titles or
   descriptions, and capture each agreed decision as a sub-issue. Prefer sub-issues to adding
   bullets or paragraphs to the parent's description, so the work is split into small pieces
   that can each be built and checked off:
   - Add a sub-issue for each agreed behaviour or edge case, titled as the requirement itself
     (e.g. "The previous and next photo pages are prefetched so navigation feels instant.").
     Put any detail the title can't hold in its description.
   - Edit an existing sub-issue when a decision refines or corrects it, rather than adding a
     new one that overlaps it.
   - Only add to the parent's description what applies to the whole feature and isn't a
     buildable behaviour on its own (e.g. the ordering that every sub-issue relies on).

   Show the exact changes first and make them only when the user agrees. Don't change status,
   assignee, priority or labels.

## Rules

- Read-only (code and Linear) until the user agrees to the Linear changes in step 6.
- Check claims against the code. Don't flag a conflict you haven't confirmed exists.
- Be decisive: recommend an answer for each question rather than listing options neutrally.
