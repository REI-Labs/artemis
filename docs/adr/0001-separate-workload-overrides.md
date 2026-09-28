# Separate application-owned Workload Cell overrides

Status: Implemented locally; external repository and deployment cutover pending. Date: 2026-09-25.

Application teams will maintain approved Workload Cell overrides in a separate
Git repository named `microservices-charts`. Artemis retains platform code,
topology, integrations, Profiles, and validation policy. This gives teams one
place to configure messaging without write access to the Artemis repository.

## Team explanation

Artemis defines the platform and what can be configured.
`microservices-charts` defines each Workload Cell's approved settings.
Argo CD combines the two approved revisions into the deployed configuration.

This decision changes configuration ownership and file locations. It does not
change the active/passive architecture, create one Workload Cell per team, or
change existing runtime identities or messaging behavior.

## Target layout

```text
artemis/
└── gitops/
    ├── environments/
    │   ├── test/
    │   │   ├── topology.yaml
    │   │   └── artemis-values.yaml
    │   ├── nonprod/                 # Same structure
    │   └── prod/                    # Same structure
    ├── profiles/
    │   ├── standard/
    │   │   ├── profile.yaml
    │   │   └── values.yaml
    │   └── application-messaging/
    │       ├── profile.yaml
    │       └── values.yaml
    ├── argocd/
    │   ├── bootstrap/               # Preserve existing root paths
    │   └── platform-config/
    ├── charts/
    ├── kustomize/
    └── releases/

microservices-charts/
└── artemis/
    ├── test/
    │   ├── test-sky/values.yaml
    │   └── test-sky2/values.yaml
    ├── nonprod/
    │   └── <workload-cell>/values.yaml
    └── prod/
        └── <workload-cell>/values.yaml
```

The second repository's Artemis subtree contains values only. Its name does
not require copying or wrapping the Artemis chart. Other content in that
repository must not be rendered by the Artemis Application.

## Ownership

| Configuration | Owner and location |
| --- | --- |
| Cell identity, namespace, coordination ID, management hostname, sizing, enablement, Profile selection, typed features | Platform team; Artemis environment topology |
| Storage class, Keycloak, scheduling, cluster-wide network integration | Platform team; Artemis environment values |
| Shared broker behavior, messaging policies, permitted policy overrides | Platform team; Artemis Profiles |
| Chart, operator, ZooKeeper, HA, durability, images, Platform Release | Platform team; Artemis |
| Declared destinations and permitted retry/expiry overrides | Application teams; microservices-charts |
| Approved listeners, broker alias, client CIDRs/selectors | Application teams with required review; microservices-charts |
| Deferred external identity Secret references and authorization rules | Existing restricted interface; microservices-charts, with security/platform review |
| Validation rules, required checks, deployment-source selection | Platform-controlled configuration |

Preserve the current allowed workload fields during migration. Do not broaden
permissions simply because a field exists in the full chart schema. Secret
contents and credentials remain outside both repositories. External and batch
cells retain their existing disabled state.

An override file cannot create or enable a Workload Cell. The platform-owned
topology remains the discovery input. A new cell requires a platform topology
change and a matching validated override file. Shared cells need coordinated
review of their single values file; this change does not introduce per-team
file merging within a cell.

## Composition and revisions

Convert generated Workload Cell Applications to two Argo CD sources:

1. The Artemis Git source renders the existing chart and supplies the selected
   Profile and environment values.
2. The microservices-charts Git source has a `ref` alias and no `path` or
   `chart`, so it supplies values without generating Kubernetes resources.

Use the external source alias in the final Helm values-file entry, shaped as
`$workloads/artemis/<environment>/<workload-cell>/values.yaml`. Keep the
effective order: chart defaults, Profile, environment, workload overrides,
then platform-owned Helm parameters. Preserve all derived identities and
existing typed-feature behavior.

Each environment explicitly selects an override revision independently of its
Artemis revision. Production uses an approved immutable commit. Validation and
promotion record both resolved commits; rollback restores a compatible pair.
Do not reuse Artemis's root revision automatically for the other repository,
and do not invent an unprotected default branch as a deployment fallback.

