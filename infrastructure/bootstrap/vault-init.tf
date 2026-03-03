# ============================================================
# Vault Initialization
# ============================================================
# Automatically initializes, unseals, and configures Vault
# during the bootstrap process. All credentials are saved to
# vault-init.json - back this up securely!

# ============================================================
# Check Vault Status
# ============================================================
# Check if Vault is already initialized to avoid re-initialization

data "external" "vault_status" {
  program = ["bash", "-c", <<-EOT
    if kubectl exec -ti vault-0 -n vault -- vault status -format=json 2>/dev/null | jq -e '.initialized == true' > /dev/null 2>&1; then
      echo '{"initialized": "true"}'
    else
      echo '{"initialized": "false"}'
    fi
  EOT
  ]

  depends_on = [null_resource.argocd_manifests]
}

# ============================================================
# Initialize Vault
# ============================================================
# Initializes Vault and saves the output to vault-init.json
# Only runs if Vault is not already initialized

resource "null_resource" "vault_init" {
  count = data.external.vault_status.result.initialized == "true" ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      echo "Initializing Vault..."
      kubectl exec -ti vault-0 -n vault -- vault operator init -format=json > vault-init.json
      if [ $? -ne 0 ]; then
        echo "ERROR: Vault initialization failed"
        exit 1
      fi
      echo "Vault initialized successfully. Output saved to vault-init.json"
    EOT
  }

  depends_on = [null_resource.argocd_manifests]
}

# ============================================================
# Read Vault Init Output
# ============================================================
# Reads the initialization output for use in other resources
# This will fail on first apply if Vault isn't initialized yet,
# which is expected - run terraform apply again after init

data "local_file" "vault_init" {
  filename   = "${path.module}/vault-init.json"
  depends_on = [null_resource.vault_init]
}

# ============================================================
# Unseal Vault
# ============================================================
# Unseals Vault using the unseal keys from initialization

resource "null_resource" "vault_unseal" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Unsealing Vault..."
      
      # Extract unseal keys and unseal Vault
      keys=$(cat ${path.module}/vault-init.json | jq -r '.unseal_keys_b64[]')
      
      for key in $keys; do
        echo "Submitting unseal key..."
        kubectl exec -ti vault-0 -n vault -- vault operator unseal "$key"
        if [ $? -ne 0 ]; then
          echo "ERROR: Failed to unseal Vault with key"
          exit 1
        fi
      done
      
      echo "Vault unsealed successfully"
    EOT
  }

  depends_on = [data.local_file.vault_init]
}

# ============================================================
# Enable Kubernetes Auth
# ============================================================
# Enables Kubernetes authentication method in Vault

resource "null_resource" "vault_k8s_auth" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Enabling Kubernetes auth in Vault..."
      
      # Get root token from the JSON file
      VAULT_TOKEN=$(cat ${path.module}/vault-init.json | jq -r '.root_token')
      
      # Create a temp script with the token embedded
      cat > /tmp/vault-k8s-auth.sh << EOF
#!/bin/sh
export VAULT_TOKEN="$VAULT_TOKEN"

# Login with root token
vault login "\$VAULT_TOKEN" || exit 1

# Enable Kubernetes auth if not already enabled
vault auth list | grep -q kubernetes || vault auth enable kubernetes || exit 1

# Configure Kubernetes auth
vault write auth/kubernetes/config \\
  kubernetes_host="https://\$KUBERNETES_SERVICE_HOST:\$KUBERNETES_SERVICE_PORT" \\
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt || exit 1

echo 'Kubernetes auth configured successfully'
EOF

      # Copy script to vault pod and execute it
      kubectl cp /tmp/vault-k8s-auth.sh vault-0:/tmp/vault-k8s-auth.sh -n vault
      kubectl exec vault-0 -n vault -- /bin/sh /tmp/vault-k8s-auth.sh
      
      exit_code=$?
      
      # Cleanup
      rm -f /tmp/vault-k8s-auth.sh
      kubectl exec vault-0 -n vault -- rm -f /tmp/vault-k8s-auth.sh
      
      if [ $exit_code -ne 0 ]; then
        echo "ERROR: Failed to configure Kubernetes auth"
        exit 1
      fi
      
      echo "Kubernetes auth configured successfully"
    EOT
  }

  depends_on = [null_resource.vault_unseal]
}

# ============================================================
# Outputs
# ============================================================
# Note: We don't output sensitive values directly

output "vault_initialized" {
  description = "Whether Vault has been initialized"
  value       = data.external.vault_status.result.initialized == "true" || length(null_resource.vault_init) > 0
}

output "vault_init_file" {
  description = "Path to the Vault initialization output file"
  value       = "${path.module}/vault-init.json"
}
