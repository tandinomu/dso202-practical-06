# DSO202 Practical 6: Creating a Helm Chart for a Complex Application on Kind

## Purpose

This repository contains the work for DSO202 Practical 6. A three-tier visit counter application (NGINX frontend, Python API backend and Redis database) is packaged as one Helm chart called `visitapp` and deployed to Kubernetes. The same chart is installed for dev and prod, and only the values file is different, such as replicas, Service type, page title, message and volume size.

## Repository Structure

```text
dso202-practical-06/
├── evidence/                      # screenshots for each task
├── visitapp-lab/
│   ├── cluster/kind-cluster.yaml  # 1 control plane + 2 workers, port 30080 mapped
│   ├── environments/
│   │   ├── dev.yaml               # dev values (NodePort 30080)
│   │   └── prod.yaml              # prod values (ClusterIP, more replicas)
│   ├── scripts/validate.sh        # lint + template + server dry run
│   ├── visitapp/                  # the Helm chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values.schema.json
│   │   ├── files/app.py           # backend code
│   │   └── templates/             # frontend, backend, redis, tests
│   └── visitapp-0.1.0.tgz         # packaged chart
├── Practical-06-Report.md         # the report
└── README.md
```

## Software Versions

| Software | Version |
|---|---|
| Operating system | macOS, Apple Silicon (arm64) |
| Docker | Docker Desktop 29.7.2 |
| kind | v0.33.0 |
| kubectl | v1.37.1 |
| Helm | v4.3.0 |
| Kubernetes (cluster) | v1.37.0 |

## How to Rebuild

Run all commands from the `visitapp-lab` folder.

**1. Create the cluster**

```bash
kind create cluster --config cluster/kind-cluster.yaml
kubectl get nodes
```

**2. Validate before deploying**

```bash
bash scripts/validate.sh
```

**3. Deploy the environments**

```bash
helm upgrade --install visitapp-dev ./visitapp -f environments/dev.yaml \
  -n dso202-dev --create-namespace --wait --timeout 5m

helm upgrade --install visitapp-prod ./visitapp -f environments/prod.yaml \
  -n dso202-prod --create-namespace --rollback-on-failure --timeout 5m
```

**4. Verify**

```bash
helm list -A
kubectl get pods,pvc -n dso202-dev
kubectl get pods,pvc -n dso202-prod
helm test visitapp-dev -n dso202-dev --logs
helm test visitapp-prod -n dso202-prod --logs
```

Expected backend replicas: dev 1, prod 3.

**5. Reach the application**

Dev:

```bash
curl http://127.0.0.1:30080/api/stats
```

Open `http://127.0.0.1:30080` in the browser. `127.0.0.1` is used because `localhost` may send old cookies that are too large for NGINX.

Prod:

```bash
kubectl -n dso202-prod port-forward svc/visitapp-prod-frontend 8081:80
```

Open `http://127.0.0.1:8081` in the browser.

**6. Package the chart**

```bash
helm package ./visitapp
```

## Cleanup

```bash
helm uninstall visitapp-dev -n dso202-dev
helm uninstall visitapp-prod -n dso202-prod

kubectl delete pvc --all -n dso202-dev
kubectl delete pvc --all -n dso202-prod
kubectl delete namespace dso202-dev dso202-prod

kind delete cluster --name dso202
kind get clusters
```

The PVCs must be deleted by hand because `helm uninstall` does not remove them.