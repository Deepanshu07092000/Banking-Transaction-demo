USE ONLINEBANKING2;
SHOW TABLES;
SHOW FULL TABLES WHERE TABLE_TYPE = 'VIEW';
SHOW PROCEDURE STATUS WHERE Db = DATABASE();
 
/*------------------------- DANGER CODE NOT TO USE IT-----------------------------------------------------------------------*/
-- SET FOREIGN_KEY_CHECKS = 0;

-- SET @tables = (
--   SELECT GROUP_CONCAT(table_name)
--   FROM information_schema.tables
--   WHERE table_schema = 'online_banking'
-- );

-- SET @sql = CONCAT('DROP TABLE IF EXISTS ', @tables);
-- PREPARE stmt FROM @sql;
-- EXECUTE stmt;
-- DEALLOCATE PREPARE stmt;

-- SET FOREIGN_KEY_CHECKS = 1;

/*---------------------------------------------------CREATING DIFFERENT USERS------------------------------------------------------------*/
-- Admin role (full access)---------------
CREATE ROLE role_admin;

-- Staff role (limited transactional access)-----------
CREATE ROLE role_staff;

-- Customer role (read-only + own transactions)---------------------
CREATE ROLE role_customer;

/*----------------------------------------------GRANTING THE PERMISSIONS TO THE DIFFERENT USERS ACCORDING TO THEIR ROLES------------------*/
GRANT ALL PRIVILEGES ON ONLINEBANKING2.* TO role_admin;

/*----------------------------------------------STAFF (Can operate transactions, but cannot delete logs)----------------------------------*/
-------------------- Read access
GRANT SELECT ON ONLINEBANKING2.customers TO role_staff;
GRANT SELECT ON ONLINEBANKING2.accounts_details TO role_staff;

------------------ Transaction operations
GRANT EXECUTE ON PROCEDURE ONLINEBANKING2.deposit_amount TO role_staff;
GRANT EXECUTE ON PROCEDURE ONLINEBANKING2.withdraw_amount TO role_staff;
GRANT EXECUTE ON PROCEDURE ONLINEBANKING2.transfer_funds TO role_staff;

------------------- View audit logs (read-only)
GRANT SELECT ON ONLINEBANKING2.admin_audit_view TO role_staff;

/*-----------------------------------------------CUSTOMERS (can only see their account_details , perform the transactions)----------------*/
--------------------- Customer can only see their own data via views
GRANT SELECT ON ONLINEBANKING2.customer_account_view TO role_customer;

---------------------- Customer transactions (only via procedures)
GRANT EXECUTE ON PROCEDURE ONLINEBANKING2.deposit_amount TO role_customer;
GRANT EXECUTE ON PROCEDURE ONLINEBANKING2.withdraw_amount TO role_customer;
GRANT EXECUTE ON PROCEDURE ONLINEBANKING2.transfer_funds TO role_customer;

/*----------------------------------------------CREATING THE MYSQL USERS(ADMIN,STAFF,CUSTOMERS)-------------------------------------------*/
CREATE USER 'admin_user'@'%' IDENTIFIED BY 'Admin@123';
CREATE USER 'staff_user'@'%' IDENTIFIED BY 'Staff@123';
CREATE USER 'customer_user'@'%' IDENTIFIED BY 'Customer@123';

/*--------------------------------------------- GRANT ROLES TO THE USERS ----------------------------------------------------------------*/
GRANT role_admin TO 'admin_user'@'%';
GRANT role_staff TO 'staff_user'@'%';
GRANT role_customer TO 'customer_user'@'%';

/*-------------------------------------------- SET DEFAULT ROLES TO THE USRES ------------------------------------------------------------*/
SET DEFAULT ROLE role_admin TO 'admin_user'@'%';
SET DEFAULT ROLE role_staff TO 'staff_user'@'%';
SET DEFAULT ROLE role_customer TO 'customer_user'@'%';

