#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
artemis_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
environment=''
overrides_root=''
report=''
while (($#)); do
  case "$1" in
    --environment) environment=$2; shift 2 ;;
    --overrides-root) overrides_root=$2; shift 2 ;;
    --report) report=$2; shift 2 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ "$environment" == test || "$environment" == nonprod || "$environment" == prod ]] || {
  printf '%s\n' 'select --environment test|nonprod|prod' >&2; exit 2;
}
[[ -n "$overrides_root" && -d "$overrides_root/artemis" ]] || {
  printf '%s\n' 'provide --overrides-root as a complete microservices-charts checkout' >&2; exit 2;
}
overrides_root=$(CDPATH= cd -- "$overrides_root" && pwd)
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required for the revision pair report' >&2; exit 2; }
[[ "$(git -C "$overrides_root" rev-parse --show-toplevel 2>/dev/null)" == "$overrides_root" ]] || {
  printf '%s\n' 'override input must be its own Git checkout, not the staging bundle' >&2; exit 2;
}
[[ -z "$(git -C "$artemis_root" status --porcelain)" && -z "$(git -C "$overrides_root" status --porcelain)" ]] || {
  printf '%s\n' 'both revision checkouts must be clean' >&2; exit 2;
}
artemis_commit=$(git -C "$artemis_root" rev-parse HEAD)
overrides_commit=$(git -C "$overrides_root" rev-parse HEAD)
rendered=$(mktemp "${TMPDIR:-/tmp}/artemis-selected-revisions.XXXXXX")
trap 'rm -f "$rendered"' EXIT
if command -v kustomize >/dev/null 2>&1; then
  kustomize build "$artemis_root/gitops/argocd/bootstrap/$environment" > "$rendered"
else
  kubectl kustomize "$artemis_root/gitops/argocd/bootstrap/$environment" > "$rendered"
fi
selected_override=$(yq ea -r 'select(.kind == "ApplicationSet") | .spec.template.spec.sources[1].targetRevision' "$rendered")
selected_repository=$(yq ea -r 'select(.kind == "ApplicationSet") | .spec.template.spec.sources[1].repoURL' "$rendered")
[[ "$selected_repository" == https://* && "$selected_repository" != *example.invalid* ]] || {
  printf 'override repository URL is still a placeholder or unsupported: %s\n' "$selected_repository" >&2; exit 1;
}
[[ "$selected_override" =~ ^[a-f0-9]{40}$ && "$selected_override" == "$overrides_commit" ]] || {
  printf 'selected override revision %s does not match checkout HEAD %s\n' "$selected_override" "$overrides_commit" >&2; exit 1;
}
selected_artemis=$(yq ea -r 'select(.kind == "ApplicationSet") | .spec.template.spec.sources[0].targetRevision' "$rendered")
branch=$(git -C "$artemis_root" branch --show-current)
resolved_artemis=$(git -C "$artemis_root" rev-parse --verify "${selected_artemis}^{commit}" 2>/dev/null || true)
[[ -n "$resolved_artemis" ]] || resolved_artemis=$(git -C "$artemis_root" rev-parse --verify "refs/remotes/origin/${selected_artemis}^{commit}" 2>/dev/null || true)
[[ "$selected_artemis" == "$artemis_commit" || "$selected_artemis" == "$branch" || "$resolved_artemis" == "$artemis_commit" ]] || {
  printf 'selected Artemis revision %s does not resolve to checkout HEAD %s\n' "$selected_artemis" "$artemis_commit" >&2; exit 1;
}
report=${report:-${TMPDIR:-/tmp}/artemis-$environment-topology-validation.json}
[[ "$report" == /* ]] || report="$artemis_root/gitops/$report"
"$script_dir/validate-topology.sh" --environment "$environment" --overrides-root "$overrides_root" --report "$report"
pair_report=$(mktemp "${TMPDIR:-/tmp}/artemis-pair-report.XXXXXX")
jq --arg artemis "$artemis_commit" --arg overrides "$overrides_commit" \
  '. + {artemisCommit: $artemis, overridesCommit: $overrides}' "$report" > "$pair_report"
mv "$pair_report" "$report"
printf 'validated revision pair: Artemis %s, overrides %s, environment %s\n' \
  "$artemis_commit" "$overrides_commit" "$environment"
