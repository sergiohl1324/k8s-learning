#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
terraform init -input=false
terraform apply -auto-approve

aws eks update-kubeconfig --name "$(terraform output -raw cluster_name)" --region "$(terraform output -raw region)" --profile "$(terraform output -raw aws_profile)"

echo "Nodes:"
kubectl get nodes
echo "Pods:"
kubectl get pods -A

echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
