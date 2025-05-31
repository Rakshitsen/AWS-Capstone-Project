# 🌐 High Availability & Cost-Optimized Web Infrastructure on AWS

This project demonstrates a **highly available**, **secure**, and **cost-efficient** web infrastructure on AWS using key services like EC2, ALB, Auto Scaling Group (ASG), EFS, and more — all within a custom VPC.

---

## 📐 Architecture Overview

- **VPC CIDR:** `192.168.0.0/24`
- **Subnets:**
  - Public Subnet 1A: `192.168.0.0/26`
  - Public Subnet 1B: `192.168.0.64/26`
  - Private Subnet 1A: `192.168.0.128/26`
  - Private Subnet 1B: `192.168.0.192/26`
- **Availability Zones:** Multi-AZ setup for HA

![Architecture Diagram](<insert-path-or-link>)  
_(Replace with actual diagram URL or local image)_

---

## 🔧 Key Components

### VPC & Networking
- Created a VPC and four subnets (2 public, 2 private)
- Attached Internet Gateway and configured public Route Table
- Created NAT Gateway in a public subnet with Elastic IP
- Private subnets access internet via NAT

### Security Groups
| SG Name        | Purpose                          | Inbound Rules                                                                 |
|----------------|----------------------------------|--------------------------------------------------------------------------------|
| ALB-SG         | For Application Load Balancer    | TCP 80 from `0.0.0.0/0`<br>TCP 8080 from `MY_IP/32`                            |
| WebServer-SG   | For EC2 instances                | TCP 80, 8080 from `ALB-SG` only                                               |
| EFS-SG         | For shared file storage          | NFS 2049 from `WebServer-SG` only                                             |

---

## 📁 Storage: Amazon EFS

- Created EFS and mounted it on EC2 demo instance at `/var/www/html`
- Modified `/etc/fstab` to ensure persistence after reboot:
- fs-<id>.efs.<region>.amazonaws.com:/ /var/www/html efs defaults,_netdev 0 0
