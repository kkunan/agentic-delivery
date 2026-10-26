# Install

This page is for a person who installs the plugin for a team or for a try. The [README](../README.md) says what the plugin does.

The plugin needs the superpowers plugin from the `claude-plugins-official` marketplace. The feature
command uses four of its skills. If one is missing, the command stops. The manifest names superpowers as a
dependency, so Claude Code can install it with this plugin. If it does not, install it first.

For a team, pin the plugin to a release tag. Run these two commands at the root of your
repository:

```bash
claude plugin marketplace add 'kkunan/agentic-delivery#v0.9.0' --scope project
```

```bash
claude plugin install agentic-delivery@agentic-delivery --scope project
```

The commands write these settings to `.claude/settings.json`. Commit that file, so that the whole
team gets the same version:

```json
{
  "extraKnownMarketplaces": {
    "agentic-delivery": {
      "source": { "source": "github", "repo": "kkunan/agentic-delivery", "ref": "v0.9.0" }
    }
  },
  "enabledPlugins": { "agentic-delivery@agentic-delivery": true }
}
```

Without a pin, each change to this repository reaches the whole team at the next update. With a
pin, an update is a change that the team reviews. To update, move `ref` to the new tag in a pull
request or merge request. After the merge, each person runs the `marketplace add` command again
with the new tag.

The owner of this repository can move a tag, so a tag pin is a review step, not a hard lock. A team
that needs a hard lock can copy the plugin into a marketplace of its own.

To try the plugin on your own, you can leave out the pin. Then each update gets the newest commit
of the default branch:

```bash
claude plugin marketplace add kkunan/agentic-delivery
```

To install from a local clone instead, give the path of the clone to the `marketplace add` command.
The option `--scope local`, `--scope project`, or `--scope user` on each command picks where Claude
Code stores the setting: your own local settings for this project, the settings file that the team
shares in the repository, or your settings for every project.

Run `claude plugin list` to check that `agentic-delivery` shows as enabled. Then copy the template
to `.claude/agentic-delivery.md` in your repository, as [Set up a project](setup.md) says,
and run `/feature` in Claude Code.

> [!IMPORTANT]
> Install tests ran three forms, and each one installed the plugin: a local clone with
> `--scope local`, the GitHub form with `--scope project`, and the pinned GitHub form with
> `--scope project`. With the pin, the clone was at the commit of the tag. On Claude Code 2.1.236,
> `ref` takes a branch or a tag, but not a commit SHA. One machine already had the marketplace.
> There, `claude plugin marketplace update` kept the old source, without `ref`. The
> `marketplace add` command with the tag then added the `ref`.

## Optional product skills

The same marketplace holds a second plugin, `agentic-discovery`. It is separate, and the delivery
plugin does not need it. It has five skills:

- `agentic-discovery:public-writing` gives the rules for a page that people outside the agent sessions read.
- `agentic-discovery:public-roadmap` builds a public roadmap page from a talk with the owner. It
  holds the questions, an HTML template, and three made-up samples.
- `agentic-discovery:product-board` keeps a log of each read of the product numbers and the
  decision that follows it, and shows both on one page. It holds the rules for a read and a board
  with made-up data.
- `agentic-discovery:product-owner` gives the rules for a Product Owner session: ready tickets,
  grooming, sprint planning, and replan.
- `agentic-discovery:product-manager` adds decision memos with evidence to the Product Owner.

A Product Owner session of the delivery plugin needs this plugin. A team of people can also use
the Product Owner alone, with no delivery plugin. Copy `templates/agentic-discovery.md` from this
plugin to `.claude/agentic-discovery.md`, and fill in the blanks. Ready tickets then go to the
person that the key `lead` names.

To install it, add the marketplace as above, then run this command:

```bash
claude plugin install agentic-discovery@agentic-delivery
```

The writing skill comes from two products, and the roadmap skill from one. The board skill comes from the boards of two products. The Product Owner skills come from the Product Owner of one product, and the mode for a team of people ran only on a fixture. No team used them yet.
