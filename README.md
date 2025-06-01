# ☁️ AWS Scalable Web Architecture Project

This project sets up a **highly available**, **scalable**, and **secure** web application infrastructure on AWS using core services like EC2, ALB, ASG, EFS, and S3.

---

## 🚀 Tech Stack & Services Used

- **EC2 (Private Instances)** – Hosts the web application (Nginx)
- **ALB (Application Load Balancer)** – Distributes traffic across instances
- **ASG (Auto Scaling Group)** – Automatically scales EC2 instances
- **EFS (Elastic File System)** – Shared storage for all EC2s
- **NAT Gateway & IGW** – Internet access for private/public subnets

---

## 🧱 Architecture Overview

> A load-balanced, auto-scaled web infrastructure spread across multiple subnets with centralized storage and secure access.

![ChatGPT Image May 31, 2025, 10_05_08 PM](https://github.com/user-attachments/assets/36532963-4fb2-4ba4-8bcc-1444ff7391a4)


---

## 📦 Project Features

- 🚀 Auto Scaling using Launch Template and ASG (Spot + On-Demand mix)
- 🌐 Public-facing Application Load Balancer with two Target Groups (Port 80 & 8080)
- 🧳 Private EC2 Instances behind ALB for serving web content
- 📂 EFS used as shared storage, mounted on `/var/www/html`
- 💻 Custom AMI created for EC2 with pre-installed Apache and EFS mount
- 🔁 High Availability using Multi-AZ Subnets and Load Balancer
- 📈 Auto Scaling triggers based on CPU utilization (>65%)
- 🔒 Security Groups tightly configured:
  - ALB exposes only required ports (80, 8080 from specific IP)
  - EC2 only allows traffic from ALB SG
  - EFS only allows NFS from EC2 SG
- 🧹 Manual clean-up steps documented to avoid billing


---

## 🧹 Resource Deletion Guide

Make sure to follow the clean-up guide in [CLEANUP.md](./CLEANUP.md) to safely delete resources and avoid extra billing.

---




