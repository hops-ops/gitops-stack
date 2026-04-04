### What's changed in v0.6.0

* feat: exclude Delete from repository managementPolicies by default (by @patrickleet)

  GitHub repos should not be deletable when the XR is removed. The
  repository now uses ["Observe", "Create", "Update", "LateInitialize"]
  by default. Set spec.repository.allowDelete: true to opt in.

  Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>


See full diff: [v0.5.1...v0.6.0](https://github.com/hops-ops/gitops-stack/compare/v0.5.1...v0.6.0)
