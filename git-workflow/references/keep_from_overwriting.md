How to keep multiple coding agents from overwriting each other
May 3, 2026
•
5 min read
Running one AI coding agent on a repo feels like pair programming. Running three or five agents on the same repo can feel like a merge conflict factory if they all share the same checkout. One agent changes branches, another edits the same file, a third runs a cleanup command, and suddenly nobody knows which diff belongs to which task.

The fix is not a bigger prompt. The fix is a workflow. I treat agents like fast junior developers with shell access: useful, but they need boundaries.

The short version
Use one Git worktree per agent.
Use one branch per task.
Give every agent a clear file or module ownership boundary.
Put shared repo rules in AGENTS.md, CLAUDE.md, or both with a symlink.
Block destructive Git commands unless a human approves them.
Merge through pull requests with CI and branch protection.
That is enough structure for most parallel agent work.

Why a shared checkout breaks down
A normal Git checkout has one working tree, one index, and one current branch. That is fine for one developer or one agent. It gets messy when multiple agents act at the same time.

If Agent A is halfway through an auth refactor and Agent B runs git checkout main, Agent A's workspace just changed under its feet. If Agent C runs git reset --hard, uncommitted work can disappear. Even harmless commands like git stash pop can mix unrelated changes together.

You can tell agents not to do those things, and you should. But filesystem isolation is stronger than trust.

Use Git worktrees for isolation
Git worktrees let one repository have multiple working directories attached to the same history. Each directory can be on its own branch, while sharing the same object database. You avoid the cost and confusion of cloning the repo five times, but each agent still gets its own files.

git fetch origin
git worktree add ../site-auth -b agent/auth-refactor origin/main
git worktree add ../site-billing -b agent/billing-fix origin/main
git worktree add ../site-tests -b agent/test-coverage origin/main
git worktree list
Then start one agent inside each directory. Agent A works in ../site-auth. Agent B works in ../site-billing. Agent C works in ../site-tests. They can run tests, edit files, and create commits without changing each other's checkout.

This is also the pattern Claude Code documents for parallel sessions: separate worktrees, separate branches, and isolated edits. Anthropic's help docs go further and describe worktree-backed parallel sessions as a common power-user workflow for running several Claude sessions at once.

Give every agent an owned surface
Worktrees solve file-level collision. They do not solve product-level conflict. Two agents can still make incompatible decisions if the task is vague.

Before I start agents in parallel, I split the work by ownership. Not just by file names, but by responsibility.

You own src/auth/** and tests/auth/**.
Do not edit files outside that scope.
Do not change public API shapes without stopping first.
Run the auth tests before reporting done.
Open a PR with a focused summary.
That prompt is boring, which is exactly why it works. Agents need boring boundaries more than clever prose.

The best splits are along natural module lines: auth, billing, search, docs, UI components, migrations, tests. The worst split is giving two agents overlapping ownership of the same service and hoping Git figures it out later.

Use AGENTS.md and CLAUDE.md as shared rules
Repo instructions should live in the repo, not just in a chat window. CLAUDE.md is the convention Claude Code reads. AGENTS.md is a more general convention for coding agents. If you use both tools, keep one source of truth and symlink the other name to it.

ln -s CLAUDE.md AGENTS.md
That file should include the repo's build commands, test commands, deploy notes, style rules, and any hard restrictions. For example: do not edit generated files, do not touch migrations without approval, use npm run lint before handoff, or keep blog code blocks on one HTML line with <br/> tags.

The point is simple: every agent should start with the same local context.

Make dangerous Git commands explicit
I do not let agents improvise with destructive Git. These commands are useful in a human-controlled terminal, but risky in autonomous work:

git reset --hard
git checkout .
git clean -fd
git push --force
git stash pop
My default rule is: read freely, write narrowly, and ask before destructive Git. Agents can run git status, git diff, git log, and normal commits. They should not discard work, force push, or move another branch unless the task explicitly requires it.

Use pull requests as the handoff point
Do not merge agent work by copying files between folders. Make each agent produce a branch and a pull request.

git status
git diff
npm test
git add src/auth tests/auth
git commit -m auth-refactor
git push origin agent/auth-refactor
gh pr create
On GitHub, branch protection rules can require pull request reviews, status checks, linear history, and merge queues. Those controls matter more when agents can generate code quickly. Speed is only useful if main stays trustworthy.

I like small agent PRs. A focused 200-line diff is reviewable. A 4,000-line mixed refactor is where bugs hide.

Merge in dependency order
If Agent A changes an API and Agent B consumes that API, merge A first. Then rebase B onto the updated base branch and let B resolve its own conflicts.

git fetch origin
git rebase origin/main
npm test
This keeps the mental model clean. The agent that owns the dependent work is responsible for adapting to the new base. The human reviewer sees one coherent PR at a time.

The workflow I would use tomorrow
Update main.
Create one worktree and branch per agent task.
Start each agent inside its own worktree.
Give each agent a written ownership boundary.
Make each agent run the relevant tests.
Push each branch and open a PR.
Review, merge in dependency order, then remove finished worktrees.
git worktree remove ../site-auth
git branch -d agent/auth-refactor
Multiple coding agents can work on the same codebase. They just should not work in the same checkout. Use Git for isolation, pull requests for review, and repo-level instruction files for shared rules. That gives you parallel speed without turning the repo into a pile of mystery diffs.
