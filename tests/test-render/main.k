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
        apiVersion = "repo.m.github.upbound.io/v1alpha1"
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
                    apiVersion = "repo.m.github.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "test-gitops-gitops-repo"
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
                            "hops.ops.com.ai/gitops" = "labeled-gitops"
                            team = "platform"
                            environment = "staging"
                        }
                    }
                }
                {
                    apiVersion = "repo.m.github.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata = {
                        name = "labeled-gitops-gitops-repo"
                        labels = {
                            "hops.ops.com.ai/managed" = "true"
                            "hops.ops.com.ai/gitops" = "labeled-gitops"
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
                    apiVersion = "repo.m.github.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "tmpl-test-gitops-repo"
                    spec.forProvider = {
                        name = "test-cluster-gitops"
                        visibility = "private"
                        hasIssues = True
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
                    apiVersion = "repo.m.github.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "init-test-gitops-repo"
                    spec.forProvider = {
                        name = "test-cluster-gitops"
                        autoInit = True
                        visibility = "private"
                        hasIssues = True
                        deleteBranchOnMerge = True
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
                    metadata.name = "gate-test-argocd-projects-app"
                    spec.forProvider.manifest = {
                        apiVersion = "argoproj.io/v1alpha1"
                        kind = "Application"
                        metadata.name = "projects"
                        spec.source = {
                            path = ".gitops/deploy"
                            repoURL = "https://github.com/hops-ops/test-cluster-gitops.git"
                        }
                    }
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "gate-test-delete-projects-app-before-argocd"
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
                    metadata.name = "no-xp-argocd-projects-app"
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
                    metadata.name = "xp-test-crossplane-app-project"
                    spec.forProvider.manifest = {
                        apiVersion = "argoproj.io/v1alpha1"
                        kind = "AppProject"
                        metadata.name = "crossplane"
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "xp-test-crossplane-configs-app"
                    spec.forProvider.manifest = {
                        apiVersion = "argoproj.io/v1alpha1"
                        kind = "Application"
                        metadata.name = "crossplane-configurations"
                        spec.source.path = "resources/crossplane/configurations"
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "xp-test-crossplane-provider-configs-app"
                    spec.forProvider.manifest = {
                        apiVersion = "argoproj.io/v1alpha1"
                        kind = "Application"
                        metadata.name = "crossplane-provider-configs"
                        spec.source.path = "resources/crossplane/provider-configs"
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
                    apiVersion = "repo.m.github.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "pc-test-gitops-repo"
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
                    apiVersion = "repo.m.github.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "custom-repo-gitops-repo"
                    spec.forProvider = {
                        name = "my-custom-gitops"
                        description = "My custom gitops repo"
                        visibility = "public"
                        topics = ["gitops", "kubernetes"]
                        hasIssues = True
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
                    applications.projects.path = "deploy/argocd"
                }
            }
            observedResources = _argocdReady
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "path-test-argocd-projects-app"
                    spec.forProvider.manifest.spec.source.path = "deploy/argocd"
                }
            ]
        }
    }
]

items = _items
