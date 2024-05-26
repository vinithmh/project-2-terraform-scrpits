provider "aws" {
  region = "us-east-1"
}

resource "aws_codecommit_repository" "my_repo" {
  repository_name = "code_commit_p2"
  description     = "Repository for Project"

  tags = {
    Environment = "Dev"
    Name        = "code_commit_p2"
  }
}

output "repository_clone_url_http" {
  value = aws_codecommit_repository.my_repo.clone_url_http
}

output "repository_clone_url_ssh" {
  value = aws_codecommit_repository.my_repo.clone_url_ssh
}
