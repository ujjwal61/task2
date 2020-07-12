provider "aws" {
  version = "~> 2.0"
region = "ap-south-1"
profile = "myujjwal"

}
variable "key_name" {
  default = "terraform_task1"
}

resource "tls_private_key" "ec2_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "terraform_task1"
  public_key = tls_private_key.ec2_private_key.public_key_openssh
}





//creating security group

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-f9859991"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}





//Launching EC2 instance using above key and SG

resource "aws_instance" "linuxefs" {
ami = "ami-0447a12f28fddb066"
instance_type = "t2.micro"
key_name = "iamkey"
security_groups = ["${aws_security_group.allow_tls.id}"]
subnet_id = "subnet-8e8184e6"
tags = {
 Name = "tasksecond"
  }
}



// Creating EFS
resource "aws_efs_file_system" "linuxefs" {
  creation_token = "linuxefsfile"

  tags = {
    Name = "efsFileSystem"
  }
}

// Mounting EFS
resource "aws_efs_mount_target" "mountefs" {
  file_system_id  = aws_efs_file_system.linuxefs.id
  subnet_id       = "subnet-8e8184e6"
  security_groups = ["${aws_security_group.allow_tls.id}",]
}

// Configuring the external volume
resource "null_resource" "setupVol" {
  depends_on = [
    aws_efs_mount_target.mountefs,
  ]


connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/UJJWAL DIXIT/Downloads/iamkey.pem")
    host     = aws_instance.linuxefs.public_ip
  }

provisioner "remote-exec"{
   
       inline = [
         
          "sudo yum install httpd php git -y",
	  "sudo systemctl start httpd",
	  "sudo systemctl enable httpd",
          "sudo mkfs.ext4  /dev/xvdf",
          "sudo rm -rf /var/www/html/*",
          "sudo mount  /dev/xvdf  /var/www/html",
          "sudo git clone https://github.com/ujjwal61/task2.git /html_repo",
	  "sudo cp -r /html_repo/* /var/www/html",
	  "sudo rm -rf /html_repo"
         ]

    }
}

// Creating S3 Bucket

resource "aws_s3_bucket" "b" {
  bucket = "cloudtask"
  acl    = "public-read"
  versioning {
 enabled = true
 } 
  
       
  
tags = {
    Name = "My bucket"
  }
}

//creating S3 bucket_object


resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.b.bucket
  key    = "My_Image"
  acl = "public-read"
  source="C:/Users/UJJWAL DIXIT/Downloads/terraimg.jpg"
  depends_on = [ aws_s3_bucket.b ]
  
}

locals {
  s3_origin_id = "myS3Origin"
}
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "some comment"
}







//cloudfront distribution 
resource "aws_cloudfront_distribution" "s3_distribution" {


origin {
    domain_name = aws_s3_bucket.b.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "My_Image"
default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD",  "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
forwarded_values {
      query_string = false
cookies {
        forward = "none"
      }
    }
viewer_protocol_policy = "allow-all"
     min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  
  }


# Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    Environment = "production"
  }

viewer_certificate {
    cloudfront_default_certificate = true
  }

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/UJJWAL DIXIT/Downloads/iamkey.pem")
    host     = aws_instance.linuxefs.public_ip
  }














}