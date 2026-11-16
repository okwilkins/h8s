# README Badges

Updates README version badges from `main` through a PR.

Configure the environment variables in the [Workflow](../../ci-cd/argo-workflows/environments/prod/workflows/readme-badges-workflow-template.yaml). Add entries to `BADGE_SOURCES` for new badges.

Mount a GitHub token with **Contents** and **Pull requests: Read and write** at `GITHUB_TOKEN_FILE`.
