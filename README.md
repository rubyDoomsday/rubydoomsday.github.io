# rubydoomsday.github.io

Personal site for Rebecca Chapin (rebeccachapin.com). It's a Jekyll site, built with the `github-pages` gem and deployed via GitHub Pages.

## Running it locally

```
script/bootstrap   # installs Ruby (via rbenv) and gem dependencies
script/serve        # runs bootstrap, then starts the Jekyll dev server
```

`script/serve` runs `bundle exec jekyll serve`. The site is served at `http://localhost:4000` by default.

On macOS, `script/bootstrap` also installs Homebrew dependencies from the `Brewfile` (currently just `rbenv`).

## Structure

| Path | What it is |
| --- | --- |
| `index.markdown`, `play.markdown`, `work.markdown` | The three top-level pages |
| `_layouts/` | Page templates (home, post, blog, feature, contents, default) |
| `_includes/` | Shared partials (header, footer, head, signup, lightbox, etc.) |
| `_sass/` | Stylesheets |
| `assets/` | Images and other static assets |
| `_config.yml` | Site settings: title, nav pages, footer links, plugins |

## Deployment

Pushing to `main` builds and deploys the site via GitHub Pages. `CNAME` points the custom domain (`www.rebeccachapin.com`) at it.
