# Install External Secrets Operator via Helm
# Run once after cluster provisioning:
#
#   helm repo add external-secrets https://charts.external-secrets.io
#   helm repo update
#   helm upgrade --install external-secrets external-secrets/external-secrets \
#     --namespace external-secrets --create-namespace \
#     --set installCRDs=true
