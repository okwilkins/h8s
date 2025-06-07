# Terraform

Terraform is used to deploy infrastructure as code for resources like [Harbor](../storage/harbor/README.md) where [Crossplane](https://www.crossplane.io/) or the resource provider does not have a mature enough operator.

## Getting Started

Postgres is used as the [Terraform backend](https://developer.hashicorp.com/terraform/language/backend) for storing infra state. This database is [defined here](../storage/cloudnative-pg/environments/prod/databases/terraform-backend/).

To gain access to the database, first port-forward the database. Ideally this should not need to happen but within my LAN I cannot get the [Cilium Gateway](../networking/gateways/base/gateways/default.yaml) to successfully route TLS traffic. See [this Github issue for more details](https://github.com/cilium/cilium/issues/39929). In on shell run:
```bash
kubectl -n terraform port-forward svc/cnpg-terraform-backend-prod-rw 5432:5432
```

To then export the connection details needed, run in a separate shell:

```bash
export PG_USER=$(kubectl get secret cnpg-terraform-backend-prod-app-user-credentials -n terraform -o json | jq -r '.data.username' | base64 -d)
export PG_PASS=$(kubectl get secret cnpg-terraform-backend-prod-app-user-credentials -n terraform -o json | jq -r '.data.password' | base64 -d)
export PG_CONN_STR=postgres://$PG_USER:$PG_PASS@localhost/terraform_backend
```

More details on the [Postgres backend can be read here](https://developer.hashicorp.com/terraform/language/backend/pg).

### Initialising Backend

Run:

```bash
terraform init
```

