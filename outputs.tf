output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "aws_profile" {
  value = var.aws_profile
}

output "ecr_repository_urls" {
  description = "URL de cada repositorio ECR — para el push inicial de imágenes"
  value       = { for k, v in module.ecr : k => v.repository_url }
}

output "configure_kubectl" {
  description = "Corre esto para actualizar tu kubeconfig local"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region} --profile ${var.aws_profile}"
}
