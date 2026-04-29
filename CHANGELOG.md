### What's changed in v0.8.0

* feat: composed StorageClass for NATS and deep-merged values (by @patrickleet)

  Adds spec.nats.storageClass (default enabled, name "knative-nats",
  provisioner ebs.csi.eks.amazonaws.com, type gp3). The stack now composes
  its own StorageClass for NATS JetStream PVCs instead of depending on the
  target cluster having a working default — fixes EKS Auto Mode where the
  in-tree gp2 provisioner is unsupported.

  The NATS Helm Release is gated on the SC being observed-ready, and a
  Usage prevents SC deletion before NATS teardown so the CSI provisioner
  can deprovision PVs cleanly.

  Also fixes the values DX: nats.values now deep-merges with defaults via
  mergeOverwrite in state-init, rendered once in 240-nats.yaml.gotmpl. The
  previous "literal defaults + toYaml user-values appended" pattern emitted
  duplicate keys at the same level, which the Helm provider's YAML parser
  silently dropped — partial overrides were lost.

  Default NATS PVC storageClassName resolves to the composed SC name unless
  the user explicitly sets nats.values.config.jetstream.fileStore.pvc.storageClassName.

* fix(tests): align composition tests with NATS SC gate and label change (by @patrickleet)

  Commit 31f7dd9 broke 6 of 9 composition tests:

    - 5 NATS-asserting tests failed because NATS Release is now gated on the
      composed StorageClass being observed-ready, but the fixtures provided no
      observed resources. Added a Ready+Synced StorageClass to each so they
      reflect production ordering.
    - custom-labels asserted the legacy hardcoded label key. State-init now
      derives the key from $xr.kind (KnativeStack -> knativestack), so update
      the assertion to hops.ops.com.ai/knativestack.

  Adds a new test 'nats-gates-on-storage-class' that exercises the full gate
  contract: observes both SC and NATS as Ready, asserts the SC Object, the
  NATS Release, and the delete-nats-before-storage-class Usage all render.
  The Usage is the strongest signal — it only emits when both SC and NATS
  are observed-ready.

  10/10 passing locally via 'make test'.


See full diff: [v0.7.0...v0.8.0](https://github.com/hops-ops/knative-stack/compare/v0.7.0...v0.8.0)
