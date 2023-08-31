variable "cidr_block" {
  type = string
}

variable "public_sn_count" {
  type = number
}

variable "private_sn_count" {
  type = number
}

variable "public_cidrs" {
  type = list
}

variable "private_cidrs" {
  type = list
}
