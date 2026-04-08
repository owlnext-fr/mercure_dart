# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pure Dart implementation of the [Mercure protocol](https://mercure.rocks/spec) — zero external dependencies, fully spec-compliant. Multi-platform: mobile, desktop, server (dart:io) and web (dart:html/EventSource). The spec at https://mercure.rocks/spec is authoritative; the internal spec at `docs/spec.md` details the implementation design.

## Build & Dev Commands

```bash
# Dependencies & build
dart pub get
dart analyze                          # Static analysis
dart format .                         # Format all files
dart format --set-exit-if-changed .   # Format check (CI)

# Tests
dart test                             # All tests
dart test test/unit/                   # Unit tests only (no network, all platforms)
dart test test/integration/           # Integration tests (requires Docker + dart:io)
dart test test/unit/sse/sse_parser_test.dart      # Single test file
dart test --name "parses multi-data"              # Single test by name
dart test --reporter expanded                     # Verbose output
```

## Architecture

### Platform Abstraction (key design decision)

A single conditional import in `mercure_transport_factory.dart` is the **only** platform branching point:

```
transport_stub.dart ← default (throws UnsupportedError)
transport_io.dart   ← dart:io (HttpClient + custom SSE parsing)
transport_web.dart  ← dart:html (native EventSource + fetch)
```

Everything else (`models/`, `sse/`, `auth/`, `discovery/`, `subscriptions_api/`) is pure Dart — **must never import dart:io or dart:html**.

### Layer Diagram

```
┌─────────────────────────────────────────┐
│  Public API: MercureSubscriber,         │
│  MercurePublisher, MercureDiscovery,    │
│  MercureSubscriptionsApi                │  ← Façades
├─────────────────────────────────────────┤
│  MercureTransport (abstract interface)  │  ← Platform boundary
├──────────────┬──────────────────────────┤
│  IO transport│  Web transport           │  ← Platform-specific
│  (HttpClient)│  (EventSource + fetch)   │
├──────────────┴──────────────────────────┤
│  SSE parser, models, auth               │  ← Pure Dart, shared
└─────────────────────────────────────────┘
```

### SSE Pipeline (io transport only)

`HttpClient response bytes` → `SseLineDecoder` (bytes→lines, handles \r\n/\r/\n split across chunks) → `SseParser` (stateful lines→MercureEvent) → `Stream<MercureEvent>`

The web transport skips this entirely — the browser's native EventSource handles SSE parsing and reconnection.

### Auth Model

