# Separate override repository cutover

The [decision](../../docs/adr/0001-separate-workload-overrides.md) is encoded in
Artemis. This offline checkout includes a staging transfer bundle at
`handoff/microservices-charts-staging/`; its files are not referenced by the
ApplicationSet. The application-owned repository has not been created or
registered. No live cutover has occurred.

## Source contract

The platform owns `gitops/environments/<environment>/topology.yaml`,
`gitops/profiles/`, the chart, bootstrap adapters, and validators. Each listed
cell has a matching `microservices-charts/artemis/<environment>/<cell>/values.yaml`,
including disabled cells. Only the topology can enable a cell. The second Argo
source has `ref: workloads` and no render path, and the chart reads its required
last values file through `$workloads`. Helm parameters still win after the
Profile, environment, and override files. The AppProject allows only the exact
Artemis and microservices-charts repository URLs.

Local development uses an explicit source path:

```sh
cd gitops
make validate-topology test-topology validate-charts OVERRIDES_ROOT=/absolute/path/to/microservices-charts
```

The validator requires PyYAML, yq, Helm, and Kustomize (or local `kubectl
kustomize`). The raw validator runs before Helm and rejects protected fields,
nulls, duplicate keys, unexpected types, and nested empty containers. The
merged chart render then enforces schema and messaging policies. A complete
external security example can intentionally contain an empty multicast queue
list. The staging bundle can be passed explicitly for offline migration tests;
it is not a deployable checkout.

## Protected check and repository rules

On the authorized work computer, use a platform-controlled CI workflow and
validator revision. For each proposed override commit, check out the intended
Artemis revision and microservices-charts commit into separate, clean Git
checkouts. Run:

```sh
cd /path/to/artemis
./gitops/scripts/validate-revision-pair.sh \
  --environment prod \
  --overrides-root /path/to/microservices-charts \
  --report /path/to/ci-artifacts/prod-revision-pair.json
```

Repeat for each environment being promoted. The script requires the rendered
selected override revision to be the exact 40-character checkout commit,
checks the Artemis selection against its checkout, validates that environment,
and records both resolved commits in the report. A branch label or placeholder
is never accepted as a selected override commit. Re-run when either commit
changes. Use the corresponding two commits together for rollback. The
`make -C gitops release-gate` target requires this check for all three
environments through `OVERRIDES_TEST_ROOT`, `OVERRIDES_NONPROD_ROOT`, and
`OVERRIDES_PROD_ROOT`, in addition to its explicit `OVERRIDES_ROOT` input.

Protect the required check outside the application authors' write scope. Set
an organization or repository ruleset on microservices-charts that requires the
platform-run validation status, including for administrators where policy
requires. Restrict workflow, ruleset, and validator changes to platform owners;
a team-editable workflow calling the validator is not sufficient enforcement.
Require pull requests and platform review for production, listener, Secret
reference, authorization, and client-network changes. Add CODEOWNERS to route
reviews, and enable the ruleset's code-owner-review requirement; CODEOWNERS by
itself does not require a review. Prevent direct pushes and bypass except the
named emergency process. Apply equivalent protection to Artemis bootstrap,
Profile, chart, and validator changes.

## External setup and promotion

1. Transfer all 14 files from the staging bundle to the authorized second
   repository, preserving content. Compare against the bundle's `SHA256SUMS`
   and confirm disabled entries are present. Do not leave an active editable
   copy in Artemis.
2. Establish repository permissions: application authors can propose only
   override changes, and platform owners control repository administration,
   validation policy, and the required status. Configure the protected ruleset
   and ownership review above.
3. Register the exact microservices-charts repository URL and read credentials
   in each cluster-local Argo CD instance through platform-owned configuration.
   Replace the placeholder URL in `bootstrap/<environment>/cluster.patch.yaml`
   and the base template, keeping the AppProject and source URL identical.
4. Select an approved immutable override commit independently for test,
   nonprod, and prod in the platform-owned adapter patches. Set the Artemis
   root revision through the existing platform root input. Run the revision
   pair check at the intended Artemis commit and record both commits.
5. Review the Argo diff, names, namespaces, PVC identities, network access,
   destinations, and disabled-cell set. Promote through test, nonprod, then
   production using the organization's existing change gates. Roll back both
   revisions as a compatible pair. Perform live actions only from the
   authorized work computer.

The placeholder repository URL and selected override revisions in this offline
copy intentionally prevent a deployable cutover until those external inputs
are supplied. No cloud credential or remote repository is present here.
