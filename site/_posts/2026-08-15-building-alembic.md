---
title: Building a template engine from scratch: Alembic's design
tags:
  - alembic
  - design
excerpt: Why Grimoire's only runtime dependency is a Liquid-compatible template engine built entirely on Elixir and OTP, with no dependencies of its own.
---

Grimoire renders every layout through
[Alembic](https://hexdocs.pm/alembic_template_engine), a
Liquid-compatible template engine developed alongside it as an independent
library. Alembic has **zero runtime dependencies** of its own — the same
constraint Grimoire holds itself to, just one layer down.

## Why not use an existing library?

Elixir has template engines already — EEx ships in the standard library,
and Grimoire's own scaffolding uses it (`grimoire new`'s starter files are
EEx templates, rendered once at generation time). But EEx embeds Elixir
directly in templates. A static site generator's layouts are content a
site *author* edits, not a developer — Liquid's constrained,
non-Turing-complete syntax (`{{ variable }}`, `{% tag %}`, no arbitrary
code execution) is the better fit for that audience, the same reason
Jekyll picked it originally.

## What it actually does

- **Compile once, render many times.** `compile/2` and `render/3` are
  separate steps — a caller can parse a template's AST once and reuse it
  across many renders, rather than re-parsing on every request.
- **Full control flow**: `{% if %}` / `{% elsif %}` / `{% else %}`,
  `{% for %}` with `forloop` metadata, `{% assign %}`, comparison and
  logical operators.
- **Template inheritance**: multi-level `{% extends %}` / `{% block %}`
  chains with `{{ block.super }}` — this is what lets Grimoire's own
  `post.html`/`page.html` layouts share a common `base.html` without
  duplicating the `<head>`.
- **An ETS-backed compiled-template cache**, with mtime-based
  invalidation — a `GenServer` owns a `:public` ETS table, so concurrent
  readers hit the table directly (never serialized through the process),
  while writes go through the `GenServer` as the single writer for mutual
  exclusion, and supervision gives it fault tolerance: if the cache
  process crashes, it — and its ETS table — come back clean.
- **Custom filters** via a two-callback behaviour (`name/0`, `apply/2`),
  which is exactly how Grimoire plugs in `date_to_string`, `slugify`,
  `relative_url`, and the rest — see
  [`docs/templates.md`](https://github.com/uminocelo/grimoire_ex/blob/main/docs/templates.md#grimoires-custom-filters).

## The dependency boundary

Alembic doesn't know Grimoire exists. It compiles and renders templates
from a context map — a plain `%{"post" => %{...}, "site" => %{...}}` — and
that's the entire interface. Grimoire's Scanner, Renderer, Router, and
Builder handle everything upstream (discovering content, computing URLs,
assembling that context map) and everything downstream (writing files);
Alembic's only job is turning a template plus a context into a string.
That separation is what makes "zero runtime dependencies beyond Alembic" a
meaningful constraint rather than a technicality — the boundary between
the two projects is a plain data structure, not a shared internal API.
