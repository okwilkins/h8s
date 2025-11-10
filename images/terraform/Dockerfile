ARG TERRAFORM_VER

FROM hashicorp/terraform:${TERRAFORM_VER-latest}

RUN addgroup -S terraform && adduser --system \
     --ingroup terraform \
     --no-create-home \
     --disabled-password \
     --shell /bin/false \
     terraform

USER terraform

