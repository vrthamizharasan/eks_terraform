module "vpc" {
  source = "./vpc"
  cidr_block = var.cidr_block
  private_sn_count = var.private_sn_count
  public_sn_count = var.public_sn_count
  public_cidrs = ["10.0.2.0/24","10.0.4.0/24"]
  private_cidrs = ["10.0.1.0/24","10.0.3.0/24"]
}
