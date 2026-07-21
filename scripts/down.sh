#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Captura la región y el profile ANTES de destruir — después de terraform destroy
# el state ya no tiene outputs que leer.
REGION="$(terraform output -raw region)"
PROFILE="$(terraform output -raw aws_profile)"

# 1. Deja que el AWS Load Balancer Controller desprovisione el ALB antes de
#    destruir el cluster. El ALB lo crea el controller a partir del Ingress,
#    NO es un recurso de Terraform — si se destruye el cluster primero, el
#    ALB queda huérfano cobrando.
#
#    Orden importa: primero las Applications de ArgoCD (su finalizer
#    resources-finalizer.argocd.argoproj.io hace que kubectl delete espere a que
#    ArgoCD borre en cascada lo que administra — Ingress incluido — antes de
#    devolver el control). El delete de Ingress de abajo queda como red de
#    seguridad redundante, no como el mecanismo principal.
#
#    El ApplicationSet se borra ANTES que las Applications: si no, el controller de
#    ApplicationSet recrea backend-app/frontend-app en cuanto el delete --all las borra,
#    dejando a app-of-apps esperando para siempre a que sus hijos desaparezcan de verdad
#    (timeout a los 120s, visto en vivo — ver K8S.md).
kubectl delete -n argocd applicationsets.argoproj.io --all --ignore-not-found
kubectl delete -n argocd applications.argoproj.io --all --ignore-not-found --wait=true --timeout=120s
kubectl delete -n app ingress --all --ignore-not-found
kubectl delete -n demo ingress --all --ignore-not-found
sleep 15

# 2. Destruye toda la infraestructura (EKS, node group, VPC, NAT GW, etc.)
terraform destroy -auto-approve

# 3. Verifica que no quedó nada corriendo cobrando
echo "EC2 instances running:"
aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId"

echo "Load balancers still up:"
aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
  --query "LoadBalancers[].LoadBalancerArn"
