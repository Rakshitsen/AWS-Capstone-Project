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

![Uploading ChatGPT Image May 31, 2025, 10_05_08 PM.png…]()

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



---

## ⚙️ EC2 Setup

- Launched a demo EC2 instance in Public Subnet
- Installed Apache (`httpd`) and placed a sample `index.html`
- Mounted EFS to `/var/www/html`
- Created **AMI** from this instance for ASG launch template

---

## 🧠 User Data Script

- A simple web app running on **port 8080** to:
- Display instance metadata
- Simulate CPU load for auto scaling tests
- Only accessible from `MY_IP/32`

---

## 🚀 Launch Template & ASG Configuration

- Used custom AMI to create **Launch Template**
- ASG:
- Desired Capacity: 2
- Min: 2, Max: 5
- Instance types: `t2.micro` (manually selected)
- Mixed purchase: 1 On-Demand, remaining Spot for cost savings
- Subnets: Both private subnets
- Scaling Policy: Target Tracking @ 65% average CPU
- Registered with **two Target Groups** (80 & 8080)

---

## 🌐 Load Balancer

- **Application Load Balancer** deployed in Public Subnets
- Two listeners:
- Port 80 → Web TG
- Port 8080 → Test TG
- DNS name used to access the application

---

## 🔒 Security & Cost Optimization Summary

| Feature           | Implementation                                                                 |
|-------------------|----------------------------------------------------------------------------------|
| High Availability | Multi-AZ setup, ASG across two private subnets                                 |
| Cost Optimization | Spot instances with 1 base On-Demand                                            |
| Central Storage   | Amazon EFS mounted on all web servers                                           |
| Controlled Access | SGs configured with principle of least privilege                                |
| Load Testing      | User data app for CPU spike → triggers ASG scaling                              |

---

## 🔍 How to Test

1. Access the app using ALB DNS name on:
 - Port 80: Regular site
 - Port 8080: Load-testing app (only from your IP)
2. Simulate high CPU load via test app
3. ASG automatically launches new instances (up to 5) as CPU > 65%
4. Monitor instances in ASG and targets in ALB

---

## 🧠 Learnings

- Real-world infra setup with HA, auto scaling, security, and cost-control
- Hands-on with user data scripts, AMI management, EFS, ASG configs
- Demonstrated how a web app can be deployed in a secure private subnet using ALB

---

## 📎 To-Do / Future Enhancements

- Add Route53
- Add Bastion Host for better SSH management
- CloudWatch log integration for metrics and alerts

---

## 👨‍💻 Author

**Rakshit**  
Feel free to connect on [LinkedIn](https://www.linkedin.com) and drop feedback or questions.

---


