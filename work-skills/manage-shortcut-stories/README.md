# Setup

You'll need to create the _.env_ file using the _.env.example_ as a template.

```bash
cp .env.example .env
```

Then, you'll need to add your Shortcut API token to the _.env_ file.

You can generate a token here: https://app.shortcut.com/giftbit/settings/account/api-tokens

```bash
SHORTCUT_API_TOKEN=your-shortcut-token
```

_.env_ should already be gitignored, but always ensure you're not committing keys to the repo if you're making changes.
