variable "region" {
    default = "eu-west-1"
    description = "Currently deployments are only allowed to Ireland"
}

variable "tags" {
  type = map(string)
  default = {}
}