locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

### VPC — reusa mod-aws-vpc tal cual (ya soporta subnets EKS nativamente) ###

module "vpc" {
  source = "git::https://github.com/sergiohl1324/mod-aws-vpc.git?ref=main"

  project     = var.project
  environment = var.environment

  cidr = var.vpc_cidr
  azs  = var.azs

  public_subnets  = var.public_subnets  # aquí vive el NAT Gateway
  eks_subnets     = var.eks_subnets     # subnets privadas dedicadas a EKS (nodos van aquí)
  private_subnets = var.private_subnets # no se usa para nada real — ver variables.tf

  # Requisito documentado de AWS para EKS: sin esto, el endpoint privado no resuelve por DNS
  # dentro de la VPC y los nodos no logran unirse al cluster (quedan "Still creating..." y
  # terminan en CREATE_FAILED / NodeCreationFailure). mod-aws-vpc trae esto en false por
  # default (el otro consumidor, poc-aws-infra-deploy, no usa EKS así que nunca lo necesitó).
  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true # cost optimization para el lab

  create_eks_subnet_route_table = true
  create_eks_nat_gateway_route  = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  eks_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.tags
}

### EKS — módulo nuevo mod-aws-eks (wrapper personalizado) ###

module "eks" {
  source = "git::https://github.com/sergiohl1324/mod-aws-eks.git?ref=main"

  project     = var.project
  environment = var.environment

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.eks_subnets
  my_ip_cidr = var.my_ip_cidr

  tags = local.tags
}

### IRSA — reusa mod-aws-iam-role genérico, sin crear un módulo nuevo ###

module "irsa_alb_controller" {
  source = "git::https://github.com/sergiohl1324/mod-aws-iam-role.git?ref=main"

  project     = var.project
  environment = var.environment
  role_use    = "eks-alb-controller"

  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume.json
  inline_policies = {
    alb-controller = file("${path.module}/policies/alb-controller-iam-policy.json")
  }

  tags = local.tags
}

module "irsa_external_secrets" {
  source = "git::https://github.com/sergiohl1324/mod-aws-iam-role.git?ref=main"

  project     = var.project
  environment = var.environment
  role_use    = "eks-external-secrets"

  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume.json
  inline_policies = {
    secrets-read = data.aws_iam_policy_document.secrets_manager_read.json
  }

  tags = local.tags
}

### ADDONS + PLATAFORMA GITOPS — helm_release, todo dentro del mismo apply/destroy ###

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_alb_controller.role_arn
  }

  depends_on = [module.eks, module.irsa_alb_controller]
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_external_secrets.role_arn
  }

  # Depende también de aws_lb_controller: su chart registra un webhook que intercepta
  # la creación de CUALQUIER Service en el cluster. Si el pod del controller no está
  # listo todavía, cualquier otro release que cree un Service falla con "no endpoints
  # available for service aws-load-balancer-webhook-service".
  depends_on = [module.eks, module.irsa_external_secrets, helm_release.aws_lb_controller]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.7.0"
  namespace        = "argocd"
  create_namespace = true
  values           = [file("${path.module}/helm/argocd/values.yaml")]

  depends_on = [module.eks, helm_release.aws_lb_controller]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 600 # chart pesado (Prometheus operator + CRDs + Grafana) — 300s (default) se quedaba corto

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "6h"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "256Mi"
  }

  depends_on = [module.eks, helm_release.aws_lb_controller]
}
