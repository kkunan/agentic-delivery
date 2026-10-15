# Set up a project

Each repository that uses the plugin adds one project file. This page says what it holds.

Each project adds one file, `.claude/agentic-delivery.md`, which git tracks. It holds the facts of
that project, and the plugin never guesses these values. Its front matter names:

- the platform: `flutter` or `ios`
- the oldest plugin version that the project accepts
- the base branch, the release branch, the branch prefix for features, and the protected branches
- where the specs, plans, ledgers, and retros go: in the repository, or in a private folder that
  the run never commits, such as `~/agentic-notes/<project>`
- the file patterns of the screens, the names of the test processes, and the branch for screenshots
- the forge of the pull request, GitHub or GitLab, and the ticket tracker
- the push times of the feature branch: after each commit, or only at the start of the pull
  request and at ship
- optionally, a prefix such as `Claude said:` for each comment that the run posts with your account
- the mutation runner for the platform
- optionally, your own agent for any of the three seats

Its body has sections for the tracker steps, the devices, the accounts, and the actions that need a
person's word, such as signing and secrets. The key `tracker` names the ticket tracker: Jira, Linear,
GitHub issues, GitLab issues, another tracker that the tracker steps describe, or none. The tracker
steps are in plain words. An optional section, Docs publishing, is for a team with private docs.
It lets the run publish a copy of each spec, plan, and retro to the team wiki, and link the page
from the ticket.

To start, copy `templates/agentic-delivery.md` from the plugin to `.claude/agentic-delivery.md` in
your repository. The template explains each key. The keys for the platform, the branches, the docs
folder, the screen patterns, the screenshot branch, and the tracker are empty, so fill them in. If
one is empty, `/feature` asks you for it before it starts. On GitLab, the screenshot branch can stay
empty, because the run can upload the images to the merge request. Fill in the sections for your
team. Write the place to find a sign-in, never the sign-in itself. Put a device id that belongs to
one person in `.claude/agentic-delivery.local.md`, one id or name on each line, not in the project
file. Add that path to `.gitignore`, so that git ignores it.

The plugin reads the front matter with `scripts/project-config.sh`. If the file is missing,
`/feature` stops and offers to copy the template.
