#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Captura la región ANTES de destruir — después de terraform destroy el state
# ya no tiene outputs que leer.
REGION="$(terraform output -raw region)"

# 1. Deja que el AWS Load Balancer Controller desprovisione el ALB antes de
#    destruir el cluster. El ALB lo crea el controller a partir del Ingress,
#    NO es un recurso de Terraform — si se destruye el cluster primero, el
#    ALB queda huérfano cobrando.
kubectl delete -n app ingress --all --ignore-not-found
kubectl delete -n argocd applications.argoproj.io --all --ignore-not-found
sleep 15

# 2. Destruye toda la infraestructura (EKS, node group, VPC, NAT GW, etc.)
terraform destroy -auto-approve

# 3. Verifica que no quedó nada corriendo cobrando
echo "EC2 instances running:"
aws ec2 describe-instances --region "$REGION" \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId"

echo "Load balancers still up:"
aws elbv2 describe-load-balancers --region "$REGION" \
  --query "LoadBalancers[].LoadBalancerArn"
