import models.ai.com.ops.hops.v1alpha1 as stacksv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

# ==============================================================================
# Unit tests for GitopsStack XRD
#
# Philosophy: Test YOUR API, not the provider's API.
# - render/validate already checks provider schema correctness
# - Tests should verify XRD spec fields produce expected behavior
# ==============================================================================

# ==============================================================================
# Shared observedResources: ArgoCD + repo ready (required for app emission)
# ==============================================================================
_argocdReady = [
    {
        apiVersion = "helm.m.crossplane.io/v1beta1"
        kind = "Release"
        metadata = {
            name = "placeholder-argocd"
            annotations = {"crossplane.io/composition-resource-name" = "helm-release-argocd"}
        }
        status.conditions = [
            {type = "Ready", status = "True"}
            {type = "Synced", status = "True"}
        ]
    }
    {
        apiVersion = "repo.github.m.upbound.io/v1alpha1"
        kind = "Repository"
        metadata = {
            name = "placeholder-repo"
            annotations = {"crossplane.io/composition-resource-name" = "github-repository"}
        }
        status.conditions = [
            {type = "Ready", status = "True"}
            {type = "Synced", status = "True"}
        ]
        status.atProvider = {
            fullName = "hops-ops/test-cluster-gitops"
        }
    }
]

_items = [
    # ==========================================================================
    # Test 1: Minimal input renders ArgoCD Release + GitHub Repository
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "minimal-renders-argocd-and-repo"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "test-gitops"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "argocd"
                }
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "test-cluster-gitops"
                    # Repository excludes Delete from managementPolicies by default
                    spec.managementPolicies = ["Observe", "Create", "Update", "LateInitialize"]
                }
            ]
        }
    }

    # ==========================================================================
    # Test 1b: Restricted parent policies never expand on the protected repo
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "observe-only-repository-stays-observe-only"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "observe-only"
                spec = {
                    clusterName = "test-cluster"
                    managementPolicies = ["Observe", "LateInitialize"]
                    repository.org = "hops-ops"
                }
            }
            assertResources = [
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "test-cluster-gitops"
                    spec.managementPolicies = ["Observe", "LateInitialize"]
                }
            ]
        }
    }

    # ==========================================================================
    # Test 1c: An explicit empty policy list stays empty
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "empty-management-policies-stay-empty"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "no-authority"
                spec = {
                    clusterName = "test-cluster"
                    managementPolicies = []
                    repository.org = "hops-ops"
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "argocd"
                    spec.managementPolicies = []
                }
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "test-cluster-gitops"
                    spec.managementPolicies = []
                }
            ]
        }
    }

    # ==========================================================================
    # Test 2: Custom labels merged with defaults
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "custom-labels-merged-with-defaults"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "labeled-gitops"
                spec = {
                    clusterName = "test-cluster"
                    labels = {team = "platform", environment = "staging"}
                    repository.org = "hops-ops"
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata = {
                        name = "argocd"
                        labels = {
                            "hops.ops.com.ai/managed" = "true"
                            "hops.ops.com.ai/gitopsstack" = "labeled-gitops"
                            team = "platform"
                            environment = "staging"
                        }
                    }
                }
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata = {
                        name = "test-cluster-gitops"
                        labels = {
                            "hops.ops.com.ai/managed" = "true"
                            "hops.ops.com.ai/gitopsstack" = "labeled-gitops"
                            team = "platform"
                            environment = "staging"
                        }
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 3: ArgoCD overrideAllValues replaces all defaults
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "argocd-override-all-values"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "override-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    argocd.overrideAllValues = {
                        server = {replicas = 3}
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "argocd"
                    spec.forProvider.values = {
                        server = {replicas = 3}
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 4: ArgoCD values merge with chart defaults
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "argocd-values-merge-with-defaults"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "merge-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    argocd.values = {
                        server.ingress.enabled = False
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "argocd"
                    spec.forProvider.values = {
                        crds.install = True
                        global.monitoring.enabled = True
                        global.monitoring.serviceMonitor.enabled = True
                        server.ingress.enabled = False
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 5: GitHub repo with template (no autoInit)
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "repo-template-no-autoinit"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "tmpl-test"
                spec = {
                    clusterName = "test-cluster"
                    repository = {
                        org = "hops-ops"
                        template = {
                            owner = "hops-ops"
                            repository = "gitops-template"
                        }
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "test-cluster-gitops"
                    spec.forProvider = {
                        name = "test-cluster-gitops"
                        visibility = "private"
                        hasIssues = True
                    }
                    spec.initProvider = {
                        deleteBranchOnMerge = True
                        template = [
                            {
                                owner = "hops-ops"
                                repository = "gitops-template"
                                includeAllBranches = False
                            }
                        ]
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 6: GitHub repo with autoInit (no template)
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "repo-autoinit-no-template"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "init-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                }
            }
            assertResources = [
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "test-cluster-gitops"
                    spec.forProvider = {
                        name = "test-cluster-gitops"
                        visibility = "private"
                        hasIssues = True
                    }
                    spec.initProvider = {
                        deleteBranchOnMerge = True
                        autoInit = True
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 7: Projects app appears when ArgoCD is ready
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "projects-app-gated-on-argocd-ready"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "gate-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                }
            }
            observedResources = _argocdReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "gate-test-argocd-apps"
                    spec.forProvider.manifest = {
                        apiVersion = "argoproj.io/v1alpha1"
                        kind = "Application"
                        metadata.name = "apps"
                        spec.source = {
                            path = "apps"
                            repoURL = "https://github.com/hops-ops/test-cluster-gitops.git"
                        }
                    }
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "gate-test-delete-apps-before-argocd"
                }
            ]
        }
    }

    # ==========================================================================
    # Test 8: Without crossplane.enabled, only projects app emitted (no crossplane apps)
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "no-crossplane-apps-when-disabled"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "no-xp"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                }
            }
            observedResources = _argocdReady
            # Only projects app + usage + base resources; crossplane apps absent
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "no-xp-argocd-apps"
                }
            ]
        }
    }

    # ==========================================================================
    # Test 9: Crossplane apps emitted when crossplane.enabled is true
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "crossplane-apps-emitted-when-enabled"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "xp-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    applications.crossplane.enabled = True
                }
            }
            observedResources = _argocdReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "xp-test-crossplane-app"
                    spec.forProvider.manifest = {
                        apiVersion = "argoproj.io/v1alpha1"
                        kind = "Application"
                        metadata.name = "crossplane"
                        spec.project = "default"
                        spec.source.path = "crossplane"
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 10: GitHub provider config defaults to "default"
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "github-provider-config-defaults"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "pc-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                }
            }
            assertResources = [
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "test-cluster-gitops"
                    spec.providerConfigRef = {
                        name = "default"
                        kind = "ProviderConfig"
                    }
                }
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "argocd"
                    spec.providerConfigRef = {
                        name = "test-cluster"
                        kind = "ProviderConfig"
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 11: Custom repo name and topics
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "custom-repo-name-and-topics"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "custom-repo"
                spec = {
                    clusterName = "test-cluster"
                    repository = {
                        org = "my-org"
                        name = "my-custom-gitops"
                        description = "My custom gitops repo"
                        visibility = "public"
                        topics = ["gitops", "kubernetes"]
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "my-custom-gitops"
                    spec.forProvider = {
                        name = "my-custom-gitops"
                        description = "My custom gitops repo"
                        visibility = "public"
                        topics = ["gitops", "kubernetes"]
                        hasIssues = True
                    }
                    spec.initProvider = {
                        deleteBranchOnMerge = True
                        autoInit = True
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 12: Custom projects path
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "custom-projects-path"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "path-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    applications.apps.path = "deploy/argocd"
                }
            }
            observedResources = _argocdReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "path-test-argocd-apps"
                    spec.forProvider.manifest.spec.source.path = "deploy/argocd"
                }
            ]
        }
    }

    # ==========================================================================
    # Test 13: ESO disabled by default - no ExternalSecret rendered
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "eso-disabled-by-default"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "no-eso"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                }
            }
            observedResources = _argocdReady
            # Projects app should render (no ESO gating when disabled)
            # but NO ExternalSecret Object should appear
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "no-eso-argocd-apps"
                }
            ]
        }
    }

    # ==========================================================================
    # Test 14: ESO enabled renders ExternalSecret when ArgoCD ready
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "eso-enabled-renders-external-secret"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "eso-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    externalSecrets = {
                        enabled = True
                        githubApp.secretPath = "github/argocd-creds"
                    }
                }
            }
            observedResources = _argocdReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "eso-test-argocd-repo-creds"
                    spec.forProvider.manifest = {
                        apiVersion = "external-secrets.io/v1"
                        kind = "ExternalSecret"
                        metadata = {
                            name = "argocd-repo-creds-github"
                            namespace = "argocd"
                        }
                        spec = {
                            secretStoreRef = {
                                name = "default"
                                kind = "ClusterSecretStore"
                            }
                            target.name = "argocd-repo-creds-github"
                            target.template.metadata.labels = {
                                "argocd.argoproj.io/secret-type" = "repo-creds"
                            }
                            data = [
                                {
                                    secretKey = "githubAppID"
                                    remoteRef = {
                                        key = "github/argocd-creds"
                                        property = "appId"
                                    }
                                }
                                {
                                    secretKey = "githubAppPrivateKey"
                                    remoteRef = {
                                        key = "github/argocd-creds"
                                        property = "privateKey"
                                    }
                                }
                            ]
                        }
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 15: ESO gates projects app on repo creds ready
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "eso-gates-projects-app-on-repo-creds"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "eso-gate"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    externalSecrets = {
                        enabled = True
                        githubApp.secretPath = "github/creds"
                    }
                }
            }
            # ArgoCD ready but repo creds NOT ready yet
            observedResources = _argocdReady
            # ExternalSecret should render, but projects app should NOT
            # (because ESO is enabled and repo creds aren't ready)
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "eso-gate-argocd-repo-creds"
                }
            ]
        }
    }

    # ==========================================================================
    # Test 16: ESO + repo creds ready unlocks projects app
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "eso-repo-creds-ready-unlocks-projects-app"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "eso-unlock"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    externalSecrets = {
                        enabled = True
                        githubApp.secretPath = "github/creds"
                    }
                }
            }
            observedResources = _argocdReady + [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata = {
                        name = "eso-unlock-argocd-repo-creds"
                        annotations = {"crossplane.io/composition-resource-name" = "external-secret-argocd-repo-creds"}
                    }
                    status.conditions = [
                        {type = "Ready", status = "True"}
                        {type = "Synced", status = "True"}
                    ]
                }
            ]
            # Now projects app AND usage should render
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "eso-unlock-argocd-apps"
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "eso-unlock-delete-repo-creds-before-argocd"
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "eso-unlock-delete-apps-before-argocd"
                }
            ]
        }
    }

    # ==========================================================================
    # Test 17: Custom ESO secret store and key names
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "eso-custom-secret-store-and-keys"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "eso-custom"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "my-org"
                    externalSecrets = {
                        enabled = True
                        secretStoreName = "aws-secrets"
                        githubApp = {
                            secretPath = "prod/github/app"
                            appIdKey = "app_id"
                            installationIdKey = "install_id"
                            privateKeyKey = "pem_key"
                        }
                    }
                }
            }
            observedResources = _argocdReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "eso-custom-argocd-repo-creds"
                    spec.forProvider.manifest.spec = {
                        secretStoreRef = {
                            name = "aws-secrets"
                            kind = "ClusterSecretStore"
                        }
                        target.template.data.url = "https://github.com/my-org"
                        data = [
                            {
                                secretKey = "githubAppID"
                                remoteRef = {
                                    key = "prod/github/app"
                                    property = "app_id"
                                }
                            }
                            {
                                secretKey = "githubAppInstallationID"
                                remoteRef = {
                                    key = "prod/github/app"
                                    property = "install_id"
                                }
                            }
                            {
                                secretKey = "githubAppPrivateKey"
                                remoteRef = {
                                    key = "prod/github/app"
                                    property = "pem_key"
                                }
                            }
                        ]
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 18: nodePool enables Argo CD placement and renders a Karpenter NodePool
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "nodepool-adds-argocd-placement-and-resources"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "nodepool-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    nodePool.enabled = True
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "argocd"
                    spec.forProvider.values = {
                        global = {
                            nodeSelector = {
                                "kubernetes.io/os" = "linux"
                                "workload-type" = "gitops"
                            }
                            tolerations = [
                                {
                                    key = "gitops"
                                    operator = "Equal"
                                    value = "true"
                                    effect = "NoSchedule"
                                }
                            ]
                        }
                        controller.resources.requests = {
                            cpu = "548m"
                            memory = "2062Mi"
                        }
                        repoServer.resources.requests = {
                            cpu = "15m"
                            memory = "100Mi"
                        }
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "nodepool-test-nodepool-gitops"
                    spec.forProvider.manifest = {
                        apiVersion = "karpenter.sh/v1"
                        kind = "NodePool"
                        metadata.name = "hops-gitops"
                        spec.template.metadata.labels = {"workload-type" = "gitops"}
                        spec.template.spec.taints = [
                            {
                                key = "gitops"
                                value = "true"
                                effect = "NoSchedule"
                            }
                        ]
                    }
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "nodepool-test-delete-argocd-before-nodepool"
                }
            ]
        }
    }

    # ==========================================================================
    # Test 19: Gateway exposure and Zitadel OIDC render target-cluster resources
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "gateway-and-zitadel-oidc"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata.name = "sso-test"
                spec = {
                    clusterName = "test-cluster"
                    repository.org = "hops-ops"
                    exposure = {
                        enabled = True
                        hostname = "argocd.example.com"
                        gatewayRef = {
                            name = "platform"
                            namespace = "istio-ingress"
                            sectionName = "https"
                        }
                    }
                    auth.oidc = {
                        enabled = True
                        issuerURL = "https://auth.example.com"
                        rbac.adminEmails = ["admin@example.com"]
                        zitadel.awsSecretsManagerPath = "push/test/zitadel-credentials"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "argocd"
                    spec.forProvider.values = {
                        global.domain = "argocd.example.com"
                        configs.cm.url = "https://argocd.example.com"
                        configs.params = {"server.insecure" = "true"}
                        server.httproute = {
                            enabled = True
                            hostnames = ["argocd.example.com"]
                            parentRefs = [{name = "platform", namespace = "istio-ingress", sectionName = "https"}]
                        }
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "sso-test-zitadel-project"
                    spec.readiness.policy = "DeriveFromObject"
                    spec.forProvider.manifest.spec.forProvider.name = "test-cluster-argocd"
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "sso-test-zitadel-oidc-client"
                    spec.readiness.policy = "DeriveFromObject"
                    spec.connectionDetails = [{
                        apiVersion = "v1"
                        kind = "Secret"
                        name = "sso-test-argocd-oidc-client"
                        namespace = "argocd"
                        fieldPath = "data[attribute.client_id]"
                        toConnectionSecretKey = "client_id"
                    }]
                    spec.writeConnectionSecretToRef.name = "sso-test-zitadel-oidc-client-id"
                    spec.forProvider.manifest.spec.forProvider = {
                        projectIdRef.name = "sso-test-argocd"
                        redirectUris = ["https://argocd.example.com/auth/callback"]
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 20: GitHub webhook uses distinct Secrets in a shared namespace
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "github-webhook-refreshes-argocd"
        spec = {
            compositionPath = "apis/gitopsstacks/composition.yaml"
            xrdPath = "apis/gitopsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = stacksv1alpha1.GitopsStack {
                metadata = {
                    name = "webhook-test"
                    namespace = "platform"
                }
                spec = {
                    clusterName = "test-cluster"
                    namespace = "platform"
                    exposure = {
                        enabled = True
                        hostname = "argocd.example.com"
                    }
                    repository = {
                        org = "hops-ops"
                        name = "platform-gitops"
                        webhook = {
                            enabled = True
                            secretStoreName = "aws-secrets"
                            secretPath = "github/argocd-webhook"
                            secretKey = "hook_secret"
                            maxPayloadSizeMB = 8
                        }
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "argocd"
                    spec.forProvider.values.configs = {
                        cm = {"webhook.maxPayloadSizeMB" = "8"}
                        secret.githubSecret = "$webhook-test-argocd-github-webhook:secret"
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "webhook-test-github-webhook-secret"
                    spec.forProvider.manifest = {
                        apiVersion = "external-secrets.io/v1"
                        kind = "ExternalSecret"
                        metadata = {
                            name = "webhook-test-github-webhook"
                            namespace = "platform"
                        }
                        spec = {
                            secretStoreRef = {
                                name = "aws-secrets"
                                kind = "ClusterSecretStore"
                            }
                            target.template.data.url = "https://argocd.example.com/api/webhook"
                            data = [{
                                secretKey = "webhookSecret"
                                remoteRef = {
                                    key = "github/argocd-webhook"
                                    property = "hook_secret"
                                }
                            }]
                        }
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "webhook-test-argocd-webhook-secret"
                    spec.forProvider.manifest = {
                        metadata = {
                            name = "webhook-test-argocd-github-webhook"
                            namespace = "platform"
                        }
                        spec.target = {
                            name = "webhook-test-argocd-github-webhook"
                            template.metadata.labels = {
                                "app.kubernetes.io/part-of" = "argocd"
                            }
                        }
                    }
                }
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "RepositoryWebhook"
                    metadata.name = "platform-gitops"
                    spec = {
                        forProvider = {
                            active = True
                            events = ["push"]
                            repositoryRef.name = "platform-gitops"
                            configuration = [{
                                contentType = "json"
                                insecureSsl = False
                                urlSecretRef = {
                                    name = "webhook-test-github-webhook"
                                    key = "url"
                                }
                                secretSecretRef = {
                                    name = "webhook-test-github-webhook"
                                    key = "secret"
                                }
                            }]
                        }
                        providerConfigRef = {
                            name = "default"
                            kind = "ProviderConfig"
                        }
                    }
                }
            ]
        }
    }
]

items = _items
