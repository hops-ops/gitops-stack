import base64
import file
import datetime
import math
import models.ai.com.ops.hops.v1alpha1 as stacksv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

# ==============================================================================
# E2E Test for GitopsStack
#
# Creates a real GitHub repository and installs ArgoCD via Helm.
#
# Credentials required:
#   secrets/github-creds  - provider-upjet-github credentials JSON.
#                          Token form:
#                          {"token":"ghs_...","owner":"hops-ops"}
#                          App auth form:
#                          {"owner":"hops-ops","app_auth":[{"id":"123456","installation_id":"78901234","pem_file":"-----BEGIN RSA PRIVATE KEY-----\n..."}]}
#
# The shared e2e workflow currently writes this file for the test. The GitHub
# App installation must target the organization owner so repo creation against
# POST /orgs/{org}/repos is allowed.
#
# Run: make e2e
# Run without cleanup: up test run tests/e2etest-gitops --e2e --skip-control-plane-cleanup
# ==============================================================================
_github_creds = file.read("secrets/github-creds")
_base64_github_creds = base64.encode(_github_creds)

_now = str(int(math.floor(datetime.ticks())))
_test_name = "e2e-gitops-stack" + _now

_items = [
    metav1alpha1.E2ETest {
        metadata.name = "gitops-e2e"
        spec = {
            crossplane = {
                autoUpgrade.channel = "Rapid"
            }
            defaultConditions = ["Ready"]
            # 30 minutes - Helm chart install + GitHub repo creation
            timeoutSeconds = 1800
            # 10 minutes
            cleanupTimeoutSeconds = 600
            skipDelete = False
            # ==============================================================
            # extraResources: RBAC, ProviderConfigs, GitHub credentials
            # These are NOT deleted during cleanup
            # ==============================================================
            extraResources = [
                # Grant cluster-admin to all SAs in crossplane-system namespace
                # Required for Helm provider to create namespaces and install charts,
                # and for Kubernetes provider to create Object resources
                {
                    apiVersion = "rbac.authorization.k8s.io/v1"
                    kind = "ClusterRoleBinding"
                    metadata.name = "crossplane-system-cluster-admin"
                    roleRef = {
                        apiGroup = "rbac.authorization.k8s.io"
                        kind = "ClusterRole"
                        name = "cluster-admin"
                    }
                    subjects = [
                        {
                            kind = "Group"
                            name = "system:serviceaccounts:crossplane-system"
                            apiGroup = "rbac.authorization.k8s.io"
                        }
                    ]
                }
                # Helm ProviderConfig - uses in-cluster identity
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "ProviderConfig"
                    metadata = {
                        name = "default"
                        namespace = "default"
                    }
                    spec = {
                        credentials = {
                            source = "InjectedIdentity"
                        }
                    }
                }
                # Kubernetes ProviderConfig - uses in-cluster identity
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "ProviderConfig"
                    metadata = {
                        name = "default"
                        namespace = "default"
                    }
                    spec = {
                        credentials = {
                            source = "InjectedIdentity"
                        }
                    }
                }
                # GitHub credentials Secret
                {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = "github-creds"
                        namespace = "default"
                    }
                    data = {
                        creds = _base64_github_creds
                    }
                }
                # GitHub ProviderConfig - references credentials Secret
                {
                    apiVersion = "github.m.upbound.io/v1beta1"
                    kind = "ProviderConfig"
                    metadata = {
                        name = "default"
                        namespace = "default"
                    }
                    spec = {
                        credentials = {
                            source = "Secret"
                            secretRef = {
                                namespace = "default"
                                name = "github-creds"
                                key = "creds"
                            }
                        }
                    }
                }
            ]
            # ==============================================================
            # manifests: GitopsStack XR
            # Deleted during cleanup (unless --skip-delete)
            # ==============================================================
            manifests = [
                stacksv1alpha1.GitopsStack {
                    metadata = {
                        name = _test_name
                        namespace = "default"
                    }
                    spec = {
                        clusterName = "default"
                        namespace = "argocd"
                        managementPolicies = ["*"]
                        labels = {
                            "hops.ops.com.ai/e2etest" = "true"
                            "hops.ops.com.ai/test-run" = _now
                        }
                        helmProviderConfigRef = {
                            name = "default"
                            kind = "ProviderConfig"
                        }
                        kubernetesProviderConfigRef = {
                            name = "default"
                            kind = "ProviderConfig"
                        }
                        githubProviderConfigRef = {
                            name = "default"
                            kind = "ProviderConfig"
                        }
                        repository = {
                            org = "hops-ops"
                            name = _test_name
                            description = "E2E test repo - safe to delete"
                            allowDelete = True
                        }
                        argocd = {
                            values = {
                                # Minimal resources for kind cluster
                                server.resources.requests = {cpu = "10m", memory = "64Mi"}
                                controller.resources.requests = {cpu = "10m", memory = "64Mi"}
                                repoServer.resources.requests = {cpu = "10m", memory = "64Mi"}
                                redis.resources.requests = {cpu = "10m", memory = "32Mi"}
                            }
                        }
                        # Enable apps Application to verify creation and ordered deletion
                        applications = {
                            apps.enabled = True
                        }
                    }
                }
            ]
        }
    }
]
items = _items
