terraform {
  backend "s3" {
    bucket       = "chebogime-s3-states" # mismo bucket compartido que usas en poc-aws-infra-deploy
    key          = "k8s-learning/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
    profile      = "personal-poc" # ajusta al profile de AWS CLI que uses localmente
  }
}
