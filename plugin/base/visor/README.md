# `.inspire/visor/`

The configuration of `/inspire:visor`, which serves `inspire_kb/` as a local website
built with Quartz.

| Path | What it holds |
|---|---|
| `visor.yaml` | The Quartz version, the Node image used when the host has no Node 22 or later, and the port. |
| `quartz.config.yaml` | The Quartz configuration: site settings, the paths left out of the site, and the plugins the site uses. |
| `plugins/inspire/` | A Quartz plugin that adds each file's unit kind, `module` and `lifecycle` to the content index, and redirects the site root to the KB's `README.md`. |
| `plugins/inspire-graph/` | The graph panel: it colours each node by its unit kind and lists the kinds on screen in a legend. |
| `.quartz/` | The Quartz installation and the built site. It is gitignored, and the visor installs it when it is missing or holds another Quartz version. |

`/inspire:update` keeps a project's changes to these files, so a project may change the
configuration and add its own Quartz plugins under `plugins/`.
