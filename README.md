# k8s-learning

Hands-on lab de EKS + ArgoCD + GitOps, construido con mis propios módulos de Terraform
(`mod-aws-vpc`, `mod-aws-eks`, `mod-aws-iam-role`) en vez de módulos públicos genéricos.
Diseñado para bajo costo (~$4-5 USD por sesión de estudio) y para destruirse por completo
cada día vía `scripts/down.sh`.

## Qué reusa y qué es nuevo

| Componente | Origen |
|---|---|
| VPC + subnets EKS | [`mod-aws-vpc`](https://github.com/sergiohl1324/mod-aws-vpc) — ya soporta EKS nativamente, sin cambios |
| Cluster EKS + node group Spot | [`mod-aws-eks`](https://github.com/sergiohl1324/mod-aws-eks) — módulo nuevo, wrapper personalizado sobre `terraform-aws-modules/eks/aws` |
| Roles IRSA (ALB Controller, External Secrets) | [`mod-aws-iam-role`](https://github.com/sergiohl1324/mod-aws-iam-role) — genérico, reusado tal cual |
| ArgoCD, kube-prometheus-stack, AWS Load Balancer Controller, External Secrets Operator | `helm_release` de Terraform, definidos en `main.tf` de este mismo repo (no son módulos GitHub separados) |
| Manifiestos de la app (Kustomize) y Applications de ArgoCD | YAML plano en `k8s/` y `argocd/` de este repo |

## Por qué todo vive en Terraform (incluido ArgoCD/Prometheus)

El objetivo es poder hacer `scripts/up.sh` / `scripts/down.sh` una vez por sesión de estudio
sin dejar nada corriendo (y cobrando) de un día para otro. Con ArgoCD y el resto de la
plataforma como `helm_release` dentro del mismo state de Terraform, un solo `terraform apply`
levanta todo y un solo `terraform destroy` lo baja — no hay pasos manuales de `helm install`
sueltos que se puedan olvidar.

**Cuidado real:** el ALB que crea el AWS Load Balancer Controller a partir del `Ingress` NO es
un recurso de Terraform. Por eso `scripts/down.sh` borra primero los `Ingress`/Applications de
ArgoCD (dejando que el controller limpie el ALB) y solo después corre `terraform destroy`.

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars
# edita terraform.tfvars: my_ip_cidr con tu IP (curl ifconfig.me)

export TF_VAR_grafana_admin_password="tu-password"   # nunca en tfvars

./scripts/up.sh     # terraform apply + kubeconfig + verificación
# ... estudiar EKS/ArgoCD/Kustomize/Argo Rollouts ...
./scripts/down.sh   # borra Ingress -> terraform destroy -> verifica que no quedó nada
```

## Notas de versionado

`mod-aws-vpc`, `mod-aws-eks` y `mod-aws-iam-role` se consumen con `?ref=main` (igual que
`poc-aws-infra-deploy`). Etiquetar cada módulo con `git tag vX.Y.Z` y fijar el `ref` a un tag
concreto queda como mejora futura de buenas prácticas.
