### What's changed in v0.5.1

* fix: make installationIdKey optional for GitHub App auth (by @patrickleet)

  ArgoCD auto-discovers installation ID from the org URL when omitted.
  Only appId and privateKey are required. installationIdKey defaults to
  empty (omitted from ExternalSecret) instead of "installationId".

  Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>

* fix: use repo name as resource name for GitHub Repository (by @patrickleet)

  Changes metadata.name from {xr-name}-gitops-repo to {repo.name}
  (e.g. pat-local-gitops) so the resource name matches the external name.

  Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>


See full diff: [v0.5.0...v0.5.1](https://github.com/hops-ops/gitops-stack/compare/v0.5.0...v0.5.1)
