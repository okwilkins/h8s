# Image: Terraform

This Dockerfile builds a non-root version of Terraform.

## Locally Building and Pushing

To build locally and to push to [Harbor](../../storage/harbor/README.md) run:

```bash
export TERRAFORM_VER="1.13"
task publish COMPONENT=terraform TAG=$TERRAFORM_VER BUILD_ARGS="--build-arg TERRAFORM_VER=$TERRAFORM_VER"
```

## Available Build Arguments

|       Argument      | Default Value |                   Description                   |
|:-------------------:|:-------------:|:-----------------------------------------------:|
| `TERRAFORM_VER`  |               |       The version of the image to be used for Terraform. For more [read here](https://hub.docker.com/r/hashicorp/terraform/tags).       |


