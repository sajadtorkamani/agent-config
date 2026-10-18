---
name: implement-linear-issue
description: Implement a Linear issue and each of its sub-issues — clarifies anything ambiguous first (and offers to write the answers back to Linear), builds it either in the background in a worktree via `delegate-task` (ending in a draft PR) or on the current or a new branch, then posts a comment on each sub-issue saying how it was implemented, its automated tests, how to check it manually and any caveats. Once a PR with the change is open, moves each issue it covers to In Code Review. Use when the user runs /implement-linear-issue <issue ID or URL>.
argument-hint: <issue ID or URL, e.g. SAJ-18>
disable-model-invocation: true
---

# Implement Linear issue

The user writes requirements in Linear as a parent issue for the feature, usually with a
sub-issue for each behaviour or edge case, and often an implementation plan comment from
`/plan-linear-issue`. Build it, then leave a comment on each sub-issue so the user can see how
each one was done and check it for themselves.

## Steps

1. **Get the issue.** Take the issue ID (e.g. `SAJ-18`) or URL from the arguments. For a URL
   such as `https://linear.app/<workspace>/issue/SAJ-18/<slug>`, the ID is the segment after
   `/issue/`. If there isn't one, ask for it and stop. Using the Linear MCP tools, fetch:
   - the issue (`get_issue`, with relations), including its project and `gitBranchName`
   - its sub-issues (`list_issues` with `parentId`), and their sub-issues if they have any
   - comments on the issue and sub-issues (`list_comments`), including any plan comment (one
     starting with `## Implementation plan`) and any earlier implementation comments (step 8)
   - images in descriptions (`extract_images`), if any. Mockups often hold requirements.
   - the parent issue, if the given issue is itself a sub-issue, for context

   The work covers the given issue only. If it's a parent, build every sub-issue under it. If
   it's a sub-issue, build just that one (and any sub-issues of its own), using the parent and
   its plan for context. An issue with no sub-issues is built as a single piece of work.

2. **Find the codebase.** Check that the current repo matches the issue's Linear project (e.g.
   by its name, remote or README). If it doesn't, or you can't tell, ask the user for the repo
   path before going on.

3. **Ask where to build it.** Ask with `AskUserQuestion` (header `Build in`):
   - **Worktree, in the background**: built in a throwaway worktree via the `delegate-task`
     skill, ending in a draft PR. The user's checkout isn't touched.
   - **This checkout**: built on the current branch if it matches the issue, otherwise on a new
     branch from the remote's default branch. No push and no PR.

   Recommend the worktree when the checkout has uncommitted changes or is on an unrelated
   branch, and this checkout otherwise. For the worktree, also ask in the same call which branch
   the PR should merge into, as `delegate-task` would (header `Base branch`, the remote's default
   branch first), because the background agent can't ask later.

4. **Study the code and clarify.** Find the code behind the feature, the conventions nearby (how
   similar features are structured, named and tested) and anything the change could affect.
   If there's a plan comment, check it against the code and follow it.

   Then look for anything that could reasonably be built two ways, contradicts another
   sub-issue, or is a gap the build will have to fill. Also look for any part of the plan the
   code shows won't work. Ask about each one before building, using `AskUserQuestion` for
   questions with clear options (up to 4 per call, recommended option first). Skip anything
   with an obvious default and list that default as an assumption in step 8's comment instead.
   With nothing to ask, go straight on.

5. **Offer to update Linear.** If step 4 settled anything, offer to record it in Linear before
   building, so the issue stays the single source of truth. Prefer sub-issues to adding bullets
   to the parent's description:
   - Add a sub-issue for each agreed behaviour or edge case, titled as the requirement itself.
   - Edit an existing sub-issue when a decision refines or corrects it.
   - Only add to the parent's description what applies to the whole feature and isn't a
     buildable behaviour on its own.

   Show the exact changes and make them only when the user agrees. Don't change status,
   assignee, priority or labels. New sub-issues are part of the work from here on.

