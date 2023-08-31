variable "cidr_block" {
  type = string
}

variable "private_sn_count" {
  type = number
  default = 2
}

variable "public_sn_count" {
  type = number
  default = 2
}
