# PhotoTagger

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## JavaScript Dependencies

Phoenix projects manage JS dependencies by vendoring them into `assets/vendor/` rather than using npm/node_modules. Drop the library's minified `.js` file into `assets/vendor/`, then import it from your application JS. esbuild (configured in `config/config.exs`) bundles everything in `assets/vendor/` automatically.

Current vendored libraries:

  * `topbar.js` — progress bar for LiveView navigation
  * `sortable.min.js` — [SortableJS](https://sortablejs.github.io/Sortable/) for drag-and-drop reordering

To add a new JS dependency: download the dist/minified file, place it in `assets/vendor/`, and `import` it from `assets/js/app.js` or a module under `assets/js/`.

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