The existing root revision injection continues to govern every Artemis source,
including the topology generator, operator, ZooKeeper, and chart source. The
new override revision has its own platform-controlled input. AppProject source
permissions must allow the exact second repository. Repository registration
and read credentials remain platform-owned work-computer setup.

Missing required values must fail rendering. Do not set
`ignoreMissingValueFiles` to conceal an incomplete migration.

Reference: [Argo CD external Git values sources](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/#helm-value-files-from-external-git-repository).

## Enforcing the override contract

Repository separation alone does not restrict Helm fields. The current
`gitops/scripts/validate-topology.sh` checks workload ownership before rendering;
that contract must continue to apply to the external files.

- Validate raw override files against a strict, platform-owned allowlist before
  merging them with platform values. Reject unknown and protected fields,
  including attempts to bypass checks through nulls, empty containers, or
  unexpected YAML types.
- Render effective values against the intended Artemis revision and run chart
  schema and messaging-policy checks.
- Require these checks before merging or selecting an override revision. Keep
  validator code and required workflow configuration protected from application
  authors; a team-editable workflow cannot be its own enforcement mechanism.
- Use branch/ruleset protections and required ownership review, including
  production and client-access changes. CODEOWNERS alone does not enforce a
  merge requirement.
- Keep Argo Application specifications and source revisions platform-controlled.
  Argo's values merge does not itself execute the repository ownership validator.

The chart's full schema describes all supported platform configuration; passing
it alone does not prove that an application team was allowed to set a field.

## Migration and acceptance

1. Capture existing offline render results and inventory all Workload Cells,
   including disabled entries, before changing paths.
2. Move `gitops/argocd/topology/<environment>.yaml` to
   `gitops/environments/<environment>/topology.yaml`. Move
   `gitops/argocd/profiles/` to `gitops/profiles/`.
3. Transfer every existing workload values file into the new repository layout,
   preserving content. Supply a complete local handoff bundle if no checkout of
   microservices-charts is available; label it as staging, not an active source.
   Do not create or publish a remote repository without separate authorization.
4. Update ApplicationSets, Kustomize replacements, AppProject permissions,
   validators, render helpers, fixtures, CI interfaces, import tools, and docs.
   Local validation must accept an explicit external checkout/bundle path and
   must not require network access or silently fall back to old workload files.
5. Compare pre/post render results using the same workload data. Preserve
   Application names, namespaces, broker and coordination identities, PVC
   identities, hostnames, sync policies, and deletion/retirement protections.
6. Test independent revision propagation, exact values paths and precedence,
   missing overrides, rejected platform fields, and valid destination policies.
   Validate all three bootstrap environments and run relevant chart, topology,
   and documentation checks. Report unavailable rendering dependencies honestly.
7. Document the external cutover: populate the second remote repository, install
   protected validation and review rules, register read credentials, select
   approved revisions, review the Argo diff, and promote through environments.
   Live cutover is performed only on the authorized work computer.

Remove old workload paths from active composition once the replacement data
and validation handoff are complete. Do not retain two editable sources of
truth. Avoid unrelated profile deduplication or chart redesign in this migration.

## Relationship to existing decisions

This decision extends the [cluster composition ADR](../../gitops/docs/adr-cluster-composition.md):
the selected Artemis revision still propagates consistently, but a Workload
Cell Application now also consumes an independently selected override revision.
It replaces the assumption that all values live in the Artemis repository.
The existing stable bootstrap roots and direct topology consumption remain.

The [Workload Cell topology ADR](../../gitops/docs/adr-workload-cell-topology.md)
continues to govern isolation and capacity. The repository now encodes this composition. The handoff bundle and offline checks prepare the external cutover; deployment still requires approved revisions and platform-owned repository setup.

## Trade-off

Teams gain a smaller editing interface and separate repository permissions.
The platform takes on cross-repository compatibility checks, two-revision
promotion and rollback, and external repository setup. Keeping all files in
Artemis would be mechanically simpler, but would not provide the requested
repository ownership separation.
