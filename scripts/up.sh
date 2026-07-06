#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Si cambiaste mod-aws-vpc/mod-aws-eks/mod-aws-iam-role en GitHub (?ref=main), corre
# `terraform init -upgrade` a mano una vez — init normal no re-clona módulos de git ya
# descargados apuntando a una rama.
terraform init -input=false
terraform apply -auto-approve

aws eks update-kubeconfig --name "$(terraform output -raw cluster_name)" --region "$(terraform output -raw region)" --profile "$(terraform output -raw aws_profile)"

echo "Nodes:"
kubectl get nodes
echo "Pods:"
kubectl get pods -A

# Bootstrap del patrón App of Apps — único kubectl apply manual de todo el flujo GitOps.
# Como down.sh destruye el cluster completo, esto hay que rehacerlo cada sesión (las
# Applications de ArgoCD no sobreviven a un terraform destroy).
echo "Aplicando App of Apps (bootstrap GitOps)..."
kubectl apply -f argocd/apps/app-of-apps.yaml

echo
echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo

echo
echo "Para entrar a la UI de ArgoCD:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  luego abre http://localhost:8080 (HTTP, no HTTPS — el server corre en modo --insecure)"
