---
name: terraform-giftbit
description: Terraform workflows infrastructure on AWS with Datadog and Stytch providers. Use when Codex needs to create or update Terraform modules, add or refactor resources, manage state/backends, or edit environment configuration in `config/env.tfvars` files that CI/CD iterates over.
---

# Terraform

## Overview

Use this skill to implement Terraform changes with a module-first approach, keeping environment configuration in `config/{env}.tfvars` and preserving the self-hosted S3 backend.

## Workflow

1. Identify scope and environments.
- Locate the repo and Terraform root(s).
- Enumerate environments by inspecting `config/*.tfvars`.
- Confirm which env(s) the change targets before editing.

2. Prefer reusable modules.
- Search for existing modules that already model the resource or pattern.
- If a module exists, extend it rather than duplicating resources in a root module.
- If no module exists, create one following the repo's established module layout and naming.

3. Apply environment-specific config conventions.
- Store environment-specific values only in `config/{env}.tfvars`.
- Keep root modules environment-agnostic; wire inputs through variables.
- When adding a new environment, add a new `config/{env}.tfvars` file and confirm CI/CD will pick it up.

4. Preserve backend/state behavior.
- Keep the existing self-hosted S3 backend configuration unchanged unless explicitly asked.
- Every project should have the backend configured to use the S3 backend.

5. Provider-specific considerations.
- AWS is primary; Datadog and Stytch are secondary providers used as needed.
- Align provider versions and configuration with what the repo already uses.
- Try to keep providers up to date, updating providers.tf.

6. Use makefile targets that wrap terraform commands.
- Never use terraform commands directly, always use the makefile equivalents.
- terraform init -> make init ENVIRONMENT=<env>
- terraform plan -> make plan ENVIRONMENT=<env>
- terraform apply -> make apply ENVIRONMENT=<env>
- terraform fmt -> make fmt
- terraform validate -> make validate

6. Validate changes safely.
- Run `make fmt` on changed files.
- Run `make validate` or `make plan ENVIRONMENT=<env>` only when requested or when the user asks for verification.
- Never apply unless explicitly asked.
- Never destroy.

## Conventions and Notes

- `config/` is authoritative for environment selection in CI/CD. Do not move or rename it.
- Modules are preferred for reuse and consistency; avoid copy/paste resource blocks at the root.
- Keep changes minimal and consistent with existing style, variable naming, and tagging patterns.

## Example Requests That Should Trigger This Skill

- "Create a reusable module for an S3-backed static site and wire it into our Terraform."
- "Add Datadog monitors for service X in Terraform."
- "Add Stytch configuration for environment Y and update the tfvars."
- "Refactor these EC2 resources into a module and update each env config."