/*-------------------------------------- TRIGGER FOR PREVENTING THE DELETE ON TRANSACTIONS DETAILS TABLE IF SOMEONE GETS THE PERMISSION---*/
CREATE TRIGGER prevent_transaction_delete
BEFORE DELETE ON transactions_details
FOR EACH ROW
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Deleting transaction history is forbidden';

/*-------------------------------------- TRIGGER FOR PREVENTING THE DELETEION FROM AUDIT LOGS TABLE--------------------------------------*/
DELIMITER $$

CREATE TRIGGER prevent_audit_logs_delete
BEFORE DELETE ON audit_logs
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Deleting audit logs is strictly forbidden';
END$$

DELIMITER ;

SELECT * FROM USERS_DETAILS;
SELECT * FROM CUSTOMERS;
SELECT * FROM ACCOUNTS_DETAILS;
SELECT * FROM user_customer_account_view; 

/*----------------------INITIATE THE DIFFERENT TRANSACTIONS---------------------------------------------------------------*/

/*----------TYPE OF TRANSACTIONS EXPLAIN IN THIS TABLE-----------------------------------------------------------
				Type	 FROM_ACCOUNT	 TO_ACCOUNT
				DEPOSIT	  NULL	         Account ID
                WITHDRAW  Account ID	 NULL
				TRANSFER  Account ID	Account ID   */

CALL deposit_amount(16,2500,105);
CALL withdraw_amount(4,3500,104);
CALL transfer_funds(4, 2, 1500.00,104);

/*---------------------------------VERIFICATION OF THE TRANSACTIONS-----------------------------------------------------------------------*/
SELECT * FROM ACCOUNTS_DETAILS;
SELECT * FROM TRANSACTIONS_DETAILS;
SELECT * FROM AUDIT_LOGS;
DELETE FROM AUDIT_LOGS WHERE LOG_ID = 2; 

/*-----------------------------ADMIN AUDIT VIEW(SO THAT THE ADMIN CAN SEE THE TRANSACTIONS DETAILS)--------------------------------------*/
CREATE OR REPLACE VIEW admin_audit_view AS
SELECT 
    u.username,
    a.transaction_type,
CASE 
    WHEN a.transaction_type = 'WITHDRAW' THEN a.from_account
    ELSE a.to_account
END AS account_id,
    a.log_time
FROM audit_logs a
JOIN users_details u ON a.user_id = u.users_id;

select * from admin_audit_view;

-- write a query which shows that the customers is not the part of the users details table (that is he is not eligible to perform the online transactions). 
SELECT 
    c.customer_id,
    c.full_name,
    c.email
FROM customers c
LEFT JOIN users_details u
    ON c.customer_id = u.customer_id
WHERE u.users_id IS NULL;

-- write a query that gives the staff from the users details.
SELECT U.USERS_ID, U.USERNAME FROM USERS_DETAILS U 
LEFT JOIN CUSTOMERS C ON U.CUSTOMER_ID = C.CUSTOMER_ID WHERE U.ROLE = 'STAFF';

/*-------------------USER_CUSTOMER_ACCOUNT_VIEW(THIS VIEW WILL GIVE THE DETAILS FOR THE CUSTOMERS AND THEIR ACCOUNTS)----*/
CREATE VIEW user_customer_account_view AS
SELECT 
    u.users_id,
    c.customer_id,
    c.full_name AS customer_name,
    a.account_id,
    a.account_type,
    a.status AS account_status
FROM users_details u
JOIN customers c 
    ON u.customer_id = c.customer_id
JOIN accounts_details a 
    ON c.customer_id = a.customer_id;
    
SELECT * FROM user_customer_account_view;     

