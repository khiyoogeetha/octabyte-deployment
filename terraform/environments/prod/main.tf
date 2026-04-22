terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "octa-byte-tstate-bucket"
    key            = "devops-assignment/prod/terraform.tfstate"
    region         = "ap-south-1"
    use_lockfile   = true
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
}

module "iam" {
  source       = "../../modules/iam"
  project_name = var.project_name
  environment  = var.environment
}

module "security_groups" {
  source       = "../../modules/security_groups"
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

module "rds" {
  source          = "../../modules/rds"
  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  db_sg_id        = module.security_groups.rds_sg_id
  db_password     = var.db_password
}

module "ecs" {
  source                 = "../../modules/ecs"
  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  aws_region             = var.aws_region
  public_subnets         = module.vpc.public_subnets
  private_subnets        = module.vpc.private_subnets
  alb_sg_id              = module.security_groups.alb_sg_id
  ecs_sg_id              = module.security_groups.ecs_sg_id
  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  
  db_endpoint = module.rds.db_endpoint
  db_user     = module.rds.db_username
  db_password = var.db_password
  db_name     = module.rds.db_name
}

module "cloudwatch" {
  source       = "../../modules/cloudwatch"
  project_name = var.project_name
  environment  = var.environment
  depends_on   = [module.ecs, module.rds]
}
