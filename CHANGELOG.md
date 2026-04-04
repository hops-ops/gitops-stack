### What's changed in v0.5.0

* chore(deps): update helm release argo-cd to v9.4.16 (#7) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* chore(deps): update helm release argo-cd to v9.4.17 (#8) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* feat: ESO integration + change default projects path to apps/ (by @patrickleet)

  ESO integration for ArgoCD repo credentials:
  - ExternalSecret pulls GitHub App creds from AWS Secrets Manager
  - Projects/Crossplane apps gated on repo creds when ESO enabled
  - Usage protects deletion ordering
  - 5 new unit tests (17 total, all passing)

  DX improvements:
  - Default projects.path changed from .gitops/deploy to apps/
  - Works with hops-ops/gitops-template for intuitive repo structure

  Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>


See full diff: [v0.4.0...v0.5.0](https://github.com/hops-ops/gitops-stack/compare/v0.4.0...v0.5.0)
