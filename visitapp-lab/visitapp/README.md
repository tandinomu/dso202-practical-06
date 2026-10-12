# visitapp

A three-tier visit counter for the DSO202 Helm practical.

| Tier | Image | Kubernetes objects |
|------|-------|--------------------|
| Frontend | `nginx:1.30-alpine` | Deployment, Service (ClusterIP or NodePort), ConfigMap (page + nginx config), optional Ingress |
| Backend | `python:3.13-alpine` | Deployment, Service, ConfigMap (code from `files/app.py`), optional HorizontalPodAutoscaler |
| Database | `redis:7.4-alpine` | StatefulSet with a PersistentVolumeClaim, headless Service, Secret (password) |

Browser -> frontend (nginx) -> `/api/*` -> backend (Python) -> Redis.

## Install

```bash
helm upgrade --install visitapp-dev ./visitapp -f environments/dev.yaml \
  -n dso202-dev --create-namespace --wait --timeout 5m
helm test visitapp-dev -n dso202-dev --logs
```

`global.environment` is required; always pass one environment file.

## Main values

| Key | Default | Meaning |
|-----|---------|---------|
| `global.environment` | `""` (required) | `dev`, `staging` or `prod` |
| `frontend.replicaCount` | `1` | nginx replicas |
| `frontend.service.type` | `ClusterIP` | `ClusterIP` or `NodePort` |
| `frontend.service.nodePort` | `null` | 30000-32767, NodePort only |
| `backend.replicaCount` | `2` | API replicas (ignored when autoscaling is on) |
| `backend.message` | `Hello from the visitapp backend` | Text shown on the page |
| `backend.autoscaling.enabled` | `false` | Create an HPA (needs metrics-server) |
| `redis.auth.password` | `""` | Empty = generated once and kept across upgrades |
| `redis.persistence.enabled` | `true` | Keep data on a PersistentVolumeClaim |
| `redis.persistence.size` | `1Gi` | Cannot be changed after install |
| `ingress.enabled` | `false` | Create an Ingress (needs an ingress controller) |
