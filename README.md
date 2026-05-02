# Feeding the Family

A meal-planning iOS app for busy families. SwiftUI, iOS 17+, no external dependencies.

5 tabs:
- **Plan** — 7-day dinner plan with freshness lane, lock/swap/regenerate, multi-week navigation, auto-draft with editable rules
- **List** — grocery list grouped by aisle, weekly staples with learned suggestions
- **Snap** — camera nutrition tracking via Claude Vision (real food detection from photos)
- **Ideas** — saved snap inspirations, generate-recipe via Claude
- **Recipes** — full library, History, import recipes from any URL

## Build

```
cd ~/Desktop/FeedingTheFamily
xcodebuild -project FeedingTheFamily.xcodeproj -scheme FeedingTheFamily \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

## Setup

First-run onboarding asks for family size, weekly rhythm, avoidances, and an optional Anthropic API key.

The Anthropic API key powers:
- **Snap** food detection (photo → macros)
- **Generate recipe** from a saved inspiration
- **Import from URL** for any recipe online

Without a key, Snap falls back to demo fixtures. Get a key at [console.anthropic.com](https://console.anthropic.com).

## Privacy

See [docs/privacy.html](docs/privacy.html). All data is stored locally on the device. The only network calls are direct to `api.anthropic.com` using your own API key.
