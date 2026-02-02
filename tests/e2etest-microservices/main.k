import datetime
import math
import models.ai.com.ops.hops.stacks.v1alpha1 as stacksv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

# ==============================================================================
# E2E Test for Microservices (Kubernetes-only)
#
# Components run in-cluster: Helm releases + provider-kubernetes Objects.
# No cloud credentials needed - uses InjectedIdentity for both providers.
#
# Run: make e2e
# Run without cleanup: up test run tests/e2etest-microservices --e2e --skip-control-plane-cleanup
# ==============================================================================

_now = str(int(math.floor(datetime.ticks())))
_test_name = "e2e-microservices-" + _now

_items = [
    metav1alpha1.E2ETest {
        metadata.name = "microservices-e2e"
        spec = {
            crossplane = {
                autoUpgrade.channel = "Rapid"
            }
            defaultConditions = ["Ready"]
            timeoutSeconds = 3600  # 60 minutes - Istio + Knative Operator + Serving/Eventing
            cleanupTimeoutSeconds = 1800  # 30 minutes
            skipDelete = False

            # ==============================================================
            # extraResources: RBAC, Helm ProviderConfig, Kubernetes ProviderConfig
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
                # Used by Object resources (KnativeServing/KnativeEventing, namespaces)
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
            ]

            # ==============================================================
            # manifests: Microservices XR
            # Deleted during cleanup (unless --skip-delete)
            # ==============================================================
            manifests = [
                stacksv1alpha1.Microservices {
                    metadata = {
                        name = _test_name
                        namespace = "default"
                    }
                    spec = {
                        clusterName = "default"
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
                        knativeServing.enabled = True
                        knativeEventing.enabled = True
                    }
                }
            ]
        }
    }
]
items = _items
