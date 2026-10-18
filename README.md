# agent-config

My personal config for coding agents: global instructions and skills. Not tied to one tool. It currently sets up [Claude Code](https://claude.com/claude-code) and [Codex](https://github.com/openai/codex), and other agents can be added.

## Install

```bash
git clone git@github.com:sajadtorkamani/agent-config.git ~/code/agent-config
~/code/agent-config/install.sh
```

`install.sh` symlinks each folder in `skills/` into `~/.claude/skills/`, `CLAUDE.md` into `~/.claude/CLAUDE.md`, and `AGENTS.md` into `~/.codex/AGENTS.md` (for Codex), so edits here take effect immediately. Re-run it after adding a new skill.

## AGENTS.md and CLAUDE.md

`AGENTS.md` holds the global instructions for every project on this machine, in the [AGENTS.md](https://agents.md) format that most coding agents read. Codex reads it directly. Claude Code doesn't read `AGENTS.md` itself, so `CLAUDE.md` just imports it (`@~/code/agent-config/AGENTS.md`). Edit `AGENTS.md`, not `CLAUDE.md`.

## Private instructions and skills

Work-specific instructions and skills live in a separate private repo, `agent-config-private`, cloned next to this one at `~/code/agent-config-private`. It's optional: without it, everything here works the same.

- `CLAUDE.md` also imports `~/code/agent-config-private/AGENTS.md`. Claude Code skips the import if the file isn't there.
- `install.sh` symlinks the private repo's `skills/` into `~/.claude/skills/` too.
- Codex doesn't support imports, so when the private repo is present, `install.sh` writes `~/.codex/AGENTS.md` as a merged copy of both `AGENTS.md` files instead of a symlink. Re-run `install.sh` after editing either one so Codex picks up the change.

## Skills

The skills are written for Claude Code.

- `address-pr-comment`: takes a pasted PR review comment, checks whether it's worth fixing (asks first for edge cases), fixes it in a worktree on a `<branch>--patch-<slug>` branch, opens a draft PR into the original PR's branch, and replies on the comment with the patch link and again once it's merged.
- `commit`: commits changes with a concise title (≤72 chars) and an optional description.
- `commit-and-push`: runs `commit`, then pushes the branch to the remote.
- `delegate-task`: does a task end to end in a throwaway worktree, then opens a draft PR into the branch you pick — assigned to you, with the description already written, and AI reviews requested via `request-reviews`.
- `explain-review-comment`: takes a pasted PR review comment (usually a screenshot), checks it against the code, says whether it's a real issue in plain terms, and offers a fix.
- `pr-summary`: asks for the base branch and any related PRs, then summarises the branch's commits as markdown for the GitHub PR description.
- `request-reviews`: gets AI reviews on a PR: comments `@codex review`, requests Copilot, and runs Claude's `/code-review` with comments prefixed `🤖 Claude (<model>):` (or a "no major issues" comment when it finds nothing). Re-run it after pushing fixes.
- `review-handoff`: asks for the base branch, then writes a review prompt for another agentic CLI (Codex, Gemini CLI, a fresh Claude Code session) to run in the same checkout, and triages the findings you paste back.
- `review-linear-issue`: reviews a Linear issue's requirements (with its sub-issues and comments) against the codebase before planning, asks about anything unclear, flags clashes with existing functionality, and offers to write the answers back to Linear. Only runs when invoked with `/review-linear-issue <issue>`.
- `summarise-changes`: recaps the uncommitted work and unpushed commits in the current repo, for when you've lost track of what you were doing.
