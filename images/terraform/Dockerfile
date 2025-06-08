ARG TERRAFORM_VER

FROM hashicorp/terraform

RUN addgroup -S terraform && adduser  --system \
     --ingroup terraform \
     --no-create-home \
     --disabled-password \
     --shell /bin/false \
     terraform
USER terraform

COPY --chown=terraform:terraform ../. /terraform