/*------------------------USER TABLE (FOR STORING THE USERS DETAILS)-------------------------------------------------------*/
CREATE TABLE USERS_DETAILS(USERS_ID INT PRIMARY KEY,
						  USERNAME VARCHAR(30),
                          PASSWORD VARCHAR(255) NOT NULL, 
                          ROLE ENUM("ADMIN","STAFF","CUSTOMER") NOT NULL,
                          CUSTOMER_ID INT,
-- 						  CONSTRAINT chk_password
-- 						     CHECK (password REGEXP '^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[@#$%!]).{8,}$'),
                          CONSTRAINT fk_users_customer FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID),
                          CONSTRAINT chk_role_customer
							CHECK ((ROLE = 'CUSTOMER' AND CUSTOMER_ID IS NOT NULL) OR (ROLE IN ('ADMIN','STAFF') AND CUSTOMER_ID IS NULL))
);

/*------------------TRIGGER (FOR PASSWORD VALIDATION[REGEX CHECK], THEN CONVERT IT INTO THE HASH[SHA2(PASSWORD,256)])----------------------*/
DELIMITER $$

CREATE TRIGGER before_users_insert
BEFORE INSERT ON USERS_DETAILS
FOR EACH ROW
BEGIN
    -- Password validation
    IF NEW.password NOT REGEXP '^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[@#$%!]).{8,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Password does not meet complexity requirements';
    END IF;

    -- Hash password
    SET NEW.password = SHA2(NEW.password, 256);
END$$

DELIMITER ;


/*----------- AUTHORISATION ROLE------------------------
			  1. ADMIN ---> ACCESS TO ALL OPERATIONS
              2. STAFF---> DEPOSIT AND WITHDRAW OPERATIONS
              3. CUSTOMER----> CAN VIEW ONLY HIS ACCOUNT DETAILS----------*/

DESC USERS_DETAILS; 
INSERT INTO USERS_DETAILS VALUES(101,'ADMIN','ADMIN@!2000','ADMIN',NULL);
INSERT INTO USERS_DETAILS VALUES(102,'DEEPANSHU KAUSHIK','DEEPU@!2000','CUSTOMER',2);
INSERT INTO USERS_DETAILS VALUES(103,'ROHIT SHARMA','ROHIT@!2000','STAFF',NULL);
INSERT INTO USERS_DETAILS VALUES(104,'TANMAY GUPTA','TANMAY@!2000','CUSTOMER',3);
INSERT INTO USERS_DETAILS VALUES(105,'SNEHA BHANDARI','SNEHA@!2000','STAFF',NULL);
INSERT INTO USERS_DETAILS VALUES(106,'AYUSHI SHARMA','AYUSHI@!2000','CUSTOMER',6);
INSERT INTO USERS_DETAILS VALUES(107,'VIRAT KOLHI','KOLHI@!2000','CUSTOMER',7);
INSERT INTO USERS_DETAILS VALUES(108,'KOBE BRYANT','KOBE@!2000','CUSTOMER',8);
INSERT INTO USERS_DETAILS VALUES(109,'MICHAEL JORDAN','JORDEN@!2000','STAFF',NULL);
INSERT INTO USERS_DETAILS VALUES(110,'SHAQ O NEIL','NEIL@!2000','ADMIN',NULL);
SELECT * FROM USERS_DETAILS;

/*------------------------VIEW (TO HIDE THE PASSWORDS OF THE ENTERED USERS)--------------------------------------------------------------*/
CREATE VIEW users_public_view AS
SELECT
    USERS_ID,
    USERNAME,
    ROLE,
    CUSTOMER_ID
FROM USERS_DETAILS;

SELECT * FROM users_public_view;

/*-------------------------BRANCHES TABLE TO STORE THE DETAILS OF THE DIFFERENT BRANCHES-------------------------------------------------*/

CREATE TABLE BRANCHES(
					 BRANCH_ID INT PRIMARY KEY,
                     BRANCH_NAME VARCHAR(30),
                     LOCATION VARCHAR(50)
                     );

DESC BRANCHES;
 
