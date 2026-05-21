### What's changed in v0.10.0

* chore(deps): update helm release argo-cd to v9.5.5 (#16) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* chore(deps): update helm release argo-cd to v9.5.7 (#17) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* chore(deps): update helm release argo-cd to v9.5.9 (#18) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* chore(deps): update helm release argo-cd to v9.5.11 (#19) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* chore(deps): update helm release argo-cd to v9.5.12 (#20) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* chore(deps): update helm release argo-cd to v9.5.13 (#21) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* chore(deps): update helm release argo-cd to v9.5.14 (#23) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* feat: per-component resource defaults for ArgoCD chart (by @patrickleet)

  application-controller (StatefulSet, holds repo state in memory) gets
  Guaranteed memory at 1Gi req=limit; observed P95 on pat-local was
  918Mi BestEffort. repoServer, server, applicationSet, notifications,
  dex, redis get Burstable defaults sized for chart-recommended baseline.

  Implements [[tasks/cluster-wide-resource-right-sizing-p95-observation]] tier-1 #1

* fix: bump argocd application-controller memory to 1.5Gi (by @patrickleet)

  P95 observed at 1047Mi on pat-local; the initial 1Gi default was right
  at the wall and the controller OOMKilled repeatedly (exit 137, restarts
  to 16+). 1.5Gi covers the cluster-wide state cache for our app count
  with real headroom.

  Verified on pat-local: argocd-application-controller-0 → Burstable,
  mem-lim=1536Mi, restarts=0 after pod recreation.

* chore(deps): update helm release argo-cd to v9.5.15 (#26) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>


See full diff: [v0.9.0...v0.10.0](https://github.com/hops-ops/gitops-stack/compare/v0.9.0...v0.10.0)
