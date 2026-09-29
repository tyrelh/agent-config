---
name: like-me
description: Write in Tyrel's own voice. Use when drafting or rewriting blog posts, write-ups, technical explainers, READMEs, or other prose that should sound like Tyrel wrote it, or when the user says "like me", "in my voice", "sound like me", or "my style".
reference: Derived from 19 hand-written superflux.dev posts (2017 to 2024), via the vault note "inbox/Tyrel writing style guide.md"
---

# Write like Tyrel

Write blog posts, write-ups, and technical explainers in Tyrel's voice. The target is his later posts (2022 onward), which are tighter; the early posts ramble more.

Keep every fact the user gave you. Do not invent experiences, prices, part names, dates, or opinions he didn't state. If a sentence needs a first-person detail you don't have, ask for it or leave it out.

## How to work

1. **Get a draft.** Rewriting existing text: that text is the draft. Writing from scratch: write a plain first draft of the content first.
2. **Run the `humanize` skill on the draft.** This strips the generic AI tells. If the skill isn't available, say so and go to step 3.
3. **Apply this style guide to the humanized text.** Humanize makes the text neutral; this step puts his voice in. Work through every section below, then check the result against *Avoid* one last time.

## Voice

- **First person, telling the story of doing the thing.** Frame posts as a personal journey: why I started, what I tried, what broke, what I'd do differently. "Here is my journey into...", "I started this project in 2018 to help teach myself...".
- **Switch to "you" for instructions.** Narrative is "I", steps are "you" and "we". "Log into your AWS Console... Click *Create bucket*."
- **Casual, no tie.** Write like explaining something to a friend at the next desk. Plain words, contractions, loose qualifiers: pretty, quite, a bit, kinda, sorta, essentially, basically, really, just.
- **Honest about what he doesn't know.** Flag uncertainty inline instead of faking confidence. "I believe this name just needs to be unique to this repo", "(or region unique? I can't remember)", "I have no idea if this is ok or ill advised but it seemed to work great for me", "I would struggle to explain A*".
- **Owns his mistakes, lightly.** Self-deprecating, never grovelling. "This wasn't a very forward thinking decision on my part." "It came out as a big frown shape (or smiley shape, but I wasn't very happy about it)." "Might be over engineering for the task, but it's for learning."
- **Pragmatic.** Prefer the simple fix and say so. "Much simpler than trying to code for it." "You're really just making a call to save yourself from making a call." Admit when a tool was easier than expected: "I just assumed it would be complicated to set up... Couldn't have been easier."
- **Opinions stated plainly, without heat.** "It feels crazy to have to use molex connections in a PC in 2021." "Deno's, frankly, lack of polish." "Just spread it yourself!" Recommendations are conditional and honest: "Only attempt something like this if you also feel the same."
- **Give the reason for a preference and admit the other way works.** "You can also just use separate branches in the same GitHub Pages repository if you prefer... That feels messy to me so I prefer to keep them separate." "Since it's going to be static for this project I don't see any reason not to."
- **Honest when something didn't matter.** Say when an upgrade or step was marginal instead of overselling it. "I don't think this was strictly necessary, but...", "although I don't really notice the difference in day-to-day use", "it's secure (secure enough for me anyway)".
- **Choices rest on consistent values:** owning his data, portable formats that will last, avoiding lock-in and subscriptions. "I'd like them to be in a format that will be accessible decades from now (like a paper notebook would), and I don't think something like Notion, Apple Notes, or Google Docs will be around in 30 or 40 years."
- **Dry humour, used lightly.** A wink, not a joke setup. "the odd legally acquired TV series", "you can use a Synology NAS as a NAS... but where's the fun in that?"
- **Date his opinions.** "My summary represents my understanding and opinions right now (Spring 2022)." Prices and numbers get a date when they'll go stale: "(Jan 24 2021)".

## Sentences and rhythm

- Medium-length, plain sentences. An occasional comma splice is fine. No literary flourishes.
- Short reaction lines after a win: "Easy!", "Basic sight!", "You can!", "Great.", "And that's it!", "Holy cow!"
- Set up the next step with a rhetorical question: "Ok, so now I have a list of all the unique tags. Now what?", "so wouldn't it be nice if you could just set the theme based on that? You can!"
- Conversational transitions: So, Now, Next, Ok so, Lastly, So there you go.
- Frequent parenthetical asides for clarifications, prices, side comments, and small jokes: "(Banggood is a Chinese online retailer similar in style to Alibaba)", "(sorry for the imagery)".
- Make a point with an everyday analogy or a "you wouldn't..." question: "Using pull request internally is like forcing your family through airport security just to enter your house." "You wouldn't let someone log into app servers and make changes directly to the code. So why let that happen for infrastructure?"
- Idioms he actually uses: rabbit hole, dialed in, gotcha, janky, fits the bill, dip my toes in, hype train, tear off the band-aid, automate all the things.
- Commas, parentheses, and the occasional semicolon. **No em dashes.**
- Canadian spelling: colour, behaviour, favourite, aluminium. Prices in CAD unless the source is USD, and say which.

## Content habits

- **Open with context and motivation** in one to three sentences: what the project is and why he did it. Briefly explain anything a newcomer wouldn't know ("If you are unfamiliar with Battlesnake, it is...").
- **Be concrete.** Exact part names, versions, temperatures, prices, frame rates, command names. Numbers over adjectives.
- **Share tips from experience**, framed as his own: "One tip I have is...", "I would recommend getting more 90° adaptors than you think you need", "do not rely on them being square, they are not."
- **Credit inspiration by name** and link it: tutorials, YouTubers, other bloggers' posts.
- **Link liberally inline** to docs, repos, and products. Put key doc links right under the section they support.
- **Explain code after showing it.** Show the snippet, then walk through it: "You can see at the beginning of this job that it depends on the `build` job."
- **Admit loose ends.** Known issues, things he ran out of time for, and future work get their own list.

## Formatting

- Backticks for code identifiers, commands, and config keys.
- Italics for file paths and UI labels: *.github/workflows/*, *Create bucket*.
- Bold only for a rare warning ("**While leaving this tab open**") or a bullet's lead phrase.
- Emoji sparingly, at most one or two per post, at the end of a sentence: 😎 🤷🏻‍♂️ 🤯 👋🏻.
- One paragraph per line; never hard-wrap markdown.

## Avoid

- Corporate, marketing, or hype tone. No "unlock", "seamless", "game-changer".
- Grand conclusions or morals. The conclusion is what got built and how he feels about it.
- Faked certainty. If it's a guess, say "I think" or "I believe".
- Polished rhetorical devices: forced triads, "not X but Y" contrasts, punchy one-line closers on every paragraph.
- Em dashes.
- Copying the typos in the source posts. Casual is the target, sloppy isn't.

## Sounds like

> Github Actions are still quite new to me and I hadn't touched them at all before this project. I just assumed it would be complicated to set up. For what I wanted to do for this project it was actually trivial. Couldn't have been easier.

> One small issue I ran into is one tag I was using contained a `/` character, `ci/cd`. This wasn't a very forward thinking decision on my part. I just needed to search through my articles and remove the `/` character from that tag, making it just `cicd`. Much simpler than trying to code for it.
