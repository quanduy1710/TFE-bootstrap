# GitOps Repository — EKS Cluster

This repository is the single source of truth for the EKS Kubernetes cluster and its workloads. It uses [ArgoCD](https://argo-cd.readthedocs.io/) as the GitOps operator with three layered patterns: a Root App bootstrap, App-of-Apps for core platform services, and ApplicationSet for dynamic workload onboarding.

---

## Directory Structure

```
/
├── argocd/
│   ├── root-app.yaml
│   ├── projects/
│   │   ├── cluster-services.yaml
│   │   └── workloads.yaml
│   ├── core-apps/
│   │   ├── istio-app.yaml
│   │   ├── prometheus-app.yaml
│   │   ├── kyverno-app.yaml
│   │   └── external-secrets-app.yaml
│   └── appsets/
│       └── apps-appset.yaml
├── apps/
│   ├── cluster-services/
│   │   ├── istio/
│   │   │   ├── base/values.yaml
│   │   │   └── overlays/
│   │   │       ├── dev/values.yaml
│   │   │       └── prod/values.yaml
│   │   ├── prometheus/
│   │   │   ├── base/values.yaml
│   │   │   └── overlays/{dev,prod}/values.yaml
│   │   ├── kyverno/
│   │   │   ├── base/values.yaml
│   │   │   └── overlays/{dev,prod}/values.yaml
│   │   └── external-secrets/
│   │       ├── base/values.yaml
│   │       └── overlays/{dev,prod}/values.yaml
│   └── workloads/
│       └── tfe/
│           ├── app-config.yaml
│           └── values.yaml
└── terraform/

/
├── argocd/
│   ├── root-app.yaml
│   ├── projects/
│   │   ├── cluster-services.yaml
│   │   └── workloads.yaml
│   ├── core-apps/
│   │   ├── istio-app.yaml
│   │   ├── prometheus-app.yaml
│   │   ├── kyverno-app.yaml
│   │   └── external-secrets-app.yaml
│   └── appsets/
│       └── apps-appset.yaml
└── apps/
    ├── cluster-services/
    │   ├── istio/
    │   │   └── values.yaml
    │   ├── prometheus/
    │   │   └── values.yaml
    │   ├── kyverno/
    │   │   └── values.yaml
    │   └── external-secrets/
    │       └── values.yaml
    └── workloads/
        └── tfe/
            ├── app-config.yaml
            └── values.yaml
```

---

## ArgoCD Layer (`argocd/`)

### Root App

`argocd/root-app.yaml` is the single manifest applied by hand to bootstrap the entire ArgoCD application tree. It watches the `argocd/` directory recursively on the `main` branch, discovering and syncing all child manifests (Projects, Applications, ApplicationSets) automatically. After this one `kubectl apply`, ArgoCD manages everything else.

### ArgoCD Projects (`argocd/projects/`)

Two ArgoCD Projects enforce RBAC boundaries between the two deployment tiers:

| Project | Manages | Namespace scope | Cluster-scoped resources |
|---------|---------|-----------------|--------------------------|
| `cluster-services` | Istio, Prometheus, Kyverno, ESO | `istio-system`, `monitoring`, `kyverno`, `external-secrets` | Allowed (CRDs, ClusterRoles, etc.) |
| `workloads` | ApplicationSet-generated apps | Any namespace | Blocked (Namespace, ClusterRole, ClusterRoleBinding) |

The root-app itself uses the `default` project since it manages ArgoCD-namespace resources.

> **Before applying:** replace `sourceRepos: ['*']` in each project with the actual repository URL once the placeholder is substituted.

### Core Apps (`argocd/core-apps/`)

One ArgoCD `Application` manifest per core platform component, all referencing project `cluster-services`. Each uses a **multi-source Helm** configuration:

- **Source 1** — upstream public Helm chart, pinned to a specific version
- **Source 2** — this Git repository (`ref: values`), used to resolve `$values` paths to overlay files

| App | Chart | Repo |
|-----|-------|------|
| `istio` | `istiod 1.20.3` | `istio-release.storage.googleapis.com/charts` |
| `prometheus` | `kube-prometheus-stack 55.5.0` | `prometheus-community.github.io/helm-charts` |
| `kyverno` | `kyverno 3.2.6` | `kyverno.github.io/kyverno/` |
| `external-secrets` | `external-secrets 0.9.11` | `charts.external-secrets.io` |

### ApplicationSet (`argocd/appsets/apps-appset.yaml`)

Discovers workloads automatically via a Git files generator scanning `apps/workloads/**/app-config.yaml`. For each `app-config.yaml` found it generates one ArgoCD Application in the `workloads` project. Namespace defaults to `app_name`; set an explicit `namespace` key in `app-config.yaml` to override.

---

## Apps Layer (`apps/`)

Contains all Helm values files. Separated into two subtrees matching the two ArgoCD Projects.

### `apps/cluster-services/`

Each service has a `base/values.yaml` with shared defaults and per-environment overlays. Both files are passed to Helm in order (base first, overlay second), so the overlay only needs to declare what changes.

| Overlay | Purpose |
|---------|---------|
| `overlays/dev/values.yaml` | Dev cluster overrides (reduced replicas, shorter retention, no persistence) |
| `overlays/prod/values.yaml` | Prod cluster overrides (HA replicas, persistent storage, full alerting) |

The active overlay is selected per-environment by editing the `valueFiles` list in the corresponding `*-app.yaml`.

### `apps/workloads/`

Each subdirectory is a deployable workload discovered by the ApplicationSet. Required files per workload:

| File | Purpose |
|------|---------|
| `app-config.yaml` | Declares `app_name`, `helm_repo_url`, `helm_chart`, `chart_version`. Optionally `namespace`. |
| `values.yaml` | Helm values for the workload chart. |

---

## Secrets Management (External Secrets Operator)

Secrets are **never stored in Git**. The External Secrets Operator (ESO) is deployed as a core platform service and reads from **AWS Secrets Manager** via IRSA.

### How it works

1. ESO is installed in the `external-secrets` namespace with an IRSA role that has read access to Secrets Manager paths.
2. Each workload namespace contains `ExternalSecret` CRs (committed to Git, no sensitive data) that tell ESO which Secrets Manager path to sync into which Kubernetes Secret.
3. ESO reconciles continuously — rotating a secret in Secrets Manager propagates to the cluster within the configured `refreshInterval`.

### Adding a secret for a workload

```yaml
# apps/workloads/<app-name>/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: <app-name>-secrets
  namespace: <app-name>
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager   # ClusterSecretStore provided by ESO
    kind: ClusterSecretStore
  target:
    name: <app-name>-secrets    # name of the resulting Kubernetes Secret
  data:
    - secretKey: MY_KEY
      remoteRef:
        key: /<env>/<app-name>/my-key   # Secrets Manager path
```

---

## Bootstrap Procedure for a New Cluster

### Prerequisites

- `kubectl` configured against the target EKS cluster
- ArgoCD installed and accessible
- This repository cloned locally
- All `<org>/<repo>` placeholders replaced with the actual Git remote URL

### Step 1 — Provision EKS with Terraform

```bash
cd terraform/
terraform init
terraform plan -out=tfplan
terraform apply tfplan
aws eks update-kubeconfig --region <aws-region> --name <cluster-name>
```

### Step 2 — Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd
```

### Step 3 — Apply the Root App

```bash
kubectl apply -f argocd/root-app.yaml
```

ArgoCD recurses into `argocd/projects/`, `argocd/core-apps/`, and `argocd/appsets/`, instantiating all Projects, Applications, and ApplicationSets automatically.

### Step 4 — Verify

```bash
argocd app list
# or
kubectl get applications,appprojects -n argocd
```

All applications should reach `Health: Healthy` and `Sync: Synced`. If an app stays `Degraded`:

```bash
argocd app get <app-name>
argocd app logs <app-name>
```

---

## Sync Policy

All Applications share a uniform sync policy:

| Setting | Behaviour |
|---------|-----------|
| `selfHeal: true` | Reverts manual `kubectl` changes to Git state within seconds |
| `prune: true` | Deletes cluster resources removed from Git on next sync |
| Retry 3× with backoff | 10s → 20s → 40s; enters `Degraded` after 3 failures |

---

## Promotion Workflow

Changes flow through Git, not kubectl.

### Day-to-day changes (values, chart version bumps)

1. Open a PR against `main`.
2. Review and merge — ArgoCD picks up the change on the next reconciliation loop (default: 3 minutes) or on the next webhook trigger.

### Promoting to a new environment

When a second cluster (e.g. dev) is onboarded:

1. Point its root-app at the `dev` branch (`targetRevision: dev`).
2. Each core-app in the `dev` cluster's manifest uses the `overlays/dev/values.yaml` overlay.
3. Promote by merging `dev` → `main`; prod cluster picks up the change.

### Pinning to a release tag (recommended for prod)

Change `targetRevision: main` to `targetRevision: "v1.4.2"` in the prod root-app. This decouples prod deploys from every commit and requires an explicit tag cut to promote.

---

## Adding a New Core Platform Component

1. Add `argocd/core-apps/<component>-app.yaml` (copy an existing app, set `project: cluster-services`).
2. Add the component's namespace to `argocd/projects/cluster-services.yaml` under `destinations`.
3. Create `apps/cluster-services/<component>/base/values.yaml` and `overlays/{dev,prod}/values.yaml`.
4. Push — ArgoCD detects the new Application and syncs it automatically.

## Onboarding a New Workload via ApplicationSet

1. Create `apps/workloads/<app-name>/app-config.yaml` with the required fields:
   ```yaml
   app_name: <app-name>
   helm_repo_url: https://...
   helm_chart: <chart-name>
   chart_version: "x.y.z"
   # namespace: <app-name>   # optional override
   ```
2. Create `apps/workloads/<app-name>/values.yaml` with Helm values.
3. If the app needs secrets, add an `ExternalSecret` CR (see Secrets section above).
4. Push — the ApplicationSet generates a new ArgoCD Application automatically. No changes to any ArgoCD manifest are needed.
