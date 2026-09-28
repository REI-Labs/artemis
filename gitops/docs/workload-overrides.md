# Workload Cell configuration

Each topology entry has one values file at
`microservices-charts/artemis/<environment>/<workloadCellName>/values.yaml`. The ApplicationSet
loads it after the reusable Profile and environment integration files, so this
is the typed seam for one HA pair's listeners, destinations, and client
NetworkPolicy sources. Internal cells normally provide only approved
`clientCidrs` or `clientSources`; broker identity and authorization references
are reserved for future external cells.

Use maps keyed by stable, review-friendly IDs for `acceptors`, `destinations`,
`networkPolicy.clientCidrs`, and external `authorization.rules`. Helm
deep-merges those maps across value layers.
Keep cluster integrations in `environments`, reusable capability defaults in a
Profile, and pair-owned messaging policy here. The platform-owned raw override validator rejects protected fields, nulls, empty nested containers, and unknown types before Helm rendering. The chart schema and effective-policy checks then validate the merged values. The topology validator requires one file for every cell, including disabled cells.

Never store users, passwords, password hashes, private keys, certificate
subjects, certificate contents, token-bearing URLs, or rendered Secrets here.
External cells may use only references to externally materialized SSL and
`*-jaas-config` Secrets. The sanitized, executable external example is
[`external-mtls-values.yaml`](../charts/artemis-ha/tests/fixtures/external-mtls-values.yaml).
For legacy Chef environment JSON, generate and review candidates with the
[`Chef ActiveMQ import workflow`](chef-activemq-import.md); never use a
generated candidate as this file without resolving its disposition report.

## Destination messaging behavior

Select a Profile-owned `messagingPolicy` on a declared destination and use
`policyOverrides` for its permitted retry and expiry settings. See the
[team guide and test example](team-messaging-policies.md). Policies are
scoped to exact addresses; arbitrary broker settings are not workload overrides.

## Local validation and promotion

Use an explicit checkout or staging bundle path. From `gitops/` run:

```sh
make validate-topology test-topology validate-charts OVERRIDES_ROOT=/absolute/path/to/microservices-charts
```

The staging bundle at `handoff/microservices-charts-staging` is a transfer artifact, not an active Artemis values source. Application authors can edit override files only in their own repository. Platform-owned validation must run against the exact Artemis and override commits selected for promotion. Branch rulesets must require that protected check and reviews by the platform/security owners for production and client-access changes. See [the cutover guide](override-cutover.md).
