variable "use_case" {
  default = "tf-aws-s3_replication"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_resourcegroups_group" "example" {
  name        = "tf-rg-example-${random_string.suffix.result}"
  description = "Resource group for example resources"

  resource_query {
    query = <<JSON
    {
      "ResourceTypeFilters": [
        "AWS::AllSupported"
      ],
      "TagFilters": [
        {
          "Key": "Owner",
          "Values": ["John Ajera"]
        },
        {
          "Key": "UseCase",
          "Values": ["${var.use_case}"]
        }
      ]
    }
    JSON
  }

  tags = {
    Name    = "tf-rg-example-${random_string.suffix.result}"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_s3_bucket" "source" {
  bucket        = "tf-s3-example-source-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name    = "tf-s3-example-source-${random_string.suffix.result}"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.source.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "destination" {
  provider      = aws.southeast2
  bucket        = "tf-s3-example-destination-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name    = "tf-s3-example-destination-${random_string.suffix.result}"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_s3_bucket_versioning" "s3_replication" {
  provider = aws.southeast2
  bucket   = aws_s3_bucket.destination.id
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "s3_replication" {
  name               = "tf-iam-role-s3_replication-example-${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name    ="tf-iam-role-s3_replication-example-${random_string.suffix.result}"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

data "aws_iam_policy_document" "s3_replication" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.source.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${aws_s3_bucket.source.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${aws_s3_bucket.destination.arn}/*"]
  }
}

resource "aws_iam_policy" "s3_replication" {
  name   = "tf-iam-policy-s3_replication-example-${random_string.suffix.result}"
  policy = data.aws_iam_policy_document.s3_replication.json
}

resource "aws_iam_role_policy_attachment" "s3_replication" {
  role       = aws_iam_role.s3_replication.name
  policy_arn = aws_iam_policy.s3_replication.arn
}

resource "aws_s3_bucket_replication_configuration" "s3_replication" {

  role     = aws_iam_role.s3_replication.arn
  bucket   = aws_s3_bucket.source.id

  rule {
    id = "rule1"

    filter {
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.destination.arn
      storage_class = "STANDARD"
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }

  depends_on = [
    aws_s3_bucket.destination,
    aws_s3_bucket.source,
    aws_s3_bucket_versioning.source
  ]
}

resource "null_resource" "config" {
  # triggers = {
  #   always_run = timestamp()
  # }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3 cp external/sample.jpg  s3://tf-s3-example-source-${random_string.suffix.result}
    EOT
  }

  depends_on = [
    aws_s3_bucket_replication_configuration.s3_replication
  ]
}
