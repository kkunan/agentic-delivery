# Get started by role

Each section below holds one prompt. Copy it, paste it into a new Claude Code session, and answer the questions that it asks. Each prompt installs what the role needs and fills in the project file with you. Each prompt ends with a restart, because Claude Code loads a new plugin only when a session starts.

The prompts install the newest version for a try. To pin a version for a team, see the [install guide](install.md).

## Developer or tech lead

You run features through the agent team with `/feature`. Start the session at the root of your repository.

```text
Set up the agentic-delivery plugin in this repository. Do these steps in order:

1. Install the plugin. Run: claude plugin marketplace add kkunan/agentic-delivery, then: claude plugin install agentic-delivery@agentic-delivery --scope project
2. Download the project file template. Run: mkdir -p .claude && curl -fsSL https://raw.githubusercontent.com/kkunan/agentic-delivery/main/templates/agentic-delivery.md -o .claude/agentic-delivery.md
3. Read the template. Read this repository to propose a value for each key that you can find: the platform, the branches, the screen file patterns, the forge, and the tracker. Then ask me one question at a time for each key and section that you cannot find. Explain each key in plain words.
4. Show me the filled file, and write it after I say yes. Do not commit it.
5. Tell me to restart Claude Code here, so that the plugin loads. After the restart, I will run /feature with my first ticket.
```

## Product Owner with a team of people

A team of people builds your tickets, and no agent writes code. Start the session in an empty folder for your product.

```text
Set me up with the Product Owner from the agentic-discovery plugin. I am a product owner, and a team of people builds my tickets. Do these steps in order:

1. Install the plugin. Run: claude plugin marketplace add kkunan/agentic-delivery, then: claude plugin install agentic-discovery@agentic-delivery
2. Download the project file template into this folder. Run: mkdir -p .claude && curl -fsSL https://raw.githubusercontent.com/kkunan/agentic-delivery/main/plugins/agentic-discovery/templates/agentic-discovery.md -o .claude/agentic-discovery.md
3. Read the template. Then ask me one question at a time to fill in each key and section. Explain each key in plain words. Use these defaults unless I say otherwise: po_authority: backlog, comment_prefix: Claude said:, delivery_mode: flow. If my tracker needs a connector that this session does not have, tell me how to add it.
4. Show me the filled file, and write it after I say yes.
5. Tell me to restart Claude Code in this folder, so that the plugin loads. After the restart, I will say: Load the product-owner skill and groom the backlog.
```

## Product Owner for the agent team

The agent team builds your tickets with `/feature`, and the repository already has `.claude/agentic-delivery.md`. Start the session at the root of that repository.

```text
Set me up as the Product Owner of the agent team in this repository. Do these steps in order:

1. Install the product plugin. Run: claude plugin marketplace add kkunan/agentic-delivery, then: claude plugin install agentic-discovery@agentic-delivery
2. Read .claude/agentic-delivery.md. If it is missing, stop and tell me to set up the delivery plugin first.
3. Ask me one question at a time to fill in the keys po, delivery_mode, po_grooming, po_authority, and po_scope, and the section Product Owner. Explain each one in plain words. Ask me what to call this session, and put that name in po. Use po_authority: backlog unless I say otherwise.
4. Show me the changed lines, and write them after I say yes. Do not commit them.
5. Tell me to restart Claude Code here, so that the plugin loads. After the restart, I will say: Load the product-owner skill and groom the backlog.
```

## Product Manager

You already have a Product Owner session from one of the two sections above, and you want it to prepare product decisions with evidence. Start the session in the folder of that Product Owner.

```text
Add decision memos to my Product Owner. Do these steps in order:

1. Find the project file: .claude/agentic-discovery.md, or .claude/agentic-delivery.md if that one exists. If neither exists, stop and tell me to set up the Product Owner first.
2. Install the expert skills that the memo rules use. Run: claude plugin marketplace add anthropics/knowledge-work-plugins, then: claude plugin install product-management@knowledge-work-plugins
3. Ask me one question at a time to fill in the section Product Manager: the person who decides, each evidence source and how to read it, and the strategy document if one exists. Set po_scope: product.
4. Show me the changed lines, and write them after I say yes.
5. Tell me to restart Claude Code here. After the restart, I will say: Load the product-owner skill and prepare a memo for my next decision.
```

## Anyone who writes for readers outside the team

You want a public roadmap, a stakeholder update, or a board of product numbers. Start the session in any folder.

```text
Install the agentic-discovery plugin. Run: claude plugin marketplace add kkunan/agentic-delivery, then: claude plugin install agentic-discovery@agentic-delivery. Then tell me to restart Claude Code. After the restart, I will ask for a public roadmap, a page for readers outside the team, or a product board.
```
