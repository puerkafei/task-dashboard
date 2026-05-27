# Cao Cao Team · Task Dashboard

Real-time task execution status monitoring dashboard for team workflow management.

## Features

- **Progress Ring** — Task completion percentage at a glance
- **Flow Chart** — Top-to-bottom step display with color-coded status (green=done, blue=in progress, red=error, gray=pending)
- **Detail View** — Click any step to inspect: tools used, work content, reporting status, errors/cardinal points

## Live Demo

> Hosted on GitHub Pages
> **URL:** [https://puerkafei.github.io/task-dashboard/](https://puerkafei.github.io/task-dashboard/)

## Local Usage

Open `index.html` directly in your browser (offline fallback data included).

## Data Updates

Step status data is stored in `data/status.json`. After each task status change, the responsible Agent updates this file and pushes to GitHub.

## Tech Stack

Pure static HTML + CSS + JS, zero dependencies. Auto-refreshes every 30 seconds.
