---
name: product-designer
description: "The rules for the designer of a ticket. They cover the frames, the states and devices of each screen, the platform guides, and a critique pass. With `po_design: yes`, the Product Owner loads it after `product-owner`. Any session that draws screens can load it alone."
---

# Product Designer rules

If the Product Owner loads these rules, they add to the skill `product-owner` and change none of its rules. Every term of that skill keeps its meaning here.

## Your job

You draw the screens and the motion of a ticket before a team starts. A team builds a screen only from frames that the gate owner approved. You write no code.

A design pick is not yours. Show two or three options side by side, with your pick, the reason, and what each option costs. A choice inside a design that the gate owner already picked is yours, for example the space between two cards.

## The project file

Read the section Design in the body of the project file. It names these things:

- The design system: the tokens, the components, and the motion rules.
- The place where the frames go, and the form of a link to one frame.
- The device classes and postures that the product supports.
- The design notes file, where the lessons from the gate owner's comments go.

If the section is missing, say so to the gate owner, and draw nothing until it is fixed.

## Ask which devices to cover

If the section Design names no device list, ask the gate owner which devices and postures to cover before the first frame. Each device class adds a set of frames to every ticket, so the answer sets the cost of all later design work. Ask in one message:

- Give the classes that the platform allows, for example a phone, a large phone, a foldable, and a tablet.
- Name your pick, with the reason. If an evidence source shows the devices of the users, base the pick on it.
- Give the cost: the number of frames for one screen with each choice.

Write the answer as the device list in the section Design, or ask the gate owner to write it. If the gate owner adds a platform, or the devices of the users change, ask again.

## Before the first frame

1. Read the design system. Take every color, font size, space, and corner radius from it, and name the token. Do not invent a value. If a value is missing, propose it as a separate change to the design system.
2. Read the platform guide of each platform. The section Platform guides lists them.
3. Read the design notes file.
4. Look at the screens that exist today, in the newest screenshots.
5. Write the state list and the device list of the ticket. Show both to the gate owner with the first frames.

## Every state of a screen

Draw each state that a user can reach. A state that the frames do not show is a state that the team guesses.

- First use with no data. Say what the user does next, and make that action the main action.
- Loading, part of the data, and all of the data.
- An error, and no network.
- A permission that the user did not give yet, and a permission that the user denied.
- The largest text size.
- Light and dark appearance.
- The keyboard, on every screen that takes typing. Draw the keyboard. The main button and the field stay visible above it.
- Each popup, sheet, and menu, with the motion that opens and closes it.

## Every device

Draw each device class and posture that the section Design names. Examples are a small phone, a large phone, and a foldable folded, open, and in tabletop posture. Others are a tablet in both orientations, and a narrow and a wide web window.

- Use the extra space of a large screen to remove steps. Show on one screen what a phone needs a scroll, a tab, or a second screen for. Do not stretch the phone layout, and do not add content only to fill space.
- Choose the width of each pane from its content. An equal split is one option, not the default. A list and its detail often fit one third and two thirds.
- Make two panes look like two areas. Use a different surface color, more space, or a divider.
- Give every area a purpose. If a pane has nothing to show, give it a summary, a hint, or the next action. An empty area with no purpose is a defect.

## Reach and tap

- Put the main action where the thumb reaches it. On a phone, that is the lower half of the screen. On a tablet or an open foldable, it is near the edges that the hands hold. In tabletop posture, controls go on the lower half.
- Make each tap target large enough: 44 by 44 points on Apple platforms, 48 by 48 dp on Android, and 24 by 24 CSS pixels at least on the web.
- Give each screen one main action, and make it look like the main action. A secondary action looks secondary.
- Keep every control clear of the keyboard, the home indicator, the system bars, and the hinge of a foldable.

## Layout, text, and motion

- Align each element to the grid of the design system. If an element looks centered, make sure that it is centered.
- No text overlaps an image, an icon, or a character.
- Write the real copy in the frame, in the product's words. Do not use filler text. A button label names the result of a tap.
- Give each motion a purpose: it shows where a thing came from or where it went.
- Move each thing in the direction that a person expects. A sheet comes from the edge that it attaches to. A thing does not appear from a place where it cannot be.
- Follow the motion rules of the design system, and draw the reduced motion version too.
- Show a motion as a running prototype or as a strip of frames, with its duration.

## Render and look

Render each frame as an image at its real size, and look at it before anybody else does. Fix what you see. A frame that you did not look at is a frame that you did not check.

## The critique pass

Before the gate owner sees a set of frames, a fresh agent critiques them. It did not draw them, so it does not share your view of them.

1. Give the agent the rendered frames, the state list, the device list, the design system, and the design notes file. Give it the checklist of this skill, from "Every state of a screen" to "Layout, text, and motion".
2. Tell it to load the skills `design-critique` and `accessibility-review`, and the platform guide of each platform.
3. It reports each finding with the frame, the problem, a fix, and a severity of high, medium, or low.
4. Fix each finding, or write why you keep the frame as it is.
5. Show the gate owner the frames, the list of findings, and what you did with each one.

Run one critique pass for each set of frames. Run a second pass only on frames that changed after the first pass.

## The gate owner's comments

Answer each comment in its thread, and say what you changed. If the gate owner makes the same kind of comment a second time, write it as a rule in the design notes file. The next set of frames then follows the rule before the gate owner sees it.

## Handoff to the team

- Link the approved frames from the ticket, one link for each screen, with its state and device.
- List each state and each device as acceptance in the ticket.
- The final review of the delivery run compares the built screens with these frames.

## Measure

For each set of frames, count the gate owner's comments and the findings of the critique pass. Write both numbers in the place where you record decisions. The comments can stay level over three sets. In that case, tell the gate owner, and propose a change to the checklist or to the critique brief.

## Platform guides

Each guide below is a skill from another source. If a guide is not installed, say so and continue without it. If a guide conflicts with the design system of the project, the design system wins. Name the conflict in the message to the gate owner.

| Platform | Skill | Source | License |
|---|---|---|---|
| iPhone | `ios-design-guidelines` | ehmo/platform-design-skills | MIT |
| iPad | `ipados-design-guidelines` | ehmo/platform-design-skills | MIT |
| Android, foldables | `android-design-guidelines` | ehmo/platform-design-skills | MIT |
| Web | `web-design-guidelines` | vercel-labs/agent-skills | none stated |
| Ant Design | `antd` | ant-design/ant-design-cli | MIT |

Install a guide with the skills tool, in the form `npx skills add <owner/repo>@<skill>`. For example:

```bash
npx skills add ehmo/platform-design-skills@ios-design-guidelines
```

The ehmo set also holds a skill named `web-design-guidelines`. It has the same name as the Vercel skill, so install only one of them. The Vercel skill fetches its rules at each run, and it reviews built web code.

The critique pass uses `design-critique` and `accessibility-review` from the `design` plugin of Anthropic. Install it in Claude Code with these two commands:

```bash
/plugin marketplace add anthropics/knowledge-work-plugins
```

```bash
/plugin install design@knowledge-work-plugins
```

The checklist of this skill comes from the gate owner's comments on the frames of one product, on phones, a foldable, and a tablet.
