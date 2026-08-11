# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Jekyll static site (personal site for Rebecca Chapin, `rebeccachapin.com`), built with the `github-pages` gem and deployed via GitHub Pages on push to `main`.

## Commands

```
script/bootstrap   # installs Ruby via rbenv (+ Homebrew deps on macOS) and gems
script/serve        # runs bootstrap, then `bundle exec jekyll serve`
```

There is no separate lint or test suite. To sanity-check a change without serving, run `bundle exec jekyll build` and check for errors/warnings in the output.

## Content architecture

The top-level nav (`index.markdown`, `play.markdown`, `work.markdown`) is driven by `_config.yml`'s `header.pages`. `play` and `work` are each a "blog" landing page (`layout: blog`) that lists sub-collections ("series") via a `features` front-matter array rendered by `_includes/features.html`.

Each series lives in its own directory, e.g. `work/data_engineering/` or `play/misfit_on_the_trail/`:

- `contents.md` — the series landing page (`layout: contents`), with a `series_name` front-matter key matching the directory name.
- `_posts/` — the posts in that series (`layout: post`), named the standard Jekyll way (`YYYY-MM-DD-title.md`).

**Categories are inferred from the directory path**, not set explicitly in post front matter: a post at `work/data_engineering/_posts/2024-...md` gets categories `['work', 'data_engineering']` automatically. Both layouts and the `blog`/`contents`/`feature` layouts rely on this:

- `_layouts/blog.html` (used by `work.markdown`/`play.markdown`) lists recent posts via `site.categories[page.slug]` — i.e. the top-level category (`work` or `play`), pulling posts across all series in that section.
- `_layouts/contents.html` and `_layouts/feature.html` list a single series' posts via `site.categories[page.series_name]` — the leaf category.

To add a new post to an existing series: drop a file into that series' `_posts/` directory with standard front matter (`layout: post`, `title`, `subtitle`, `date`, `tags`). No other file needs to change; the category-derived listings pick it up automatically.

To add a new series: create `<section>/<series_name>/contents.md` (with `layout: contents` and matching `series_name`) and a `<section>/<series_name>/_posts/` directory, then add an entry to the parent page's (`work.markdown`/`play.markdown`) `features` list.

## Layouts and includes

- `_layouts/default.html` is the base; `post`, `blog`, `contents`, `feature`, `home` build on top of it.
- `_includes/head.html`, `header.html`, `footer.html`, `foot.html` are shared chrome included by every layout.
- `_includes/features.html` renders a `features` front-matter array (used by both `work.markdown` and `play.markdown`).
- Styles are in `_sass/`, compiled into `assets/css/main.css`.

## Deployment

`CNAME` pins the custom domain (`www.rebeccachapin.com`). Pushing to `main` triggers GitHub Pages' Jekyll build and deploy; there's no separate CI config in this repo.
