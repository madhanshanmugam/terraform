module "vpc" {

  source ="github.com/madhanshanmugam/terraform/vpc"
  #source = "./vpc"

  region = "us-east-1"

  name = "myapp-vpc" # name of the vpc

  name_space = "MYAPP_US_EAST_1" # namespace which gets prefixed to all components created here.

  azs = ["us-east-1b", "us-east-1c"] # lists of AZ, only two supported as of now.

  cidr = "10.120.0.0/16" #cidr range of the VPC

  nat_subnet = ["10.120.1.0/24", "10.120.2.0/24"]

  ssh_subnet = ["10.120.3.0/24", "10.120.4.0/24"]

  db_subnet = ["10.120.5.0/24", "10.120.6.0/24"]

  public_elb_subnet = ["10.120.7.0/24", "10.120.8.0/24"]

  app_subnet = ["10.120.9.0/24", "10.120.10.0/24"]

  ssh_ips = ["x.x.x.x/32","x.x.x.x/32"] # only ips specified here will be allowed in ssh, example 54.2.4.4/32 etc

  app_running_port = "8080"

}
