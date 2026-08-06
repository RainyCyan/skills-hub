Git Worktrees for AI Coding Agents: Isolated, Reviewable Parallel Work
May 20, 2026
·
8 min read

Git worktrees for AI coding agents solve a specific, painful problem: when several agents work in one checkout, they overwrite each other’s edits and the combined diff becomes impossible to trust. A worktree gives each agent its own checkout of the same repository on its own branch — isolated, reviewable, and safe to run in parallel.

Worktrees aren’t an AI feature; they’re a general git technique that happens to map perfectly onto parallel agent work. This guide teaches worktrees from scratch — what they are, the mental model, the actual commands — and then shows why they’re the right foundation for running more than one agent at a time.

What a git worktree actually is
By default a git repository has exactly one working directory: the folder you cloned into. To work on a different branch, you git checkout it, which rewrites the files in that one folder. That’s fine for one person doing one thing. It falls apart the moment you want two pieces of work checked out at once.

A worktree is an additional working directory attached to the same repository, each on its own branch. One repository, many checkouts. Every worktree is a real folder you can edit, build, test, and commit in — but they all share the same underlying .git object store, so you’re not cloning the repo again and you’re not paying for a second copy of the history.

The mental model: instead of one desk where you swap out the papers every time you change tasks, you get several desks, each with one task laid out and ready, all drawing from the same filing cabinet.

The commands you actually need
Worktrees are a small, sharp part of git. Four commands cover almost everything.

Create a worktree
The core command makes a new directory and checks out a branch into it. The -b flag creates the branch at the same time:

# create ../feature-x as a new worktree on a new branch feature-x
git worktree add ../feature-x -b feature-x

# or check out an existing branch into a new worktree
git worktree add ../hotfix hotfix
Pointing worktrees at sibling directories (../feature-x) keeps them next to your main checkout but cleanly separate from it.

List your worktrees
See every worktree attached to the repo, where it lives, and which branch it’s on:

git worktree list

# /path/to/repo          a1b2c3d [main]
# /path/to/feature-x     e4f5g6h [feature-x]
# /path/to/hotfix        i7j8k9l [hotfix]
Remove a worktree
When you’re done, remove the working directory. Delete the branch afterward if you don’t need it:

git worktree remove ../feature-x
git branch -d feature-x
Prune stale references
If a worktree’s folder was deleted by hand, git still holds a stale reference to it. Clean those up with:

git worktree prune
Why this maps perfectly onto parallel agents
Once you have worktrees in your head, the fit with agentic coding is obvious. The three problems that wreck parallel agent work — collisions, untrustworthy diffs, and risky experiments — are exactly the problems worktrees were built to solve:

Isolation. Each agent gets its own checkout, so two agents editing files at the same time can never overwrite each other. No coordination, no clobbering.
Reviewable per-agent diffs. Because each agent works on its own branch in its own folder, its changes are a clean, self-contained diff you can read and judge on its own merits — instead of one tangled diff from several agents mashed together.
Safe to run in parallel. With no shared files in play, you can launch several agents at once and let them all run flat out without worrying about who’s touching what.
Easy to throw away. If an agent goes down a bad path, you delete its worktree and branch and you’re back to a clean slate. Cheap experiments are the whole point — you want to be able to try a risky approach and discard it without a trace.
This is why a worktree-per-agent setup is the backbone of running multiple AI coding agents in parallel. The agents stay out of each other’s way, and you stay in control of what actually merges.

A worktree-per-agent workflow
In practice the loop is short. For each task you want to hand off:

Spin up a worktree on a fresh branch: git worktree add ../task-name -b task-name.
Point an agent at it. Launch the agent with that directory as its working directory so every edit it makes lands on that branch.
Let it run alongside your other agents in their own worktrees, with nothing shared between them.
Review the branch’s diff on its own, merge it if it’s good, and git worktree remove it when you’re done — or throw it away if it isn’t.
How Kadro ADE handles the isolation for you
Doing this by hand works, but you end up managing a pile of directories and remembering which terminal points where. An agentic development environment can take that on so the isolation is automatic rather than a chore.

Kadro ADE can give each agent its own worktree, so parallel work stays isolated and reviewable without you wiring up directories by hand. It runs Claude Code, Codex, opencode, and 20+ coding agents on the desktop, each in a real terminal pane, so you can watch several isolated sessions side by side and read each branch’s diff before anything reaches your main branch. The agents stay out of each other’s way; you keep the final say on what merges.

Frequently asked questions
What is a git worktree?
A git worktree is an additional working directory attached to the same repository, checked out to its own branch. One repo, many checkouts. You get a real folder on disk you can edit, build, and commit in, without cloning the repo again — and without the branch-switching dance that a single checkout forces on you.

Why are git worktrees good for AI coding agents?
Because parallel agents that share one checkout overwrite each other and produce a diff you can't trust. Give each agent its own worktree and its own branch, and their edits never collide, each agent's diff is reviewable on its own, the work is safe to run in parallel, and anything that didn't pan out is easy to throw away.

How do I remove a git worktree when I'm done?
Run git worktree remove <path> to delete the working directory, then delete the branch if you don't need it. If a worktree's folder was deleted manually, git worktree prune cleans up the stale references. Worktrees are cheap to create and cheap to discard, which is exactly what you want for throwaway agent experiments.

Do worktrees use a lot of disk space?
Far less than a full clone. All worktrees share the same .git object store, so you're only paying for the checked-out files in each one, not a second copy of the entire history. That's what makes spinning up a worktree per agent practical.

Worktrees are the cleanest way to keep parallel agents from stepping on each other — and the easiest way to keep their work reviewable before it lands. Download Kadro ADE to run isolated agents side by side, or see the docs for setup.
