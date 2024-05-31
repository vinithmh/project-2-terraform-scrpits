#Creating a code-commit repo
provider "aws" {
  region = "us-east-1"
}
resource "aws_codecommit_repository" "my_frontend_repo" {
  repository_name = var.frontend-repo-name
  description     = "Repository for Project"

  tags = {
    Environment = "Dev"
    Name        = "code_commit_p2"
  }
}

#pushing files to code-commit repo
resource "null_resource" "clone_repo" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir gitreponew
      pwd
      git clone ${aws_codecommit_repository.my_frontend_repo.clone_url_http} gitreponew/
      cp -r revhire-frontend/* gitreponew/
      cd gitreponew
      git add .
      git commit -m "Initial commit"
      git push -u origin master
    EOT
    interpreter = ["C:\\Program Files\\Git\\bin\\bash.exe", "-c"]
  }

  depends_on = [aws_codecommit_repository.my_frontend_repo]
  triggers = {
    always_run = timestamp()
  }
}

#Creating a s3 bucket
resource "aws_s3_bucket" "myfrontendbucket" {
  bucket = var.frontend-bucket-name

}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.myfrontendbucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

#Giving public access
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.myfrontendbucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

#Disabling acl controls
resource "aws_s3_bucket_acl" "example" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.myfrontendbucket.id
  acl    = "private"
}

# Bucket policy to allow public read access to objects
resource "aws_s3_bucket_policy" "mybucket_policy" {
  bucket = aws_s3_bucket.myfrontendbucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = [
				"s3:GetObject",
				"s3:PutObject"
			]
        Resource  = "${aws_s3_bucket.myfrontendbucket.arn}/*"
      }
    ]
  })
}

#Enabling static web hosting
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.myfrontendbucket.id
  index_document {
    suffix = "index.html"
  }
}

output "static_web_hosting_url" {
  value = aws_s3_bucket.myfrontendbucket.website_endpoint
}

# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CodeBuild role
resource "aws_iam_role_policy" "codebuild_role_policy" {
  name   = "codebuild-role-policy"
  role   = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "sts:GetServiceBearerToken"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "codecommit:GitPull"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# CodeBuild project
resource "aws_codebuild_project" "codecommit_project" {
  name          = "codecommit-build-project"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 30  # 30 minutes build timeout

  source {
    type            = "CODECOMMIT"
    location        = "https://git-codecommit.us-east-1.amazonaws.com/v1/repos/${var.frontend-repo-name}"
    git_clone_depth = 1

    buildspec = <<EOF
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 18
    commands:
      - echo Installing the Angular CLI...
      - npm install -g @angular/cli
  pre_build:
    commands:
      - echo Installing dependencies...
      - npm install
  build:
    commands:
      - echo Building the Angular application...
      - ng build --configuration production
  post_build:
    commands:
      - echo Build completed successfully.
      - echo Copying files to S3...
      - aws s3 cp dist/revhire/ s3://${var.frontend-bucket-name}/ --recursive

artifacts:
  files:
    - '**/*'
  base-directory: dist
  discard-paths: no
EOF
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true  # Needed for Docker commands
    image_pull_credentials_type = "CODEBUILD"
  }

  cache {
    type = "NO_CACHE"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/codecommit-build-project"
      stream_name = "build-log"
    }
  }
}
