variable "stack_name" {}

variable "key_path" {
    default = "~/.ssh/amazon.pem"
}

variable "key_name" {
    default = "amazon"
}

# aws creds
variable "aws_access_key" {}
variable "aws_secret_key" {}

variable "cloudflare_email" {}
variable "cloudflare_token" {}
variable "cloudflare_domain" {}

# aws network stuff
variable "region" {
  default = "ap-southeast-2"
}

variable "instance_size" {
    default = "m3.medium"
}

variable "bastion_instance_size" {
    default = "t2.micro"
}

variable "cluster_size" {
    default = 3
}

# coreos images
variable "coreos_amis" {
  default = {
    ap-southeast-2 = "ami-4dd3a777"
  }
}

# ubuntu images
variable "ubuntu_amis" {
  default = {
    ap-southeast-2 = "ami-e9d091d3"
  }
}
