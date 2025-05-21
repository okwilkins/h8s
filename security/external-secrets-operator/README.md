# External Secrets Operator

External-secrets runs within your Kubernetes cluster as a deployment resource. It utilizes CustomResourceDefinitions to configure access to secret providers through SecretStore resources and manages Kubernetes secret resources with ExternalSecret resources.

## Installation

To get started in creating the secret required for the resources ESO uses, please [read here](https://external-secrets.io/v0.16.2/introduction/getting-started/).

***WARNING***: Ideally this secret is not necessary, as AWS service accounts should be used. This removes the need for access tokens and is more secure.

