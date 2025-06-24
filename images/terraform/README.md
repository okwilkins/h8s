# Image: Terraform

This Dockerfile builds a non-root version of Terraform.

## Locally Building and Pushing

To build locally and to push to [Harbor](../../storage/harbor/README.md) run:

```bash
task dagger_run
```

## Available Build Arguments

|       Argument      | Default Value |                   Description                   |
|:-------------------:|:-------------:|:-----------------------------------------------:|
| `TERRAFORM_VERION`  |               |       The version of the image to be used for Terraform       |


