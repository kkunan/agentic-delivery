# Get started by role

## Not sure which one to copy

Copy this one prompt, and paste it into a new Claude Code session. It asks about your work, picks the section that fits, and follows that section with you.

```text
Help me set up the agentic-delivery plugin. I do not know which setup I need. Run: curl -fsSL https://raw.githubusercontent.com/kkunan/agentic-delivery/main/docs/get-started.md. Ask me one plain question at a time to find the section that fits my work, for example whether I write code and whether agents or people build my tickets. Explain each technical word in plain words. If I do not write code, pick the section for anyone who does not write code, in any folder. For another section, look at the current folder, and see whether .claude/agentic-delivery.md is in it. If that section needs a different folder, tell me how to start a session there, and stop. Otherwise tell me which section you picked, and follow its prompt.
```

## Know your role

Each section below holds one prompt. Copy it, paste it into a new Claude Code session, and answer the questions that it asks. Each prompt installs what the role needs and fills in the project file with you. Each prompt ends with a restart, because Claude Code loads a new plugin only when a session starts.

The prompts install the newest version for a try. To pin a version for a team, see the [install guide](install.md).

## Anyone who does not write code

This section is for you if you do not write code, for example a designer, a tester, a manager, an operations lead, or a founder. You do not need to know what a repository is. The session does the technical steps, and you answer questions in plain words. You can start the session in any folder.

To change an existing product, a developer must first set up the project. The run builds the app on your computer, so your computer needs the build tools of the project. The prompt finds out if they are missing. A developer reviews and merges the work, unless the project file names you as the person who says merge.

```text
Help me start with agentic-delivery. I do not write code, so do the technical steps for me. Explain each step in plain words. Before each approval request, say in one sentence what it does. Never ask me to paste a password or a key into this chat. Run: curl -fsSL https://raw.githubusercontent.com/kkunan/agentic-delivery/main/docs/get-started.md. Then ask me what I want to do, and follow the matching item:

- I decide what the team builds. Follow the prompt in the section Product Owner who does not use code tools.
- I want a page for readers outside the team, for example a roadmap or an update. Follow the prompt in the section Anyone who writes for readers outside the team.
- I want agents to change an existing product, for example build my design or fix a problem. Do these steps:
  1. Follow steps 1 to 6 of the prompt in the section Product Owner who does not use code tools.
  2. Install the plugin. Run: claude plugin marketplace add kkunan/agentic-delivery, then: claude plugin install agentic-delivery@agentic-delivery. Then run: claude plugin list. If superpowers is not in the list, run: claude plugin install superpowers@claude-plugins-official
  3. Read the platform key in .claude/agentic-delivery.md, and find out which build tools that platform needs. If a tool is missing, name it, and give me one sentence to send to the developer. Do not start a large install unless I say yes.
  4. Tell me who says merge, from the project file. If the file does not name me, say that a developer reviews and merges my work.
  5. Tell me to open the project folder in a new Claude Code session. In that session, I will say /feature, and then what I want in my own words.
- I have an idea and no project yet. Tell me that this guide has no setup for this case yet. Give me one sentence to send to a developer, to ask them to create the project and set up agentic-delivery.
```

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

The agent team builds your tickets with `/feature`, and the repository already has `.claude/agentic-delivery.md`. Start the session at the root of that repository. The prompt asks one question and uses the recommended value for each other setting. You can change a setting later if you ask the session. If you do not use code tools, use the next section.

```text
Set me up as the Product Owner of the agent team in this repository, with the recommended settings. Do these steps in order:

1. Install the product plugin. Run: claude plugin marketplace add kkunan/agentic-delivery, then: claude plugin install agentic-discovery@agentic-delivery
2. Read .claude/agentic-delivery.md. If it is missing, stop and tell me to set up the delivery plugin first.
3. Set these keys: po: Product Owner, delivery_mode: flow, po_grooming: events, po_authority: backlog, po_scope: tickets.
4. Ask me one question: which date or customer promise must the backlog order follow? If I have none, write that the backlog follows user value against size. Write the answer in the section Product Owner, and write there that each open question stays on its ticket.
5. Show me the changed lines, with one plain sentence that explains each setting. Write them after I say yes. Do not commit them.
6. Tell me to rename this session to Product Owner and restart Claude Code here. After the restart, I will say: Load the product-owner skill and groom the backlog.
```

## Product Owner who does not use code tools

The agent team builds your tickets, and a developer already set up the project. You need only the link to the project page that you open in your browser. You can start the session in any folder.