INSERT INTO branches (branch_id, branch_name, location) VALUES
(1001, 'State Bank of India', 'Bangalore'),
(1002, 'HDFC Bank', 'Mumbai'),
(1003, 'ICICI Bank', 'Delhi'),
(1004, 'Axis Bank', 'Pune'),
(1005, 'Punjab National Bank', 'Chandigarh'),
(1006, 'Canara Bank', 'Mangalore'),
(1007, 'Bank of Baroda', 'Ahmedabad'),
(1008, 'Kotak Mahindra Bank', 'Hyderabad'),
(1009, 'IDFC First Bank', 'Chennai'),
(1010, 'Union Bank of India', 'Kolkata');

SELECT * FROM BRANCHES;

/*------------------------CUSTOMER TABLE (TO STORE THE CUSTOMER DETAILS)-------------------------------------------------*/
CREATE TABLE CUSTOMERS(CUSTOMER_ID INT AUTO_INCREMENT PRIMARY KEY,
					   FULL_NAME VARCHAR(50) NOT NULL,
                       EMAIL VARCHAR(50) UNIQUE,
                       PHONE_NO VARCHAR(20),
                       CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                       BRANCH_ID INT,
                       FOREIGN KEY (BRANCH_ID) REFERENCES branches(BRANCH_ID)
                       );
DESC CUSTOMERS; 

INSERT INTO CUSTOMERS (FULL_NAME, EMAIL, PHONE_NO,BRANCH_ID)
VALUES ('Rahul Sharma', 'rahul2000@gmail.com', '9876543210',1001);
INSERT INTO CUSTOMERS (FULL_NAME, EMAIL, PHONE_NO,BRANCH_ID)
VALUES ('DEEPANSHU KAUSHIK', 'DEEPU2000@gmail.com', '9098637389',1002);
INSERT INTO CUSTOMERS (FULL_NAME, EMAIL, PHONE_NO,BRANCH_ID)
VALUES ('TANMAY GUPTA', 'TANMAY2000@gmail.com', '9987642000',1003);
INSERT INTO CUSTOMERS (FULL_NAME, EMAIL, PHONE_NO,BRANCH_ID)
VALUES ('ROHIT SHARMA', 'ROHIT2000@gmail.com', '97654290861',1004);
INSERT INTO CUSTOMERS (FULL_NAME, EMAIL, PHONE_NO,BRANCH_ID)
VALUES ('SNEHA BHANDARI', 'SNEHA2002@gmail.com', '9987539201',1005);
INSERT INTO CUSTOMERS (FULL_NAME, EMAIL, PHONE_NO,BRANCH_ID)
VALUES ('AYUSHI SHARMA', 'AYUSHI2003@gmail.com', '9775372901',1006);
INSERT INTO CUSTOMERS (FULL_NAME, EMAIL, PHONE_NO,BRANCH_ID)
VALUES ('VIRAT KOLHI', 'KOLHI1998@gmail.com', '8907654321',1007);
INSERT INTO CUSTOMERS (FULL_NAME, EMAIL, PHONE_NO,BRANCH_ID)
VALUES ('KOBE BRYANT', 'KOBE1998@gmail.com', '8907654551',1008);
INSERT INTO CUSTOMERS (FULL_NAME, EMAIL, PHONE_NO,BRANCH_ID)
VALUES ('SHAQ O NEIL', 'SHAQ1996@gmail.com', '9907654551',1009);
INSERT INTO CUSTOMERS (FULL_NAME, EMAIL, PHONE_NO,BRANCH_ID)
VALUES ('MICHAEL JORDAN', 'JORDAN1995@gmail.com', '8860765455',1010);
SELECT * FROM CUSTOMERS;

/*----------------ACCOUNTS TABLE TO STORE THE DETAILS OF THE CUSTOMERS_ACCOUNT------------------------------------------*/
CREATE TABLE ACCOUNTS_DETAILS(ACCOUNT_ID INT AUTO_INCREMENT PRIMARY KEY,
							 CUSTOMER_ID INT,
                             BALANCE DECIMAL(10,2) CHECK (BALANCE >= 0),
                             ACCOUNT_TYPE ENUM('SAVINGS','CURRENT') NOT NULL,
                             STATUS ENUM('ACTIVE','INACTIVE','CLOSED') DEFAULT 'ACTIVE',
                             CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                             CONSTRAINT fk_accounts_customer FOREIGN KEY(CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID)
                             );
