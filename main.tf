resource "aws_security_group" "factorio_sg" {
  name        = "factorio-sg"
  description = "Security group for Factorio server"
}

resource "aws_vpc_security_group_egress_rule" "factorio_egress_rule" {
  security_group_id = aws_security_group.factorio_sg.id

  from_port   = 34197
  to_port     = 34197
  ip_protocol = "udp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "factorio_ingress_rule" {
  security_group_id = aws_security_group.factorio_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 34197
  ip_protocol = "udp"
  to_port     = 34197
}

resource "aws_instance" "factorio_server" {
  ami                         = "ami-0182f373e66f89c85"
  instance_type               = "t3.micro"
  security_groups             = [aws_security_group.factorio_sg.name]
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
              su - factorio -c "/home/factorio/factorio/bin/x64/factorio --create /home/factorio/factorio/saves/my-save.zip"

              # Start and enable the Factorio service
              systemctl daemon-reload
              systemctl start factorio
              systemctl enable factorio
              EOF

  tags = {
    Name = "factorio-server"
  }
}
