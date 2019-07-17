variable "region" {}

variable "name" {}

variable "cidr" {}

variable "name_space" {}


variable "app_running_port" {}

variable "ssh_ips" {
 description = "A list of ssh_ips."
  default     = []
}

variable "nat_subnet" {
  description = "A list of nat subnets inside the VPC."
  default     = []
}

variable "ssh_subnet" {
  description = "A list of ssh subnets inside the VPC."
  default     = []
}

variable "db_subnet" {
  description = "A list of db subnets inside the VPC."
  default     = []
}

variable "public_elb_subnet" {
  description = "A list of public elb subnets inside the VPC."
  default     = []
}

variable "app_subnet" {
  description = "A list of app subnets inside the VPC."
  default     = []
}


variable "azs" {
  description = "A list of Availability zones in the region"
  default     = []
}

variable "tags" {
  description = "A map of tags to add to all resources"
  default     = {}
}