6. **Set up the branch.**
   - **Worktree:** launch a background agent (`Agent` with `subagent_type: "fork"`, so it has
     everything gathered so far) that runs the `delegate-task` skill with the base branch from
     step 3. Name the task after the issue (e.g. `SAJ-18 photo keyboard navigation`) so its
     branch becomes `feature/SAJ-18-<slug>`, and tell it to follow steps 7 and 8 of this skill
     for the build and the Linear comments, posting the comments after the PR is open and
     linking the PR in each, then step 9 for the statuses. Tell the user it's running and
     stop. Report back when the agent's notification arrives (step 10).
   - **This checkout:** the current branch matches if its name contains the issue's ID or, for
     a sub-issue, its parent's ID (case-insensitive). Otherwise check the working tree is clean
     (stop and ask if it isn't), then fetch and branch from the remote's default branch
     (`git symbolic-ref --short refs/remotes/origin/HEAD`), naming the branch
     `<type>/<ISSUE-ID>-<slug>` as `delegate-task` does (e.g.
     `feature/SAJ-18-photo-keyboard-navigation`).

7. **Build it.** Follow the repo's conventions and CLAUDE.md, and match the surrounding code.
   - Build the shared changes first, then each sub-issue in a sensible order (the plan's
     order of work, if it has one).
   - Add automated tests for each sub-issue where the project has a test setup and a test is
     worth it. Run the relevant tests, type checks, lint and build, and fix what fails.
   - Commit with the `commit` skill: one commit for the shared changes, then one per sub-issue,
     scoped by that sub-issue's ID (e.g. `feat(SAJ-20): go to the previous photo with the left
     arrow`). A sub-issue with nothing of its own to build gets no commit.
   - Stay inside the issue. Note anything you'd change outside it as a caveat rather than
     changing it.
   - If something comes up mid-build that would change what gets built, stop and ask (in this
     checkout) or pick the most defensible option and note it as a caveat (in the background).

8. **Post the implementation comments.** Once the build is done and committed, post one comment
   on each sub-issue (`save_comment` with its `issueId`) without showing it first. Post on the
   given issue itself instead when it has no sub-issues. When there are shared changes or
   caveats that span the whole feature, also post a short comment on the parent covering just
   those, linking to the sub-issue comments rather than repeating them. Use this shape:

   ```markdown
   ## Implementation notes

   ### Implementation
   <What was done and where: files and line ranges (`path/to/file.php` lines 63–64) and how
   they make the behaviour work. Link the PR, if there is one.>

   ### Automated tests
   <The test file and what it checks. If there's no test, say why (e.g. the project has no
   test setup, or the behaviour is only checkable in a browser).>

   ### How to test manually
   1. <Numbered steps: where to go, what to do, what should happen.>

   ### Caveats
   <Assumptions made, limits, and anything to be aware of. Leave this section out if there
   are none.>
   ```

   - For a sub-issue that fell out of another's work, say so under Implementation and link that
     sub-issue, but still give its own manual steps.
   - If an issue already has an `## Implementation notes` comment from an earlier run, edit it
     (`save_comment` with its `id`) instead of posting another.

9. **Move the issues to In Code Review once there's a PR.** As soon as a PR containing the
   change is open, set the status of every issue it covers to `In Code Review` (`save_issue`
   with `state`): the given issue and each sub-issue built, including ones that fell out of
   another's work. This applies whenever a PR gets opened in the session: by `delegate-task` in
   worktree mode, or later in this checkout when the user asks for one.
   - Look the status up first (`list_issue_statuses` for the issue's team). If the team has
     no `In Code Review` status, don't create one or pick a different status. Tell the user
     and leave the statuses as they are.
   - Leave any issue that's already Done or Canceled alone.
   - Don't change statuses before there's a PR, e.g. after committing in this checkout.

10. **Report.** Briefly: what was built, the branch and commits (or the PR link in worktree
    mode), what was verified and what couldn't be, any caveats, links to the comments
    posted, and which issues moved to In Code Review.

## Rules

- Nothing changes in Linear except the agreed updates in step 5, the comments in step 8 and
  the In Code Review status in step 9. Never change assignee, priority or labels, or any
  other status.
- In this checkout: no push and no PR unless the user asks.
- Ask about ambiguity before building, never after. A background build can't ask, so settle
  everything in step 4 before launching it.
