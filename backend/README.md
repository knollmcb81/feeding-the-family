# Backend proxy

Tiny serverless proxy so the iOS app doesn't ship the Anthropic API key. The app posts the same Anthropic Messages payload it would post directly; this proxy validates a bearer token, then forwards to `api.anthropic.com` using the server-side Anthropic key.

Required for App Store distribution. Optional for personal TestFlight (the app falls back to direct calls when no backend URL is configured).

## Deploy to Vercel (recommended)

1. Sign up at [vercel.com](https://vercel.com), free tier is fine.
2. Install the CLI: `npm i -g vercel`.
3. From this `backend/` folder:
   ```
   vercel login
   vercel
   ```
   Accept the defaults. Vercel deploys to a unique URL (e.g. `feeding-family-proxy.vercel.app`).
4. Set the two environment variables in the Vercel dashboard:
   - `ANTHROPIC_API_KEY` — your `sk-ant-...` (same one you've been using directly)
   - `APP_AUTH_TOKEN` — any random string. Generate one with `openssl rand -base64 32`. **Keep it private.**
5. Redeploy: `vercel --prod`.

## Configure the app

In the app: Plan → gear → AI Vision → scroll to **OR USE A BACKEND**.

- **Backend URL**: paste your Vercel URL (e.g. `https://feeding-family-proxy.vercel.app`). No trailing slash.
- **Bearer token**: paste your `APP_AUTH_TOKEN`.

Tap **Test connection**. If it returns "Connected," the proxy works. From this point, the Anthropic key field can be empty — the proxy holds the real key.

## What the proxy does

- Accepts `POST /v1/messages` with a JSON body matching Anthropic's shape.
- Verifies `Authorization: Bearer <APP_AUTH_TOKEN>` against the env var.
- Forwards to Anthropic with the server's key.
- Returns the response unmodified.

That's it. ~50 lines of code. No persistence, no logging, no rate limiting — add those if you want.

## Other deploy targets

The same `api/v1/messages.js` runs on:

- **Cloudflare Workers** — paste into a Worker, set the same env vars
- **Railway / Render** — wrap in a tiny Express app
- **Supabase Edge Functions** — same code, minor import swap

## Cost expectations

Vercel's free tier: 100 GB-hours/month, plenty for personal use. Anthropic costs (Claude Sonnet 4.6 vision): ~$0.005 per snap, ~$0.01 per recipe import. $5 of credit lasts hundreds of operations.

## Security notes

- The bearer token is a shared secret between every install of the app. Anyone with the token can hit the proxy. For real distribution, swap to per-user auth (Sign in with Apple → JWT).
- Don't commit secrets. Vercel env vars stay server-side; the iOS app only stores the bearer token in Keychain.
- Add a domain allowlist or rate limit if you ever distribute the app publicly.
