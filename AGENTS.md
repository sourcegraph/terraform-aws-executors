# AGENTS.md

Terraform module for provisioning Sourcegraph executors on AWS. This is
infrastructure-as-code (HCL), not an application — there is no app to run.

## Layout

- `main.tf`, `variables.tf`, `providers.tf` — root module wiring the submodules together.
- `modules/` — the submodules: `networking`, `docker-mirror`, `executors`, `credentials`.
- `examples/` — usable configurations: `single-executor`, `private-single-executor`, `multiple-executors`.
- `iam-policy.json` — example minimal IAM policy for deploy/destroy.
- `.buildkite/` — CI scripts (the source of truth for the commands below).

## Toolchain

Tool versions are pinned in `.tool-versions` (managed via mise or asdf):
Terraform `1.10.4`, `shfmt` `3.2.0`, `shellcheck` `0.10.0`, `github-cli` `2.65.0`.
The root module requires Terraform `>= 1.1.0, < 2.0.0` and the AWS provider
`>= 3.0, < 5.0.0` (see `providers.tf`).

## Commands

Run these from the repository root; they mirror the Buildkite pipeline.

```bash
# Format HCL (CI checks with -check)
terraform fmt -recursive .

# Validate every module and example (matches .buildkite/terraform-validate.sh).
# Requires AWS_DEFAULT_REGION to be set, e.g. us-east-2.
.buildkite/terraform-validate.sh

# Shell script formatting and linting
.buildkite/shfmt.sh        # shfmt -i 2 -ci -d .
.buildkite/shellcheck.sh   # shellcheck across all *.sh

# Security scan (soft-fail in CI)
.buildkite/ci-checkov.sh   # installs and runs checkov
```

To validate a single module manually:

```bash
cd modules/executors
terraform init
terraform validate .
```

## Conventions

- Keep all HCL `terraform fmt`-clean and shell scripts `shfmt -i 2 -ci` / `shellcheck`-clean before committing.
- The module's major and minor version must match the target Sourcegraph version; keep changes consistent across the root module and all submodules.
- `.editorconfig` defines whitespace rules — respect it.
- Do not delete `.use_mise`; CI uses it to choose mise vs. asdf for tool installation.
