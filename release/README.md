# Release-controlled files

Files under `templates/` are the source of truth for generated Terraform and Markdown files containing release-controlled values. Edit the template, then run:

```shell
python3 scripts/render_release.py
```

The default version is stored in `release/version`. Release automation passes the new version explicitly. CI runs the renderer in `--check` mode and fails when generated files do not match their templates.

Supported template values are `{{ release_version }}` (for example, `7.7.0`) and `{{ family_version }}` (for example, `7-7`).