DESC ACCOUNTS_DETAILS; 

/*-------------------STORED PROCEDURE (FOR CHECKING THE VALIDATION OF THE CUSTOMER TO CREATE THE ACCOUNT)----*/
DELIMITER $$

CREATE PROCEDURE create_account(
    IN p_customer_id INT,
    IN p_account_type ENUM('SAVINGS','CURRENT'),
    IN p_initial_balance DECIMAL(10,2),
    IN p_status ENUM('ACTIVE','INACTIVE')
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM customers WHERE customer_id = p_customer_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Customer does not exist';
    END IF;

    INSERT INTO accounts_details (
        customer_id,
        balance,
        account_type,
        status
    )
    VALUES (
        p_customer_id,
        p_initial_balance,
        p_account_type,
        p_status
    );
END$$

DELIMITER ;
CALL create_account(2, 'SAVINGS', 20000.00, 'ACTIVE');
CALL create_account(2, 'CURRENT', 2000.00, 'ACTIVE');
CALL create_account(3, 'CURRENT', 45000.00, 'ACTIVE');
CALL create_account(3, 'SAVINGS', 200000.00, 'ACTIVE');
CALL create_account(6, 'CURRENT', 80000.00, 'ACTIVE');
CALL create_account(6, 'SAVINGS', 50000.00, 'ACTIVE');
CALL create_account(7, 'CURRENT', 20000.00, 'ACTIVE');
CALL create_account(7, 'SAVINGS', 1000.00, 'INACTIVE');
CALL create_account(10, 'CURRENT', 400000.00, 'ACTIVE');
CALL create_account(10, 'SAVINGS', 50000.00, 'INACTIVE');
CALL create_account(5, 'CURRENT', 70000.00, 'ACTIVE');
CALL create_account(5, 'CURRENT', 60000.00, 'INACTIVE');
CALL create_account(4, 'SAVINGS', 10000.00, 'ACTIVE');
CALL create_account(9, 'SAVINGS', 1000000.00, 'ACTIVE');
CALL create_account(1, 'SAVINGS', 90000.00, 'ACTIVE');
CALL create_account(1, 'CURRENT', 2500.00, 'ACTIVE');

SELECT * FROM ACCOUNTS_DETAILS;


/*----------VIEW FOR CUSTOMERS TO FETCH THEIR ACCOUNT DETAILS--------------------------------------------------------*/
CREATE VIEW customer_account_view AS
SELECT
    c.customer_id,
    c.full_name,
    a.account_id,
    a.account_type,
    a.balance,
    a.status
FROM customers c
JOIN accounts_details a
ON c.customer_id = a.customer_id;

SELECT * FROM CUSTOMER_ACCOUNT_VIEW;

/*----------------------------TRANSACTIONS TABLE (FOR STORING THE TRANSACTIONS DETAILS)-------------------------------------*/
CREATE TABLE TRANSACTIONS_DETAILS(TRANSACTIONS_ID INT AUTO_INCREMENT PRIMARY KEY,
								 PERFORMED_BY INT,
								 FROM_ACCOUNT INT,
                                 TO_ACCOUNT INT,
                                 AMOUNT DECIMAL(10,2) CHECK (AMOUNT > 0),
                                 TRANSACTION_TYPE ENUM('DEPOSIT','WITHDRAW','TRANSFER') NOT NULL,
                                 TRANSACTION_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                 CONSTRAINT fk_tx_from_account FOREIGN KEY (FROM_ACCOUNT) REFERENCES ACCOUNTS_DETAILS(ACCOUNT_ID),
                                 CONSTRAINT fk_tx_to_account FOREIGN KEY (TO_ACCOUNT) REFERENCES ACCOUNTS_DETAILS(ACCOUNT_ID),
								 CONSTRAINT fk_tx_user FOREIGN KEY (PERFORMED_BY) REFERENCES USERS_DETAILS(USERS_ID)
);

/*----------TYPE OF TRANSACTIONS EXPLAIN IN THIS TABLE-----------------------------------------------------------
				Type	 FROM_ACCOUNT	 TO_ACCOUNT
				DEPOSIT	  NULL	         Account ID
                WITHDRAW  Account ID	 NULL
				TRANSFER  Account ID	Account ID   */

DESC TRANSACTIONS_DETAILS;
SELECT * FROM ACCOUNTS_DETAILS;
SELECT * FROM TRANSACTIONS_DETAILS;

/*-----------------------------------STORE PROCEDURE FOR DEPOSIT AMOUNT (first the checking of customer takes place and then if the customer do not exist
in the users_details table then the transaction is completed by the staff----------*/

DELIMITER $$

CREATE PROCEDURE deposit_amount(
    IN p_account_id INT,
    IN p_amount DECIMAL(10,2),
    IN p_performed_by INT
)
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_user_customer_id INT;
    DECLARE v_account_status VARCHAR(20);

    -- Get role
    SELECT role, customer_id
    INTO v_role, v_user_customer_id
    FROM users_details
    WHERE users_id = p_performed_by;

    -- Check account status
    SELECT status INTO v_account_status
    FROM accounts_details
    WHERE account_id = p_account_id;

    -- Customer ownership check
    IF v_role = 'CUSTOMER' THEN
        IF NOT EXISTS (
            SELECT 1 FROM accounts_details
            WHERE account_id = p_account_id
            AND customer_id = v_user_customer_id
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Customer can deposit only into own account';
        END IF;
    END IF;

    -- Account must be active
    IF v_account_status != 'ACTIVE' OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Deposit failed: invalid account or amount';
    END IF;

    START TRANSACTION;

    UPDATE accounts_details
    SET balance = balance + p_amount
    WHERE account_id = p_account_id;

    INSERT INTO transactions_details
    (from_account, to_account, amount, transaction_type, performed_by)
    VALUES
    (NULL, p_account_id, p_amount, 'DEPOSIT', p_performed_by);

    COMMIT;
END$$

DELIMITER ;

/*-----------------------------------STORE PROCEDURE FOR WITHDRAW AMOUNT (first the checking of customer takes place and then if the customer do not exist
in the users_details table then the transaction is completed by the staff----------*/

DELIMITER $$

CREATE PROCEDURE withdraw_amount(
    IN p_account_id INT,
    IN p_amount DECIMAL(10,2),
    IN p_performed_by INT
)
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_user_customer_id INT;
    DECLARE v_balance DECIMAL(10,2);
    DECLARE v_status VARCHAR(20);

    SELECT role, customer_id
    INTO v_role, v_user_customer_id
    FROM users_details
    WHERE users_id = p_performed_by;

    SELECT balance, status
    INTO v_balance, v_status
    FROM accounts_details
    WHERE account_id = p_account_id;

    -- CUSTOMER restriction
    IF v_role = 'CUSTOMER' THEN
        IF NOT EXISTS (
            SELECT 1 FROM accounts_details
            WHERE account_id = p_account_id
            AND customer_id = v_user_customer_id
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Customer can withdraw only from own account';
        END IF;
    END IF;

    IF v_status != 'ACTIVE' OR v_balance < p_amount OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Withdraw failed: invalid account or insufficient funds';
    END IF;

    START TRANSACTION;

    UPDATE accounts_details
    SET balance = balance - p_amount
    WHERE account_id = p_account_id;

    INSERT INTO transactions_details
    (from_account, to_account, amount, transaction_type, performed_by)
    VALUES
    (p_account_id, NULL, p_amount, 'WITHDRAW', p_performed_by);

    COMMIT;
END$$

DELIMITER ;

/*-----------------------------------STORE PROCEDURE FOR TRANSFER AMOUNT (first the checking of customer takes place and then if the customer do not exist
in the users_details table then the transaction is completed by the staff----------*/

DELIMITER $$

CREATE PROCEDURE transfer_funds(
    IN p_sender INT,
    IN p_receiver INT,
    IN p_amount DECIMAL(10,2),
    IN p_performed_by INT
)
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_user_customer_id INT;
    DECLARE v_sender_balance DECIMAL(10,2);
    DECLARE v_sender_status VARCHAR(20);
    DECLARE v_receiver_status VARCHAR(20);

    SELECT role, customer_id
    INTO v_role, v_user_customer_id
    FROM users_details
    WHERE users_id = p_performed_by;

    SELECT balance, status
    INTO v_sender_balance, v_sender_status
    FROM accounts_details
    WHERE account_id = p_sender;

    SELECT status
    INTO v_receiver_status
    FROM accounts_details
    WHERE account_id = p_receiver;

    -- CUSTOMER restriction (sender must be their own)
    IF v_role = 'CUSTOMER' THEN
        IF NOT EXISTS (
            SELECT 1 FROM accounts_details
            WHERE account_id = p_sender
            AND customer_id = v_user_customer_id
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Customer can transfer only from own account';
        END IF;
    END IF;

    IF v_sender_status != 'ACTIVE'
       OR v_receiver_status != 'ACTIVE'
       OR v_sender_balance < p_amount
       OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transfer failed: validation error';
    END IF;

    START TRANSACTION;

    UPDATE accounts_details
    SET balance = balance - p_amount
    WHERE account_id = p_sender;

    UPDATE accounts_details
    SET balance = balance + p_amount
    WHERE account_id = p_receiver;

    INSERT INTO transactions_details
    (from_account, to_account, amount, transaction_type, performed_by)
    VALUES
    (p_sender, p_receiver, p_amount, 'TRANSFER', p_performed_by);

    COMMIT;
END$$

DELIMITER ;

/*-----------------------AUDIT LOGS TABLE (TO STORE THE DETAILS FOR THE TRANSACTIONS----------------------------------------*/
CREATE TABLE AUDIT_LOGS(LOG_ID INT AUTO_INCREMENT PRIMARY KEY,
						FROM_ACCOUNT INT NULL,
		                TO_ACCOUNT INT NULL,
                        USER_ID INT NOT NULL,
                        TRANSACTION_TYPE ENUM('DEPOSIT','WITHDRAW','TRANSFER')NOT NULL,
                        LOG_TIME TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
						CONSTRAINT fk_audit_user FOREIGN KEY (USER_ID) REFERENCES USERS_DETAILS(USERS_ID),
						CONSTRAINT fk_audit_fromaccount FOREIGN KEY (FROM_ACCOUNT) REFERENCES ACCOUNTS_DETAILS(ACCOUNT_ID),
                        CONSTRAINT fk_audit_toaccount FOREIGN KEY (TO_ACCOUNT) REFERENCES ACCOUNTS_DETAILS(ACCOUNT_ID)
                        );
-- DROP TABLE AUDIT_LOGS;                        
DESC AUDIT_LOGS;



/*-----------TRIGGER FOR EACH TRANSATIONS----------------------------------------------------------------------------------*/
-- DROP TRIGGER IF EXISTS after_transaction_insert;

DELIMITER $$

CREATE TRIGGER after_transaction_insert
AFTER INSERT ON transactions_details
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (
        from_account,
        to_account,
        user_id,
        transaction_type
    )
    VALUES (
        NEW.from_account,
        NEW.to_account,
        NEW.performed_by,
        NEW.transaction_type
    );
END$$
DELIMITER ;

SELECT * FROM AUDIT_LOGS;

/*-----------------------------ADMIN AUDIT VIEW(SO THAT THE ADMIN CAN SEE THE TRANSACTIONS DETAILS)--------------------------*/
CREATE VIEW admin_audit_view AS
SELECT u.username, a.transaction_type, a.account_id, a.log_time
FROM audit_logs a
JOIN users_details u ON a.user_id = u.users_id;

select * from admin_audit_view;





             

                
