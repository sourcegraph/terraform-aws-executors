# Release-controlled files

Files under `templates/` are the source of truth for generated Terraform and Markdown files containing release-controlled values. `sg release create` renders them automatically before the repository-defined create steps run.

The current rendered version is stored in `release/version`. `sg release run test` verifies that the generated files and version match the templates before running the repository-defined release tests.

These templates use Go `text/template` syntax. The release values used here are `{{ .Release.Version }}` (for example, `7.7.0`) and `{{ .Release.Family }}` (for example, `7-7`). See the `sg release` documentation for the complete template contract.
