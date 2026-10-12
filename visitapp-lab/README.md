# DSO202 Helm practical - visitapp

```
visitapp-lab/
├── cluster/kind-cluster.yaml   # 3-node kind cluster, host port 30080 mapped
├── environments/dev.yaml       # dev overrides (NodePort 30080, 1 backend)
├── environments/prod.yaml      # prod overrides (ClusterIP, 3 backends)
├── scripts/validate.sh         # lint + template + server dry-run, per env
└── visitapp/                   # the Helm chart
```

Quick start:

```bash
kind create cluster --config cluster/kind-cluster.yaml
./scripts/validate.sh
helm upgrade --install visitapp-dev ./visitapp -f environments/dev.yaml \
  -n dso202-dev --create-namespace --wait --timeout 5m
helm test visitapp-dev -n dso202-dev --logs
# open http://localhost:30080
```
