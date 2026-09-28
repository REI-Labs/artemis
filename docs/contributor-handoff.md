# Contributor handoff

Reviewed 2026-09-28 against repository revision `3a72864`, recent Artemis Codex
chat conclusions (including the separate-override implementation), and local
memory availability. The local Codex memory directory was empty. This is a
repository handoff, not a certification of the deployed environment or an
exhaustive export of historical conversations.

## Start a fresh Codex session

Open the repository root. The checked-in [AGENTS.md](../AGENTS.md) supplies
project instructions; personal chat history and personal skills are not needed.
Codex's instruction discovery is described in the
[official AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md).
A useful first prompt is:

> Read AGENTS.md and docs/contributor-handoff.md. Inspect the current Git status,
> then use docs/repository-guide.md to identify the authoritative files for my
> task. Treat this checkout as offline. Implement and validate repository-owned
> changes, preserve existing work, and report any acceptance that requires the
> authorized work computer. Do not commit, push, or deploy without my request.

For a first contribution, finish when the intended files are changed, relevant
checks pass, documentation links pass, and unavailable checks are explicitly
reported. Local rendering is evidence of intended configuration, not live health.
Use the [repository guide](repository-guide.md) for file ownership and the
[GitOps index](../gitops/docs/README.md) for task-specific reading.

Install tools for the work being done: Git, Make, Bash, Python 3 with PyYAML,
and the renderer versions in [toolchain.yaml](../gitops/toolchain.yaml) for
GitOps; Docker with Compose v2 for the local broker; Java/Maven for the full
repository unit-test gate. Consult the [local guide](../local/README.md) and
[performance guide](../performance/README.md) for their build paths. Use
`make validate-toolchain` to check renderer versions. No cloud credentials are
needed for repository editing and offline rendering.

