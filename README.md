# ☁️ AWS Scalable Web Architecture Project

This project sets up a **highly available**, **scalable**, and **secure** web application infrastructure on AWS using core services like EC2, ALB, ASG, EFS, and S3.

---

## 🚀 Tech Stack & Services Used

- **EC2 (Private Instances)** – Hosts the web application (Nginx)
- **ALB (Application Load Balancer)** – Distributes traffic across instances
- **ASG (Auto Scaling Group)** – Automatically scales EC2 instances
- **EFS (Elastic File System)** – Shared storage for all EC2s
- **S3 (Static Assets)** – Stores and syncs static web content
- **ACM (HTTPS)** – SSL certificate for secure traffic
- **NAT Gateway & IGW** – Internet access for private/public subnets
- **Bastion Host** – Secure SSH access to private instances
- **CloudWatch** – Monitoring and log collection

---

## 🧱 Architecture Overview

> A load-balanced, auto-scaled web infrastructure spread across multiple subnets with centralized storage and secure access.

![Architecture Diagram](./architecture.png)

---

## 📦 Project Features

- 🚀 Auto Scaling with Launch Template
- 🔐 Private Subnet EC2s with Bastion Host
- 🌐 HTTPS-enabled Load Balancer
- 📂 Nginx content synced from S3 to EFS
- 📊 CloudWatch monitoring for logs and alarms

---

## 🧹 Resource Deletion Guide

Make sure to follow the clean-up guide in [CLEANUP.md](./CLEANUP.md) to safely delete resources and avoid extra billing.

---




