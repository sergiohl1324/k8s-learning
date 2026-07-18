variable "project" {
  description = "Project name (naming/tagging)"
  type        = string
  default     = "k8s-learning"
}

variable "environment" {
  description = "Logical environment used for tagging"
  type        = string
  default     = "lab"
}

variable "region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI named profile a usar (evita depender de variables de entorno sueltas en la shell)"
  type        = string
  default     = "personal-poc"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.30.0.0/16"
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnets" {
  description = "Public subnet CIDRs (NAT Gateway placement — no public ALB, el AWS Load Balancer Controller crea el suyo)"
  type        = list(string)
  default     = ["10.30.1.0/24", "10.30.2.0/24"]
}

variable "eks_subnets" {
  description = "Private subnet CIDRs dedicadas al cluster EKS y al node group"
  type        = list(string)
  default     = ["10.30.11.0/24", "10.30.12.0/24"]
}

variable "private_subnets" {
  description = "Pool genérico de subnets privadas de mod-aws-vpc — no se usa para nada en este lab (los nodos van en eks_subnets), pero hay que declararlo porque aws_route.private_nat_gateway del módulo se crea con base en enable_nat_gateway sin revisar si este pool está vacío, y sin esto el conteo interno del módulo queda inconsistente"
  type        = list(string)
  default     = ["10.30.21.0/24", "10.30.22.0/24"]
}

variable "database_subnets" {
  description = "Subnets dedicadas a RDS (pool database_subnets nativo de mod-aws-vpc, con su propio db_subnet_group). Sin ruta a NAT/IGW — solo alcanzables desde dentro de la VPC"
  type        = list(string)
  default     = ["10.30.31.0/24", "10.30.32.0/24"]
}

variable "db_name" {
  description = "Nombre de la base de datos Postgres del backend demo"
  type        = string
  default     = "demoapp"
}

variable "db_username" {
  description = "Usuario master de RDS"
  type        = string
  default     = "demoapp_admin"
}

variable "my_ip_cidr" {
  description = "Tu IP pública en formato CIDR (curl ifconfig.me), permitida en el endpoint público de EKS"
  type        = string
}

variable "grafana_admin_password" {
  description = "Password de admin de Grafana — pásalo con TF_VAR_grafana_admin_password, nunca lo commitees"
  type        = string
  sensitive   = true
}