`MercureAuth` is a sealed class with 3 variants: `Bearer`, `Cookie`, `QueryParam`. Transport applies auth to requests. Web subscriber cannot use Bearer (EventSource doesn't support custom headers) — falls back to query param `authorization` per spec.

## Constraints & Rules

- **Zero dependencies** in pubspec.yaml — no package:http, no package:web
- Dart 3.x with sound null safety
- `sealed class` for unions (auth, results); `final class` everywhere else unless inheritance needed
- No code generation, no annotations
- Conditional imports only in `mercure_transport_factory.dart`
- Unit tests are pure Dart (run on all platforms); integration tests are dart:io only (Docker)
- Integration tests use `dunglas/mercure` Docker image — helper at `test/helpers/hub.dart` manages container lifecycle and JWT generation
- Set `MERCURE_HUB_URL` env var to use an external hub (CI service container) instead of auto-starting Docker
- CI runs via GitHub Actions (`.github/workflows/ci.yml`): analyze, unit tests (SDK 3.0.0 + stable matrix), integration tests with Mercure service container

<!-- rtk-instructions v2 -->
## RTK (Rust Token Killer) - Token-Optimized Commands

### Golden Rule

**Always prefix commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

### RTK Commands by Workflow

#### Build & Compile (80-90% savings)
```bash
rtk cargo build         # Cargo build output
rtk cargo check         # Cargo check output
rtk cargo clippy        # Clippy warnings grouped by file (80%)
rtk tsc                 # TypeScript errors grouped by file/code (83%)
rtk lint                # ESLint/Biome violations grouped (84%)
rtk prettier --check    # Files needing format only (70%)
rtk next build          # Next.js build with route metrics (87%)
```

#### Test (90-99% savings)
```bash
rtk cargo test          # Cargo test failures only (90%)
rtk vitest run          # Vitest failures only (99.5%)
rtk playwright test     # Playwright failures only (94%)
rtk test <cmd>          # Generic test wrapper - failures only
```

#### Git (59-80% savings)
```bash
rtk git status          # Compact status
rtk git log             # Compact log (works with all git flags)
rtk git diff            # Compact diff (80%)
rtk git show            # Compact show (80%)
rtk git add             # Ultra-compact confirmations (59%)
rtk git commit          # Ultra-compact confirmations (59%)
rtk git push            # Ultra-compact confirmations
rtk git pull            # Ultra-compact confirmations
rtk git branch          # Compact branch list
rtk git fetch           # Compact fetch
rtk git stash           # Compact stash
rtk git worktree        # Compact worktree
```

Note: Git passthrough works for ALL subcommands, even those not explicitly listed.

#### GitHub (26-87% savings)
```bash
rtk gh pr view <num>    # Compact PR view (87%)
rtk gh pr checks        # Compact PR checks (79%)
rtk gh run list         # Compact workflow runs (82%)
rtk gh issue list       # Compact issue list (80%)
rtk gh api              # Compact API responses (26%)
```

#### JavaScript/TypeScript Tooling (70-90% savings)
```bash
rtk pnpm list           # Compact dependency tree (70%)
rtk pnpm outdated       # Compact outdated packages (80%)
rtk pnpm install        # Compact install output (90%)
rtk npm run <script>    # Compact npm script output
rtk npx <cmd>           # Compact npx command output
rtk prisma              # Prisma without ASCII art (88%)
```

#### Files & Search (60-75% savings)
```bash
rtk ls <path>           # Tree format, compact (65%)
rtk read <file>         # Code reading with filtering (60%)
rtk grep <pattern>      # Search grouped by file (75%)
rtk find <pattern>      # Find grouped by directory (70%)
```

#### Analysis & Debug (70-90% savings)
```bash
rtk err <cmd>           # Filter errors only from any command
rtk log <file>          # Deduplicated logs with counts
rtk json <file>         # JSON structure without values
rtk deps                # Dependency overview
rtk env                 # Environment variables compact
rtk summary <cmd>       # Smart summary of command output
rtk diff                # Ultra-compact diffs
```

#### Infrastructure (85% savings)
```bash
rtk docker ps           # Compact container list
rtk docker images       # Compact image list
rtk docker logs <c>     # Deduplicated logs
rtk kubectl get         # Compact resource list
rtk kubectl logs        # Deduplicated pod logs
```

#### Network (65-70% savings)
```bash
rtk curl <url>          # Compact HTTP responses (70%)
rtk wget <url>          # Compact download output (65%)
```

#### Meta Commands
```bash
rtk gain                # View token savings statistics
rtk gain --history      # View command history with savings
rtk discover            # Analyze Claude Code sessions for missed RTK usage
rtk proxy <cmd>         # Run command without filtering (for debugging)
rtk init                # Add RTK instructions to CLAUDE.md
rtk init --global       # Add RTK to ~/.claude/CLAUDE.md
```

### Token Savings Overview

| Category | Commands | Typical Savings |
|----------|----------|-----------------|
| Tests | vitest, playwright, cargo test | 90-99% |
| Build | next, tsc, lint, prettier | 70-87% |
| Git | status, log, diff, add, commit | 59-80% |
| GitHub | gh pr, gh run, gh issue | 26-87% |
| Package Managers | pnpm, npm, npx | 70-90% |
| Files | ls, read, grep, find | 60-75% |
| Infrastructure | docker, kubectl | 85% |
| Network | curl, wget | 65-70% |

Overall average: **60-90% token reduction** on common development operations.
<!-- /rtk-instructions -->
