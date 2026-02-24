# stack-knative

A Crossplane Configuration package that deploys Knative Serving, Knative Eventing, and optional NATS JetStream on any Kubernetes cluster with Istio.

## Overview

`stack-knative` installs and configures a complete serverless platform:

- **Knative Operator** — manages the lifecycle of Knative components via Helm
- **Knative Serving** — autoscaling serverless workloads with Istio ingress, scale-to-zero, and revision management
- **Knative Eventing** — event-driven architecture with pluggable channels and brokers
- **NATS JetStream** (optional, enabled by default) — high-performance messaging backend for Knative Eventing channels

The stack assumes Istio is already installed (e.g. via [stack-istio](https://github.com/hops-ops/stack-istio)) and configures Knative to use Istio for ingress, mTLS, and network policies.

Deletion protection (Usages) ensures correct teardown order: Serving/Eventing CRs are deleted before the Knative Operator that provides their CRDs.

## Prerequisites

- Crossplane installed in the cluster
- **Istio** installed (provides `security.istio.io` CRDs and ingress)
- Crossplane providers:
  - `provider-helm` (>=v1)
  - `provider-kubernetes` (>=v1)
- Crossplane function:
  - `function-auto-ready` (>=v0.6.0)

## Quick Start

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: stack-knative
spec:
  package: ghcr.io/hops-ops/stack-knative:latest
```

```yaml
apiVersion: stacks.hops.ops.com.ai/v1alpha1
kind: Knative
metadata:
  name: knative
  namespace: default
spec:
  clusterName: default
```

This minimal spec installs the Knative Operator, Knative Serving (with Istio ingress), Knative Eventing (with NATS channels), and a 3-node NATS JetStream cluster.

## The Journey

### Stage 1: Getting Started

Minimal configuration — everything uses sensible defaults. Serving and Eventing are both enabled, NATS provides the default channel backend, and Istio handles ingress.

```yaml
apiVersion: stacks.hops.ops.com.ai/v1alpha1
kind: Knative
metadata:
  name: knative
  namespace: default
spec:
  clusterName: default
```

**What you get:**
- Knative Serving with Istio ingress, pod affinity/tolerations/topology spread enabled
- Knative Eventing with NATS JetStream as the default channel
- Revision garbage collection (max 10 non-active, retain 48h since creation)
- Istio mTLS permissive mode on the knative-serving namespace

### Stage 2: Production with TLS and Custom Domain

Add a hosted zone and cert-manager for automatic TLS on Knative services.

```yaml
apiVersion: stacks.hops.ops.com.ai/v1alpha1
kind: Knative
metadata:
  name: knative
  namespace: default
spec:
  clusterName: production-cluster
  hostedZone: example.com
  certManager:
    enabled: true
  labels:
    team: platform
```

**What this adds:**
- All Knative services get `*.example.com` domain routing
- cert-manager automatically provisions TLS certificates via Let's Encrypt
- External domain TLS enabled on the Serving network config

### Stage 3: Customized Components

Override Helm values and Knative specs for specific requirements.

```yaml
apiVersion: stacks.hops.ops.com.ai/v1alpha1
kind: Knative
metadata:
  name: knative
  namespace: default
spec:
  clusterName: production-cluster
  hostedZone: example.com
  certManager:
    enabled: true
  knativeServing:
    spec:
      config:
        gc:
          max-non-active-revisions: "20"
          retain-since-last-active-time: "48h"
  knativeEventing:
    spec:
      config:
        features:
          new-apiserversource-filters: enabled
  nats:
    values:
      config:
        jetstream:
          fileStore:
            pvc:
              size: 50Gi
```

### Serving or Eventing Only

Disable components you don't need:

```yaml
spec:
  clusterName: my-cluster
  knativeEventing:
    enabled: false
  nats:
    enabled: false
```

## Composed Resources

| Resource | Kind | Purpose |
|----------|------|---------|
| `knative-operator` | Helm Release | Installs the Knative Operator (manages Serving/Eventing CRDs) |
| `namespace-knative-serving` | Object (Namespace) | Creates the knative-serving namespace with `istio-injection: enabled` |
| `namespace-knative-eventing` | Object (Namespace) | Creates the knative-eventing namespace with `istio-injection: enabled` |
| `knative-serving` | Object (KnativeServing) | Deploys Knative Serving via the operator |
| `knative-serving-peer-auth` | Object (PeerAuthentication) | Sets Istio mTLS to permissive in knative-serving namespace |
| `knative-eventing` | Object (KnativeEventing) | Deploys Knative Eventing via the operator |
| `nats` | Helm Release | Installs NATS JetStream cluster (3 replicas, 10Gi storage) |
| `usage-knative-serving` | Usage | Prevents operator deletion before KnativeServing cleanup |
| `usage-knative-eventing` | Usage | Prevents operator deletion before KnativeEventing cleanup |

## Spec Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `clusterName` | string | **required** | Target cluster name, used for provider config defaults |
| `hostedZone` | string | | DNS zone for Knative service domains (e.g. `example.com`) |
| `certManager.enabled` | bool | `false` | Enable cert-manager TLS integration |
| `certManager.issuerRef` | string | `letsencrypt-production` | ClusterIssuer reference |
| `labels` | map | `{}` | Labels merged with defaults on all resources |
| `managementPolicies` | string[] | `["*"]` | Crossplane management policies |
| `helmProviderConfigRef.name` | string | `<clusterName>` | Helm ProviderConfig name |
| `helmProviderConfigRef.kind` | string | `ProviderConfig` | ProviderConfig or ClusterProviderConfig |
| `kubernetesProviderConfigRef.name` | string | `<clusterName>` | Kubernetes ProviderConfig name |
| `kubernetesProviderConfigRef.kind` | string | `ProviderConfig` | ProviderConfig or ClusterProviderConfig |
| `knativeOperator.name` | string | `knative-operator` | Helm release name |
| `knativeOperator.namespace` | string | `knative-operator` | Namespace |
| `knativeOperator.values` | object | `{}` | Helm values merged with defaults |
| `knativeOperator.overrideAllValues` | object | | Replaces all defaults |
| `knativeServing.enabled` | bool | `true` | Install Knative Serving |
| `knativeServing.name` | string | `knative-serving` | KnativeServing resource name |
| `knativeServing.namespace` | string | `knative-serving` | Namespace |
| `knativeServing.spec` | object | *(see defaults)* | Spec merged with defaults |
| `knativeServing.overrideAllSpec` | object | | Replaces all spec defaults |
| `knativeEventing.enabled` | bool | `true` | Install Knative Eventing |
| `knativeEventing.name` | string | `knative-eventing` | KnativeEventing resource name |
| `knativeEventing.namespace` | string | `knative-eventing` | Namespace |
| `knativeEventing.spec` | object | *(see defaults)* | Spec merged with defaults |
| `knativeEventing.overrideAllSpec` | object | | Replaces all spec defaults |
| `nats.enabled` | bool | `true` | Install NATS JetStream |
| `nats.name` | string | `nats` | Helm release name |
| `nats.namespace` | string | `nats` | Namespace |
| `nats.values` | object | `{}` | Helm values merged with defaults |
| `nats.overrideAllValues` | object | | Replaces all defaults |

## Serving Defaults

When not overridden, Knative Serving is configured with:

- **Ingress:** Istio (`istio.ingress.networking.knative.dev`)
- **Pod features:** affinity, securityContext, nodeSelector, tolerations, topologySpreadConstraints
- **GC:** max 10 non-active revisions, retain 48h since creation, 15h since last active
- **TLS:** enabled when `certManager.enabled: true`
- **Domain:** configured when `hostedZone` is set

## Eventing Defaults

When not overridden, Knative Eventing is configured with:

- **Istio integration:** enabled
- **Default channel:** NATS JetStream (when `nats.enabled: true`)

## Status

| Field | Type | Description |
|-------|------|-------------|
| `status.ready` | bool | Overall readiness (all components healthy) |

## Development

```bash
make render        # Render all examples
make validate      # Validate against XRD schema
make test          # Run unit tests
make e2e           # Run E2E tests
```
