provider "aws" {
  region = "us-east-1"
}

resource "aws_codecommit_repository" "revhire-job-repository" {
  repository_name = "revhire-job-repository"
  description     = "A revhire job-repository on AWS CodeCommit"
}

resource "null_resource" "clone_repo" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p C:/Users/shara/Desktop/revhire-job
      git clone ${aws_codecommit_repository.revhire-job-repository.clone_url_http} C:/Users/shara/Desktop/revhire-job
      cp -r C:/Users/shara/Desktop/revhire-job-local/* C:/Users/shara/Desktop/revhire-job
      cp -r C:/Users/shara/Desktop/revhire-job-local/.* C:/Users/shara/Desktop/revhire-job
      cd C:/Users/shara/Desktop/revhire-job
      git add .
      git commit -m "Initial commit"
      git push -u origin master
    EOT
    interpreter = ["C:\\Program Files\\Git\\bin\\bash.exe", "-c"]
  }

  depends_on = [aws_codecommit_repository.revhire-job-repository]
  triggers = {
    always_run = timestamp()
  }
}

data "aws_codecommit_repository" "revhire_job_repo" {
  repository_name = aws_codecommit_repository.revhire-job-repository.repository_name
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-service-role-for-job"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "codecommit:GitPull"
        ]
        Resource = data.aws_codecommit_repository.revhire_job_repo.arn
      },
      {
        Effect   = "Allow"
        Action   = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:us-east-1:914921102753:secret:revhire-job-access-keys-terraform-LL9b5H"
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "ecr-public:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "eks:DescribeCluster",
          "eks:GetToken"
        ]
        Resource = "arn:aws:eks:us-east-1:914921102753:cluster/my-cluster"
      }
    ]
  })
}



resource "aws_codebuild_project" "revhire-job-build" {
  name          = "revhire-job-build"
  description   = "Build project for revhire-job application"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"

    environment_variable {
      name  = "REPOSITORY_URI"
      value = "public.ecr.aws/w2k8x3r6/revhire-job-repo"
    }
    environment_variable {
      name  = "EKS_CLUSTERNAME"
      value = "revhire-cluster"
    }

    environment_variable {
      name  = "TAG" // Update to match your actual variable name
      value = "latest"
    }
  }

  source {
    type            = "CODECOMMIT"
    location        = data.aws_codecommit_repository.revhire_job_repo.clone_url_http
    buildspec       = "buildspec.yaml"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/revhire-job-build"
      stream_name = "build-log"
    }
  }
}
