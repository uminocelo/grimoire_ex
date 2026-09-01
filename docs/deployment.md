# Deployment

`mix grimoire.build` (or `grimoire build` from the escript) produces a
plain static `_site/` directory — HTML, CSS, JS, images, `feed.xml`,
`atom.xml`, `sitemap.xml`. Deploying it is just "upload this directory to
a static host." No server-side runtime is involved.

## GitHub Pages

**Project site** (`https://user.github.io/repo`) — set `base_url` to
include the repo path, so `relative_url`/`absolute_url` compute correct
links:

```elixir
%{title: "My Site", base_url: "https://user.github.io/repo"}
```

A GitHub Actions workflow that builds and publishes on every push to `main`:

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.18"
          otp-version: "26"
      - run: mix local.hex --force
      - run: mix deps.get
      - run: mix grimoire.build
      - uses: actions/upload-pages-artifact@v3
        with:
          path: _site

  deploy:
    needs: build
    runs-on: ubuntu-24.04
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

Enable Pages under the repo's Settings → Pages → Source → "GitHub Actions".

A `_site/CNAME` file (any root-level file that doesn't start with `_` is
copied verbatim — see [`docs/site-structure.md`](site-structure.md)) sets
a custom domain: create `CNAME` (no extension) at the site root containing
just the domain name.

## Netlify

No config file is required if you set these in the Netlify UI (Site
settings → Build & deploy), or commit a `netlify.toml`:

```toml
[build]
  command = "mix local.hex --force && mix deps.get && mix grimoire.build"
  publish = "_site"

[build.environment]
  ELIXIR_VERSION = "1.18"
  OTP_VERSION = "26"
```

Netlify's build image includes `asdf`, so pinning versions via
`.tool-versions` at the repo root works too:

```
elixir 1.18.4-otp-26
erlang 26.2.5
```

## Fly.io

Fly serves static sites via a minimal container. A `Dockerfile` that builds
with Elixir and serves with a tiny static file server:

```dockerfile
FROM hexpm/elixir:1.18.4-erlang-26.2.5-alpine-3.20.3 AS build
WORKDIR /app
COPY . .
RUN mix local.hex --force && mix deps.get && mix grimoire.build

FROM pierrezemb/gostatic
COPY --from=build /app/_site /srv/http
```

```toml
# fly.toml
app = "my-site"

[http_service]
  internal_port = 8043
  force_https = true
```

`fly launch` (first time) or `fly deploy` (subsequent) ships it.

## Any other static host

The pattern is always the same: `mix grimoire.build` (or `mix
grimoire.build --dest dist` if the host expects a different directory
name), then hand the output directory to the host — S3 + CloudFront,
Cloudflare Pages, a plain `rsync` to a VPS behind nginx, all work
identically since `_site/` is just files.

## Cache-busting with `fingerprint_assets`

Set `fingerprint_assets: true` in `config.exs` to rename every file under
`assets/` to embed a content hash (`style.css` → `style.ab12cd34.css`) and
write the resulting path map to `_site/assets/manifest.json`. This lets you
set aggressive `Cache-Control` headers on `assets/` at your host/CDN
without worrying about stale cached CSS/JS after a redeploy — the URL
itself changes when the content does. See [`docs/config.md`](config.md)
and [`Grimoire.Assets`](Grimoire.Assets.html).
