# Staging handoff: microservices-charts Artemis overrides

This directory is a transfer bundle for a separate `microservices-charts` Git
repository. It is not an active Artemis deployment source and must not be
copied back under `gitops/`. No remote repository was created here.

Copy the `artemis/` subtree to the root of the authorized external checkout.
It contains one `values.yaml` for each of the 14 topology entries, including
disabled external and batch cells. Preserve file contents exactly during the
transfer. The platform-owned topology controls enablement; these files cannot
create or enable a cell.

After the transfer, the platform team must configure the actual repository URL,
read credential, and approved commit for each environment in the Artemis
bootstrap adapter. Run the protected validation workflow and the revision pair
gate against those exact checkouts before cutover. See
`gitops/docs/override-cutover.md` in Artemis.
