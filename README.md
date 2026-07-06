# k8s-learning

Hands-on lab de EKS + ArgoCD + GitOps, construido con mis propios módulos de Terraform
(`mod-aws-vpc`, `mod-aws-eks`, `mod-aws-iam-role`) en vez de módulos públicos genéricos.
Diseñado para bajo costo (~$4-5 USD por sesión de estudio) y para destruirse por completo
cada día vía `scripts/down.sh`.

## Qué reusa y qué es nuevo

| Componente | Origen |
|---|---|
| VPC + subnets EKS | [`mod-aws-vpc`](https://github.com/sergiohl1324/mod-aws-vpc) — ya soporta EKS nativamente, con `enable_dns_hostnames = true` (requisito de EKS, ver Incidente #1 en `K8S.md`) |
| Cluster EKS + node group Spot (`t3.medium` x2) | [`mod-aws-eks`](https://github.com/sergiohl1324/mod-aws-eks) — módulo nuevo, wrapper personalizado sobre `terraform-aws-modules/eks/aws` v21 |
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
un recurso de Terraform. Por eso `scripts/down.sh` borra primero las Applications de ArgoCD
(su finalizer `resources-finalizer.argocd.argoproj.io` hace que ArgoCD borre en cascada lo que
administra, Ingress incluido, antes de que `kubectl delete` devuelva el control), dejando que
el controller desprovisione el ALB — y solo después corre `terraform destroy`.

## Requisitos previos

- Cuenta AWS que **no** esté en el guardrail de "Free Plan" (cuentas nuevas restringidas a
  instancias `t2.micro`/`t3.micro`) — si ves `InvalidParameterCombination ... not eligible for
  Free Tier` al lanzar el node group, necesitas hacer "Upgrade" de la cuenta (agregar método de
  pago; tus créditos se siguen aplicando igual).
- Un usuario **IAM** dedicado (no root) con permisos suficientes, y un profile de AWS CLI local
  llamado `personal-poc` — ver `variables.tf` (`aws_profile`) y `backend.tf`.
- `terraform`, `awscli` v2, `kubectl`, `helm`.

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars
# edita terraform.tfvars: my_ip_cidr con tu IP (curl ifconfig.me)

export TF_VAR_grafana_admin_password="tu-password"   # nunca en tfvars

./scripts/up.sh     # terraform apply + kubeconfig + bootstrap de ArgoCD (App of Apps) + verificación
# ... estudiar EKS/ArgoCD/Kustomize/Argo Rollouts ...
./scripts/down.sh   # borra Applications de ArgoCD (cascade) -> terraform destroy -> verifica que no quedó nada
```

**Acceso a ArgoCD:** `kubectl port-forward svc/argocd-server -n argocd 8080:443` y abre
**`http://localhost:8080`** (HTTP, no HTTPS — el server corre en modo `--insecure`, ver
`helm/argocd/values.yaml`). Usuario `admin`, password del output de `scripts/up.sh`.

**Acceso por consola AWS vs `kubectl`:** `enable_cluster_creator_admin_permissions = true` le da
acceso al cluster solo al usuario IAM que corrió el `apply` (el del profile `personal-poc`) — si
navegas la consola de EKS logueado como root vas a ver *"Your current IAM principal doesn't have
access to Kubernetes objects"*. Es esperado, no un bug — usa `kubectl` (ya funciona) o habilítale
acceso de consola a ese mismo usuario IAM, nunca a root.

**Troubleshooting real:** cuatro incidentes completos (síntoma → diagnóstico → causa raíz → fix)
quedaron documentados en `K8S.md`, en la carpeta padre de este repo — DNS de la VPC, orden de
addons/access entries en EKS v21, y el límite de pods por nodo (`Too many pods`, no es CPU/RAM).

## Notas de versionado

`mod-aws-vpc`, `mod-aws-eks` y `mod-aws-iam-role` se consumen con `?ref=main` (igual que
`poc-aws-infra-deploy`). Etiquetar cada módulo con `git tag vX.Y.Z` y fijar el `ref` a un tag
concreto queda como mejora futura de buenas prácticas.