A developer can add that link to the prompt before they send it to you. On a company GitLab server, browser sign-in needs an OAuth application (a sign-in entry on the server). An administrator makes one for all users, as the [GitLab CLI authentication page](https://docs.gitlab.com/cli/authentication/) says. The developer can add its client ID to the prompt too.

```text
Set me up as the Product Owner of our agent team. I do not use code tools, so do the technical steps for me. Explain each step in plain words. Before each approval request, say in one sentence what it does. Never ask me to paste a password or a key into this chat. Do these steps in order:

1. Ask me for the link to the project page that I open in my browser. Read the host name from the link. If you cannot tell whether the host is GitHub or GitLab, ask me.
2. Make sure that git is installed, and that the tool for the host is installed: gh for GitHub, glab for GitLab. If a tool is missing, run: brew install gh, or: brew install glab. If Homebrew is missing or an install asks for my password, tell me what to do, and wait.
3. Sign me in through my browser, and tell me what to approve. Show me each code that the command prints. For GitHub, run: gh auth login --hostname <host> --web --git-protocol https, then: gh auth setup-git --hostname <host>. For gitlab.com, run: glab auth login --hostname gitlab.com --web --git-protocol https --setup-git-credential-helper. For another GitLab server, I need a client ID from the administrator. If I have it, run: glab config set client_id <CLIENT_ID> --host <host>, then the glab command above with that host. If I do not have it, give me one sentence to send to the developer, and stop.
4. If a sign-in command waits for me to type, give me the exact command to run in the Terminal app, and wait.
5. Copy the project into ~/Documents/<project name>. If that folder exists and its origin is this project, use it. If it holds something else, stop and tell me.
6. Read .claude/agentic-delivery.md in that folder. If it is missing, give me one sentence to send to the developer, and stop. If its tracker needs a connector that this session does not have, tell me how to add it.
7. Install the product plugin. Run: claude plugin marketplace add kkunan/agentic-delivery, then: claude plugin install agentic-discovery@agentic-delivery
8. In that file, set these keys: po: Product Owner, delivery_mode: flow, po_grooming: events, po_authority: backlog, po_scope: tickets.
9. Ask me one question: which date or customer promise must the backlog order follow? If I have none, write that the backlog follows user value against size. Write the answer in the section Product Owner, and write there that each open question stays on its ticket.
10. Show me the changed lines, with one plain sentence that explains each setting. Write them after I say yes. Do not commit or push.
11. Tell me to open ~/Documents/<project name> in a new Claude Code session, and to name that session Product Owner. In that session, I will say: Load the product-owner skill and groom the backlog.
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

## QA

You set the bar for done, and the QA reviewer agent finds each check in a plan that cannot fail. It needs no build tools. A developer must first set up the project. Start the session at the root of the repository.

```text
Set me up as the QA person of the agent team in this repository. Do these steps in order:

1. Read .claude/agentic-delivery.md. If it is missing, stop and tell me to ask a developer to set up the plugin first.
2. Install the plugin. Run: claude plugin marketplace add kkunan/agentic-delivery, then: claude plugin install agentic-delivery@agentic-delivery
3. Read the sections Devices and Accounts. If one is empty, ask me one question at a time to fill it in. Never write a password or a key in the file. Write only the place to find it.
4. Show me the changed lines, and write them after I say yes. Do not commit them.
5. Tell me to restart Claude Code here, so that the plugin loads. After the restart, I will say: Use the agentic-delivery:qa-reviewer agent to review this plan, for the platform in the project file. Then I will give the plan, the spec, or the ticket.
```

## Engineering manager

You own the budget and who signs off. Each run writes a retro with its estimated and actual cost, and this prompt puts the retros into one table. It installs nothing. Start the session at the root of the repository.

```text
Set me up as the engineering manager of the agent team in this repository. Do these steps in order:

1. Read .claude/agentic-delivery.md. If it is missing, stop and tell me to ask a developer to set up the plugin first. To learn what each key means, run: curl -fsSL https://raw.githubusercontent.com/kkunan/agentic-delivery/main/templates/agentic-delivery.md
2. Find the retros in the retros folder inside the folder that docs_dir names. If docs is private, that folder can be on the computer of a developer. If it is not here, ask me for a folder that holds a copy.
3. Make one table with one row for each retro: the date, the ticket, the size, the tokens, and the human touches, each with its estimate and its actual. Copy each number from the retro. If a retro has no number, leave the cell empty and say so. Do not estimate a number.
4. Ask me one question at a time who approves plans, who says merge, and who decides process changes. Write each answer in the section of the project file that the template names.
5. Show me the changed lines, and write them after I say yes. Do not commit them.
6. Tell me that I can ask this session for the cost table again at any time.
```

## Anyone who writes for readers outside the team

You want a public roadmap, a stakeholder update, or a board of product numbers. Start the session in any folder.

```text
Install the agentic-discovery plugin. Run: claude plugin marketplace add kkunan/agentic-delivery, then: claude plugin install agentic-discovery@agentic-delivery. Then tell me to restart Claude Code. After the restart, I will ask for a public roadmap, a page for readers outside the team, or a product board.
```
