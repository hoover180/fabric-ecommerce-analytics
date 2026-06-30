# Deployment Pipeline

## Design Rationale

This document describes a **Dev → Test → Prod** deployment pipeline pattern for
this portfolio project. All work was performed in a single Fabric workspace — a
deliberate scope decision for a solo, time-boxed project, not a claim that three
environments were actually provisioned. The design below reflects how this pattern
would be implemented in an enterprise setting using Microsoft Fabric features such
as Deployment Pipelines, Deployment Rules, Git Integration, and environment-specific
configuration, where applicable.

Separating development, validation, and production promotion reduces the risk of
introducing breaking changes, provides reproducible releases, and supports
environment-specific configuration without maintaining separate codebases.

## Pipeline Stages

### Dev

- Primary development workspace with full read/write access
- Fabric Git Integration configured against the `main` branch
- Contains: Lakehouse, Warehouse, Notebooks, Dataflows Gen2, Pipelines,
  Semantic Model, Power BI reports
- Pre-promotion validation: manual execution of the Gold layer validation suite
  (`/gold/sql/validation/`) — schema checks, row counts, referential integrity,
  and revenue reconciliation

### Test

- Dedicated integration testing environment
- Promotion prerequisites from Dev:
  - All Gold validation scripts pass
  - Row count reconciliation (Silver → Gold) within tolerance
  - GitHub Actions SQL linting workflow passes successfully (`sql_lint.yml`)
- Promoted via **Fabric Deployment Pipelines** using item-level promotion
  (not a full workspace copy)

### Prod

- Deployment-only environment — analysts and downstream consumers have read
  access only
- Promotion gates from Test: all Test validations pass, manual approval step
  in the Deployment Pipeline UI
- Power BI reports connect exclusively to the Prod semantic model
- Row-Level Security (RLS) policies reviewed and tested prior to promotion

## Tooling Boundary: Deployment Pipelines vs. Git Integration

Fabric provides two distinct, complementary mechanisms:

- **Fabric Git Integration** — version control and source-of-truth for the
  **Dev** workspace. It does not perform cross-environment promotion.
- **Fabric Deployment Pipelines** — handle Dev → Test → Prod promotion via the
  Fabric UI. **Deployment Rules** manage environment-specific configuration
  (connection rebinding, parameter substitution) during promotion.

The Dev workspace stays synchronized with `main`. Deployment Pipelines promote
the current state of Fabric items from Dev into downstream environments — Git
is the Dev backup mechanism, not the deployment trigger.

## Promotion Scope

| Item Type        | Promoted | Notes                                                                                                                                                                      |
| ---------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Lakehouse        | Yes      | Lakehouse artifact promoted; underlying data remains environment-specific. Downstream connections rebound via Deployment Rules.                                            |
| Warehouse        | Yes      | Warehouse item promoted as a single Fabric artifact. Database objects (tables, views, procedures) are included as part of the warehouse rather than promoted individually. |
| Notebooks        | Yes      | Code promoted as-is; environment-specific paths resolved dynamically via workspace context APIs (`mssparkutils.runtime.context`) or Fabric Environment configurations.     |
| Dataflows Gen2   | Yes      | Promoted via pipeline; connections re-bound using Deployment Rules or parameterized connection strings where supported.                                                    |
| Semantic Model   | Yes      | Storage target re-bound to destination Lakehouse/Warehouse via Deployment Rules.                                                                                           |
| Power BI Reports | Yes      | Promoted after the underlying semantic model is validated in the target environment.                                                                                       |

## Environment-Specific State Management

Notebooks avoid hardcoded workspace references by resolving context dynamically
at runtime (via workspace context APIs or Fabric Environment configuration)
rather than hardcoding paths or IDs, allowing the same code to run unmodified
across Dev, Test, and Prod.

## CI/CD Integration

SQL changes to `/gold/sql/` trigger automated linting via GitHub Actions
(`.github/workflows/sql_lint.yml`) on pushes and pull requests, using sqlfluff
for style and structural validation. This serves as an automated quality gate
before changes are considered ready for promotion into downstream environments.

## Git Integration

- The Dev workspace remains continuously synchronized with the GitHub `main`
  branch via Fabric Git Integration
- Deployment Pipelines promote the current state of Fabric items from Dev to
  Test and Prod, independent of Git tags
- Release points are tracked through Git commit history and meaningful
  commit messages

## Rollback Procedure

If a regression reaches Prod:

1. Revert the affected item in the Dev workspace to the last known-good
   version via Git, then redeploy it through the Deployment Pipeline to
   Test and Prod
2. For data-level regressions, restore the affected Delta table(s) using
   Delta Lake Time Travel (`RESTORE TABLE ... TO TIMESTAMP AS OF ...`)
3. Re-execute the full Gold validation suite to confirm the restored state
4. Document the incident, root cause, and remediation in
   `/docs/transformation_log.md`
