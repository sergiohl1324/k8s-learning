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

variable "my_ip_cidr" {
  description = "Tu IP pública en formato CIDR (curl ifconfig.me), permitida en el endpoint público de EKS"
  type        = string
}

variable "grafana_admin_password" {
  description = "Password de admin de Grafana — pásalo con TF_VAR_grafana_admin_password, nunca lo commitees"
  type        = string
  sensitive   = true
}
