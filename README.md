# 🏦 Online Banking System (MySQL)

## 📌 Project Overview

This project is a **MySQL-based Online Banking Database System** that simulates core banking operations such as account management, transactions, and role-based access control.

It demonstrates how a real-world banking backend can be structured using **SQL, roles, stored procedures, and permissions**.

---

## 🚀 Features

### 👥 Role-Based Access Control

* **Admin Role**

  * Full access to the database
* **Staff Role**

  * Can perform transactions (deposit, withdraw, transfer)
  * Can view customer and account details
  * Cannot delete logs
* **Customer Role**

  * Limited access to their own account details
  * Can perform allowed transactions

---

### 💳 Core Functionalities

* Customer management
* Account creation and handling
* Deposit operations
* Withdrawal operations
* Fund transfer between accounts
* Transaction tracking

---

### 🔐 Security & Permissions

* Implemented using **MySQL Roles**
* Fine-grained access using:

  * `GRANT` statements
* Controlled execution of:

  * Stored Procedures
* Separation of concerns between Admin, Staff, and Customer

---

### ⚙️ Stored Procedures

The system includes procedures for:

* `deposit_amount`
* `withdraw_amount`
* `transfer_funds`

These ensure:

* Data consistency
* Controlled transaction execution
* Reusability of business logic

---

### 📊 Views & Monitoring

* Audit-related views (e.g., admin audit view)
* Helps in tracking system activities

---

## 🛠️ Technologies Used

* MySQL
* SQL (DDL, DML, DCL)
* Stored Procedures
* Views
* Role-Based Access Control (RBAC)

---

## 📂 Project Structure

```
online_banking2.sql   --> Complete database script
README.md             --> Project documentation
```

---

## ▶️ How to Run

1. Open MySQL Workbench or CLI
2. Create database (if not already created):

   ```sql
   CREATE DATABASE ONLINEBANKING2;
   ```
3. Select database:

   ```sql
   USE ONLINEBANKING2;
   ```
4. Run the SQL file:

   ```sql
   SOURCE online_banking2.sql;
   ```

---

## ⚠️ Important Notes

* The script includes role and permission setup—run with a user having sufficient privileges.
* Avoid executing any commented **danger zone code** unless you fully understand it.
* Ensure proper MySQL version compatibility for roles and procedures.

---

## 🎯 Learning Outcomes

* Designed a real-world database schema
* Implemented role-based access using MySQL
* Used stored procedures for business logic
* Applied secure and structured database practices

---

## 📌 Future Improvements

* Integration with a Spring Boot backend
* Add triggers for automation
* Implement transaction rollback mechanisms
* Enhance audit logging system

---

## 👨‍💻 Author

Deepanshu Kaushik

---

## ⭐ If you find this useful

Give it a star on GitHub and feel free to fork!
