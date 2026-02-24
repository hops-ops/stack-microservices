import datetime
import math
import models.ai.com.ops.hops.stacks.v1alpha1 as stacksv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

# ==============================================================================
# E2E Test for Knative (Kubernetes-only)
#
# Components run in-cluster: Helm releases + provider-kubernetes Objects.
# No cloud credentials needed - uses InjectedIdentity for both providers.
#
# Requires stack-istio to be installed first (provides Istio CRDs needed by
# PeerAuthentication resources in knative-serving).
#
# Run: make e2e
# Run without cleanup: up test run tests/e2etest-knative --e2e --skip-control-plane-cleanup
# ==============================================================================
_now = str(int(math.floor(datetime.ticks())))
_test_name = "e2e-knative-" + _now
_istio_name = "e2e-istio-" + _now

_items = [
    metav1alpha1.E2ETest {
        metadata.name = "knative-e2e"
        spec = {
            crossplane = {
                autoUpgrade.channel = "Rapid"
            }
            defaultConditions = ["Ready"]
            # 60 minutes - Knative Operator + Serving/Eventing
            timeoutSeconds = 3600
            # 30 minutes
            cleanupTimeoutSeconds = 1800
            skipDelete = False
            # ==============================================================
            # initResources: Install dependency Configuration packages
            # ==============================================================
            initResources = [
                # stack-istio Configuration package (provides IstioStack XRD + Istio CRDs)
                {
                    apiVersion = "pkg.crossplane.io/v1"
                    kind = "Configuration"
                    metadata = {
                        name = "stack-istio"
                    }
                    spec = {
                        package = "ghcr.io/hops-ops/stack-istio:v0.7.0"
                    }
                }
            ]
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
            # manifests: IstioStack + Knative XR
            # Deleted during cleanup (unless --skip-delete)
            # ==============================================================
            manifests = [
                # 1. IstioStack - installs Istio CRDs needed by Knative PeerAuthentication
                {
                    apiVersion = "stacks.hops.ops.com.ai/v1alpha1"
                    kind = "IstioStack"
                    metadata = {
                        name = _istio_name
                        namespace = "default"
                    }
                    spec = {
                        clusterName = "default"
                        labels = {
                            "hops.ops.com.ai/e2etest" = "true"
                            "hops.ops.com.ai/test-run" = _now
                        }
                        providerConfigRef = {
                            name = "default"
                            kind = "ProviderConfig"
                        }
                        istiod = {
                            values = {
                                pilot = {
                                    resources = {
                                        requests = {cpu = "10m", memory = "64Mi"}
                                    }
                                }
                            }
                        }
                    }
                }
                # 2. Knative XR
                stacksv1alpha1.Knative {
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