Run the root [README validation commands](../README.md#gitops-validation),
passing an explicit override checkout or staging bundle. `make validate` also
requires that path. Report `NOT_RUN` schema/artifact checks separately from
passes; they do not satisfy a release gate.

## Current decisions and traps from prior sessions

| Topic | Durable guidance and authoritative reference |
| --- | --- |
| Two repositories | Artemis owns platform behavior and the allowed override contract. Application teams propose values in `microservices-charts`. The local split is implemented; external setup and cutover remain pending. See [ADR 0001](adr/0001-separate-workload-overrides.md) and [cutover](../gitops/docs/override-cutover.md). |
| Old paths in chats | Topology is now `gitops/environments/<environment>/topology.yaml`; Profiles are `gitops/profiles/`; workload values belong to the separate repository. Earlier chats using `gitops/argocd/topology`, `gitops/argocd/profiles`, or `gitops/workloads` describe the old layout. |
| Staged examples | [The transfer bundle](../handoff/microservices-charts-staging/README.md) preserves all 14 overrides, including disabled cells. It is not an Argo deployment source. `test-sky2` is a disabled messaging-policy example, not an instruction to enable it. See [team policies](../gitops/docs/team-messaging-policies.md). |
| Profile versus cell features | Profiles define approved defaults; topology `features` is platform-owned; destination `policyOverrides` is the bounded application interface. Making `features: {}` optional was discussed but is not implemented: the validator still requires the map. See [topology validator](../gitops/scripts/validate-topology.sh). |
| HA and readiness | A Workload Cell is one active/passive pair. Healthy standby readiness intentionally succeeds, so both peers can be Service endpoints. The `broker` DNS alias adds no active-only routing. Client retry/failover must be tested through the exact Service path in both directions. See [failover runbook](../gitops/docs/runbooks/failover-failback.md). |
| Performance evidence | Supervised two-pod tunnels support laptop testing, but bypass Service routing. A successful tunneled test cannot certify the in-cluster Service path. See [performance validation](../performance/README.md). |
| Keycloak URLs | Realm issuer, browser redirect, and allowed network destination are different inputs. Cell `managementHost` drives `https://<host>/console`; `allowInClusterEgress` controls pod-selector access, not the redirect. See [Keycloak checklist](../gitops/docs/runbooks/keycloak-hawtio-work-computer-checklist.md) and [redirect inventory](../gitops/docs/runbooks/hawtio-redirect-inventory.md). |
| Hawtio login | Local credentials are per broker deployment. A login success followed by Jolokia 403s or a return to the console login page is not proof of a Keycloak redirect. Check session stickiness, authorization, and actual browser requests using [Hawtio diagnosis](../gitops/docs/runbooks/hawtio-access-diagnosis.md). |
| Argo stale state | Check the selected revisions, ApplicationSet, and generated Application before changing workload resources. `--enable-helm` is owned by platform Argo configuration; a cached render error may need Hard Refresh after that configuration is applied. See [Argo guide](../gitops/argocd/README.md). |
| Renaming or disabling cells | `create-update` intentionally retains old Applications. A new name is not a migration of brokers, data, PVCs, or coordination identity. Follow [cell retirement](../gitops/docs/runbooks/workload-cell-retirement.md). |
| ZooKeeper startup | JVM heap flags use Java units such as `-Xmx1g`; Kubernetes limits use units such as `Gi`. The fix and regression coverage are present. Rollouts still require the [ZooKeeper procedure](../gitops/kustomize/zookeeper/README.md). |
| Future architecture | Multiple actives and DR are [discussion](../gitops/docs/workload-cell-evolution-discussion.md), not the accepted runtime design. The [shared private NLB](../gitops/docs/adr-shared-private-nlb.md) is an accepted design pending platform integration. Protocol removal requires [runtime inventory](../gitops/docs/runbooks/protocol-acceptor-inventory.md), not an inference from absent client code. |

Current code, schemas, tests, and accepted ADRs must agree. If they conflict,
resolve the discrepancy explicitly. A historical chat recommendation or a
successful check from an older revision does not override the current contract.

## Remaining handoff and acceptance work

The following items need team ownership. Role names below are suggested
responsibilities, not confirmed assignees. Record the actual owner, tracking
issue/change, evidence location, and completion date in the approved team
tracker. Keep credentials and sensitive evidence outside this repository.

| Work | Suggested owner | Completion evidence |
| --- | --- | --- |
| Override repository cutover | Platform/repository administrators | All bundle files transferred and checksums verified; exact repository URLs/read access registered; protected validation and reviews enforced; approved Artemis/override commit pairs validated and promoted using the [cutover guide](../gitops/docs/override-cutover.md). |
| Keycloak network and browser acceptance | Identity, network, platform owners | Approved destination CIDRs/TCP 443 for test/nonprod; pod-network connectivity; real DNS/certificates; exact redirects and role mappings; successful browser acceptance from the [checklist](../gitops/docs/runbooks/keycloak-hawtio-work-computer-checklist.md). |
| Keycloak management tooling | Identity owner | Matching container/tool versions built and tested against the work environment; sanitized configuration reviewed; existing redirects preserved. [Toolkit](../tools/keycloak/README.md) has offline tests, but image/live compatibility was not established by the reviewed sessions. |
| HA, durability, and recovery | Platform and application owners | Exact client protocol/URL and admitted network path tested; both failover directions and acknowledged-message accounting recorded; measured recovery compared with agreed targets. Follow [failover](../gitops/docs/runbooks/failover-failback.md) and [backup/restore](../gitops/docs/runbooks/backup-restore.md). |
| External clients and protocol retirement | Network, security, application owners | NLB integration gates, listener ownership, real client inventory, and migration acceptance complete before enabling external cells or retiring protocols. See [NLB ADR](../gitops/docs/adr-shared-private-nlb.md). |
| Access and operational ownership transfer | Project lead/platform administrators | Named maintainers for both repositories, required reviews/CI, Argo/Terraform, image supply, DNS/certificates, identity, secrets, monitoring/on-call, and backup ownership confirmed through the organization's offboarding process. Access transferred through approved systems, not shared personal credentials. |
| Deployment baseline | Release owner | Record deployed Artemis and override commits per environment, outstanding incidents, last acceptance reports, rollback pair, and outstanding change approvals. This offline copy cannot establish those facts. |

Optional cleanup: make empty topology `features` optional only through a
separate reviewed validator/template change with regression coverage. It is not
a handoff blocker and should not be presented as completed work.

## Keep the next handoff small

When a chat resolves a lasting behavior or operational gotcha, update its
existing ADR, area README, or runbook and link it from the relevant index.
Record unresolved work and its acceptance criteria in the issue tracker. Use
[issue conventions](agents/issue-tracker.md) and [domain conventions](agents/domain.md)
without requiring personal skill installation. Update this status table when
external acceptance is completed; do not preserve completed work as permanently
pending. Keep raw conversations, credential exports, screenshots containing
sessions, and generated reports out of source documentation.
