# ============================================================
# Cosign Key Pair Generation
# ============================================================

resource "tls_private_key" "cosign_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "random_password" "cosign_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}
