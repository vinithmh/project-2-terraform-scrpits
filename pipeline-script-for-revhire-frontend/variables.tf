variable "frontend-repo-name"{
    description = "code commit repository name"
    type = string
    default = "revhire-frontend"
}
variable "frontend-bucket-name" {
  description = "frontend bucket name"
  type = string
  default = "revhire-frontend-dynamic-bucket"
}