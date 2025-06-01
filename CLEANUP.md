# 🧹 AWS Infrastructure Clean-Up Guide

This document provides the correct step-by-step deletion sequence of AWS resources for a VPC-based infrastructure with EC2, ASG, ALB, EFS, NAT Gateway, and more.

---

## 🔥 1. Terminate EC2 Instances

- Go to `EC2 > Instances`
- Select all **running EC2 instances**
- Click: `Actions > Instance State > Terminate`

---

## 🔁 2. Delete Auto Scaling Group (ASG)

- Navigate to: `EC2 > Auto Scaling Groups`
- Select the ASG and **delete it**

---

## 📄 3. Delete Launch Template

- Navigate to: `EC2 > Launch Templates`
- Delete the **Launch Template** used by ASG

---

## 🌐 4. Delete Load Balancer (ALB)

- Navigate to: `EC2 > Load Balancers`
- Delete your **Application Load Balancer (ALB)**

---

## 🎯 5. Delete Target Groups

- Go to: `EC2 > Target Groups`
- Select and delete **all target groups**
> ⚠️ ALB must be deleted *before* deleting target groups

---

## 📁 6. Delete EFS

- Go to: `EFS > File Systems`
- Make sure the EFS is not in use
- Select and **delete**

---

## 🌉 7. Delete NAT Gateway

- Go to: `VPC > NAT Gateways`
- Delete the **NAT Gateway**
- Then, release the **Elastic IP**

---

## 🌐 8. Release Elastic IP

- Go to: `EC2 > Elastic IPs`
- Select the IP and choose `Actions > Release addresses`

---

## 🔌 9. Detach & Delete Internet Gateway

- Go to: `VPC > Internet Gateways`
- Detach from VPC, then delete

---

## 🛣️ 10. Delete Route Tables

- Go to: `VPC > Route Tables`
- Delete **custom route tables** (e.g., public/private)
> ⚠️ Main Route Table will be deleted with the VPC

---

## 🌍 11. Delete Subnets

- Navigate to: `VPC > Subnets`
- Select all **public and private subnets**
- Delete them

---

## 🔐 12. Delete Custom Security Groups

- Go to: `EC2 > Security Groups`
- Delete **only** the custom ones (not the default)

---

## 🏠 13. Delete VPC

- Go to: `VPC > Your VPCs`
- Select and delete the **VPC**
> ⚠️ Ensure all components within are already removed

---

## 📜 14. Delete CloudFormation Stack (If Used)

- Go to: `CloudFormation > Stacks`
- Select your stack and delete
> ⚙️ Automatically deletes dependent resources

---

## 🪣 15. Delete S3 Buckets

- Navigate to: `S3 > Buckets`
- Empty and then delete all related buckets

---

## 🔐 16. Delete ACM Certificates (If HTTPS was used)

- Go to: `Certificate Manager`
- Select and delete unused SSL certificates

---

## 🗝️ 17. Delete Key Pairs

- Go to: `EC2 > Key Pairs`
- Delete any custom key pairs created for the EC2 instances

---

## ✅ Done!

Your AWS resources are now cleanly removed. Always remember to follow the dependency chain while deleting resources to avoid errors.

