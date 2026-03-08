# Platform Configuration

Terraform configurations for managing platform-level resources that don't have mature Kubernetes operators.

## Harbor Configuration

This manages Harbor container registry resources including:
- Projects (main, docker-hub-cache, ghcr-cache)
- Registries (Docker Hub, Quay, GHCR pull-through caches)
- Users and robot accounts
- Project memberships and permissions

## Getting Started

Postgres is used as the [Terraform backend](https://developer.hashicorp.com/terraform/language/backend) for storing state. This database is [defined here](../../storage/cloudnative-pg/environments/prod/databases/terraform-backend/).

### Connecting to the Backend

Port-forward the database:
```bash
kubectl -n terraform port-forward svc/cnpg-terraform-backend-prod-rw 5432:5432
```

Export connection details:
```bash
export PGUSER=$(kubectl get secret cnpg-terraform-backend-prod-app-user-credentials -n terraform -o json | jq -r '.data.username' | base64 -d)
export PGPASSWORD=$(kubectl get secret cnpg-terraform-backend-prod-app-user-credentials -n terraform -o json | jq -r '.data.password' | base64 -d)
export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=terraform_backend
```

### Initialising Terraform

```bash
cd platform-config
terraform init
```

### Using Harbor Pull-Through Caches

Login to Harbor:
```bash
docker login harbor.okwilkins.dev -u oli
```

Pull through caches:
```bash
docker pull harbor.okwilkins.dev/docker-hub-cache/hello-world:latest
```

Pattern: `harbor.okwilkins.dev/<project>/<image>:<tag>`
