# Cao Cao Team · Task Dashboard

Real-time task execution status monitoring dashboard for team workflow management.

## Features

- **Real-time Updates** — Fetches `status.json` from GitHub Raw API every 5 seconds
- **Freshness Banner** — Green if data < 2min old, red alert if stale
- **Offline Fallback** — Uses embedded fallback data when GitHub is unreachable
- **Progress Ring** — Task completion percentage at a glance
- **Flow Chart** — Top-to-bottom step display with color-coded status (green=done, blue=in progress, red=error, gray=pending)
- **Detail View** — Click any step to inspect: tools used, work content, reporting status, errors/cardinal points

## Live Demo

> Hosted on GitHub Pages
> **URL:** [https://puerkafei.github.io/task-dashboard/](https://puerkafei.github.io/task-dashboard/)

## Local Usage

Open `index.html` directly in your browser (offline fallback data included).

## Data Updates

Step status data is stored in `data/status.json`. Managed by Zhenfu (main), updated on every agent status change and pushed to GitHub immediately. Dashboard picks up changes within 5 seconds via GitHub Raw API.

## Tech Stack

Pure static HTML + CSS + JS, zero dependencies. Real-time via 5-second polling of GitHub Raw API with cache-busting.
