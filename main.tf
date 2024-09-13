resource "aws_security_group" "factorio_security_group" {
  name        = "factorio-sg"
  description = "Security group for Factorio server"
  tags = {
    Name        = "factorio-security-group"
    Application = "factorio"
  }
}

resource "aws_vpc_security_group_ingress_rule" "factorio_ingress_rule" {
  security_group_id = aws_security_group.factorio_security_group.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 34197
  ip_protocol = "udp"
  to_port     = 34197

  tags = {
    Name        = "factorio-ingress-rule"
    Application = "factorio"
  }
}

resource "aws_ebs_volume" "factorio_server_storage" {
  availability_zone = "us-east-1a"
  size              = 8
  type              = "gp3"

  tags = {
    Name        = "factorio-server-storage"
    Application = "factorio"
  }
}

resource "aws_volume_attachment" "ebs_attachment" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.factorio_server_storage.id
  instance_id = aws_instance.factorio_server.id
}

resource "aws_instance" "factorio_server" {
  ami                         = "ami-0182f373e66f89c85"
  instance_type               = "t3.micro"
  availability_zone           = "us-east-1a"
  security_groups             = [aws_security_group.factorio_security_group.name]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y wget unzip

              # Add a dedicated user for Factorio
              useradd -m factorio

              # Switch to factorio user
              su - factorio -c "
              # Download Factorio server
              wget https://www.factorio.com/get-download/latest/headless/linux64 -O factorio_headless.tar.xz
              # Extract files
              tar -xvf factorio_headless.tar.xz
              # Remove the archive
              rm factorio_headless.tar.xz
              "

              # Create a systemd service file
              echo "[Unit]
              Description=Factorio Headless Server

              [Service]
              Type=simple
              User=factorio
              ExecStart=/home/factorio/factorio/bin/x64/factorio --start-server /home/factorio/factorio/saves/my-save.zip
              Restart=on-failure

              [Install]
              WantedBy=multi-user.target" > /etc/systemd/system/factorio.service

              # Create a save directory and generate a new map
              su - factorio -c "
              mkdir -p /home/factorio/factorio/saves
              if [ ! -f /home/factorio/factorio/saves/my-save.zip ]; then
                /home/factorio/factorio/bin/x64/factorio --create /home/factorio/factorio/saves/my-save.zip
              fi
              "

              # Start and enable the Factorio service
              systemctl daemon-reload
              systemctl start factorio
              systemctl enable factorio
              EOF

  tags = {
    Name        = "factorio-server"
    Application = "factorio"
  }
}
