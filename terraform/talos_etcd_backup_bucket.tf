# Single bucket shared by all environments. Bucket lifecycle managed from the
# production workspace only; staging and other workspaces read it by name.

resource "aws_s3_bucket" "talos_etcd_backup" {
  count = terraform.workspace == "production" ? 1 : 0

  bucket        = local.talos_backup_shared_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = local.talos_backup_shared_bucket_name
    ManagedBy = "terraform"
    Purpose   = "talos-etcd-backup"
  }
}

resource "aws_s3_bucket_versioning" "talos_etcd_backup" {
  count = terraform.workspace == "production" ? 1 : 0

  bucket = aws_s3_bucket.talos_etcd_backup[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "talos_etcd_backup" {
  count = terraform.workspace == "production" ? 1 : 0

  bucket = aws_s3_bucket.talos_etcd_backup[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "talos_etcd_backup" {
  count = terraform.workspace == "production" ? 1 : 0

  bucket = aws_s3_bucket.talos_etcd_backup[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
