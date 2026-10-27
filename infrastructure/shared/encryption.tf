terraform {
  encryption {
    key_provider "pbkdf2" "bootstrap" {
      passphrase               = var.bootstrap_state_passphrase
      encrypted_metadata_alias = "h8s-bootstrap"
    }

    method "aes_gcm" "bootstrap" {
      keys = key_provider.pbkdf2.bootstrap
    }

    state {
      method   = method.aes_gcm.bootstrap
      enforced = true
    }

    plan {
      method   = method.aes_gcm.bootstrap
      enforced = true
    }

    remote_state_data_sources {
      default {
        method = method.aes_gcm.bootstrap
      }
    }
  }
}

variable "bootstrap_state_passphrase" {
  description = "State encryption passphrase, supplied through SOPS. Preserve it for recovery."
  type        = string
  sensitive   = true
}
