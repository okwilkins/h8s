variable "infra_root" {
  description = "Root directory for infrastructure"
  type        = string
}

variable "forgejo_url" {
  description = "Forgejo instance URL (without /api/v1)."
  type        = string
  default     = "https://git.okwilkins.dev"
}

variable "forgejo_renovate_email" {
  description = "Bot email; use this same address in Renovate's gitAuthor."
  type        = string
  default     = "renovate@okwilkins.dev"
}

variable "forgejo_renovate_repositories" {
  description = "Existing owner/repository names to grant Renovate write access. Empty grants no repository access."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for repository in var.forgejo_renovate_repositories : can(regex("^[^/\\s]+/[^/\\s]+$", repository))])
    error_message = "Each repository must have the form owner/repository."
  }
}
