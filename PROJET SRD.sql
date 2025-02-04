# Storing and Retrieving Data Course @ NOVA IMS
# Alice Viegas 20240572
# Bernardo Faria 20240579


CREATE DATABASE IF NOT EXISTS Mountain_Ski_Shop DEFAULT CHARACTER SET = 'utf8' DEFAULT COLLATE 'utf8_general_ci';
USE Mountain_Ski_Shop;



CREATE TABLE IF NOT EXISTS customer (
  CUSTOMER_ID INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  FIRST_NAME VARCHAR(25) NOT NULL,
  LAST_NAME VARCHAR(25) NOT NULL,
  EMAIL VARCHAR(100) UNIQUE NOT NULL,
  PHONE_NUMBER VARCHAR(15)                        -- Stores the phone number as a string, allowing for characters like '+' for international formats
);

CREATE TABLE IF NOT EXISTS equipment (
  EQUIPMENT_ID INT UNSIGNED PRIMARY KEY,
  CATEGORY ENUM( 'HELMET', 'GOGGLES', 'SKIS', 'SKI BOOTS', 'SNOWBOARD', 'SNOWBOARD BOOTS') NOT NULL,
  BRAND ENUM('SALOMON', 'ATOMIC', 'HEAD', 'ROSSIGNOL') NOT NULL,
  SIZE VARCHAR(50),
  PRICE_PER_DAY DECIMAL(10,2) NOT NULL,
  STOCK INT UNSIGNED DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS store (
  STORE_ID INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  STORE_NAME VARCHAR(50),
  MANAGER_ID INT UNSIGNED DEFAULT NULL,
  STORE_MAINTENANCE_COSTS INT UNSIGNED
);

CREATE TABLE IF NOT EXISTS employee (
  EMPLOYEE_ID INT NOT NULL DEFAULT 0 PRIMARY KEY,
  FIRST_NAME VARCHAR(25) NOT NULL,
  LAST_NAME VARCHAR(25) NOT NULL,
  MANAGER_ID INT UNSIGNED DEFAULT NULL,
  STORE_ID INT UNSIGNED DEFAULT NULL,
  FOREIGN KEY (STORE_ID) REFERENCES store(STORE_ID)
	ON DELETE RESTRICT                                    -- Blocks deletion of a store if there are employee records referencing it
	ON UPDATE CASCADE                                     -- If the store is updated, STORE_ID in employee is also updated
);  

CREATE TABLE IF NOT EXISTS rental (
  RENTAL_ID INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  CUSTOMER_ID INT UNSIGNED NOT NULL,
  START_DATE DATE NOT NULL,
  RETURN_DATE DATE NOT NULL,
  EMPLOYEE_ID INT NOT NULL,
  FOREIGN KEY (CUSTOMER_ID) REFERENCES customer(CUSTOMER_ID)
    ON DELETE RESTRICT                                    -- Blocks deletion of a customer if there are rental records referencing it
    ON UPDATE CASCADE,                                    -- If the customer is updated, STORE_ID in rental is also updated
  FOREIGN KEY (EMPLOYEE_ID) REFERENCES employee(EMPLOYEE_ID)
    ON DELETE RESTRICT                                    -- Blocks deletion of an employee if there are rental records referencing it
    ON UPDATE CASCADE                                     -- If the employee is updated, EMPLOYEE_ID in rental is also updated
);


CREATE TABLE IF NOT EXISTS rental_detail (
  RENTAL_ID INT UNSIGNED NOT NULL,
  EQUIPMENT_ID INT UNSIGNED NOT NULL,
  QUANTITY INT UNSIGNED NOT NULL,
  PRIMARY KEY (RENTAL_ID, EQUIPMENT_ID),
  FOREIGN KEY (RENTAL_ID) REFERENCES rental(RENTAL_ID)
    ON UPDATE CASCADE                                    -- If the rental is updated, RENTAL_ID in rental_detail is also updated
    ON DELETE RESTRICT,                                  -- Blocks deletion of a rental if there are rental_detail records referencing it
  FOREIGN KEY (EQUIPMENT_ID) REFERENCES equipment(EQUIPMENT_ID)
    ON UPDATE CASCADE                                    -- If the equipment is updated, EQUIPMENT_ID in rental_detail is also updated
    ON DELETE RESTRICT                                   -- Blocks deletion of an equipment if there are rental_detail records referencing it
);

CREATE TABLE IF NOT EXISTS rating (
  RENTAL_ID INT UNSIGNED NOT NULL,
  EMPLOYEE_ID INT NOT NULL,
  RATING TINYINT UNSIGNED,
  REVIEW VARCHAR(100),
  PRIMARY KEY (RENTAL_ID, EMPLOYEE_ID),
  CHECK (RATING >= 0 AND RATING <= 5),
  FOREIGN KEY (RENTAL_ID) REFERENCES rental(RENTAL_ID)
    ON UPDATE CASCADE                                    -- If the rental is updated, RENTAL_ID in rating is also updated
    ON DELETE RESTRICT,                                  -- Blocks deletion of a rental if there are rating records referencing it
  FOREIGN KEY (EMPLOYEE_ID) REFERENCES employee(EMPLOYEE_ID)
    ON UPDATE CASCADE                                    -- If the employee is updated, EMPLOYEE_ID in rating is also updated
    ON DELETE RESTRICT                                   -- Blocks deletion of an employee if there are rating records referencing it
);


CREATE TABLE IF NOT EXISTS log (
  LOG_ID INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  TIME_STAMP DATETIME NOT NULL,
  RENTAL_ID INT UNSIGNED,
  EVENT_TYPE ENUM('RENTAL', 'RETURN', 'PAYMENT') NOT NULL,  -- ENUM specifies and restricts the type of event
  FOREIGN KEY (RENTAL_ID) REFERENCES rental(RENTAL_ID)
    ON UPDATE CASCADE                                       -- If the rental is updated, RENTAL_ID in log is also updated
    ON DELETE CASCADE                         		        -- If the rental is deleted, all log entries associated with that RENTAL_ID are also deleted
);

CREATE TABLE IF NOT EXISTS payment(
  PAYMENT_ID INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  RENTAL_ID INT UNSIGNED NOT NULL,
  PAYMENT_DATE DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  AMOUNT DECIMAL(10,2) NOT NULL,							-- Will be generated from the rental details using a trigger
  FOREIGN KEY (RENTAL_ID) REFERENCES rental(RENTAL_ID)
    ON UPDATE CASCADE                                  		-- If the rental is updated, RENTAL_ID in payments is also updated   
    ON DELETE CASCADE                                 	    -- If the rental is deleted, all payments associated with that RENTAL_ID are also deleted
);





-- Triggers-

#1  Trigger updates the equipment stock after a new entry is added to the rental_detail table.

DELIMITER $$ 
CREATE TRIGGER update_stock_on_rental
AFTER INSERT ON rental_detail
FOR EACH ROW
BEGIN
	UPDATE equipment
	SET stock = stock - NEW.quantity                   -- Stock quantity is updated
	WHERE equipment_id = NEW.equipment_id;
END $$
DELIMITER ;




#2  Trigger inserts an entry into the payment table and calculates the amount value after a new entry is added to the rental_detail table.

DELIMITER $$ 
CREATE TRIGGER insert_payment_on_rental
AFTER INSERT ON rental_detail
FOR EACH ROW
BEGIN
    -- Step 1: Delete any existing payment rows for the same rental_id so that only the one with the total amount remains
    DELETE FROM payment
    WHERE rental_id = NEW.rental_id;

    -- Step 2: Insert the correct payment entry
    INSERT INTO payment (rental_id, amount, payment_date)
    SELECT 
		rd.rental_id,
        SUM(e.price_per_day * rd.quantity) * DATEDIFF(r.return_date, r.start_date), 
        r.start_date
    FROM rental r
    JOIN rental_detail rd ON rd.rental_id = r.rental_id
    JOIN equipment e ON rd.equipment_id = e.equipment_id
    WHERE rd.rental_id = NEW.rental_id
    GROUP BY rd.rental_id;
END$$
DELIMITER ;




#3 Trigger inserts an entry into the log table whenever a new record is added to the rental table.

DELIMITER $$   
CREATE TRIGGER log_rental 
AFTER INSERT ON rental
FOR EACH ROW
BEGIN
    INSERT INTO log (rental_id, event_type, time_stamp)
    VALUES ( NEW.rental_id, 'RENTAL', NEW.start_date);
END $$
DELIMITER ;




#4 Trigger inserts an entry into the log table whenever a new record is added to the rental table.

DELIMITER $$  
CREATE TRIGGER log_payment 
AFTER INSERT ON payment
FOR EACH ROW
BEGIN
    INSERT INTO log (rental_id, event_type, time_stamp)
    VALUES (NEW.rental_id, 'PAYMENT', NEW.payment_date );
END$$
DELIMITER ;



 
#5 Trigger updates the equipment stock whenever a return is logged in the log table.

DELIMITER $$
CREATE TRIGGER update_stock_on_return
AFTER INSERT ON log
FOR EACH ROW
BEGIN
    IF NEW.EVENT_TYPE = 'RETURN' THEN                                                     -- Check if the event type is 'RETURN'
        UPDATE equipment AS e                                                             -- Update the stock in the equipment table
        JOIN rental_detail rd ON e.equipment_id = rd.equipment_id
        JOIN rental r ON r.rental_id = rd.rental_id
        SET e.stock = e.stock + rd.quantity                                               
        WHERE r.rental_id = NEW.rental_id;   
    END IF;
END$$
DELIMITER ;


INSERT INTO customer (FIRST_NAME, LAST_NAME, EMAIL, PHONE_NUMBER) VALUES
('David', 'Perez', 'david.perez@yahoo.es', '+34 655998877'),
('William', 'Smith', 'william.smith@gmail.com', '+44 7911122233'),
('Claire', 'Moreau', 'claire.moreau@gmail.com', '+33 634567890'),
('Antonio', 'Rodrigues', 'antonio.rodrigues@gmail.com', '+351 956789012'),
('Sergio', 'Fernandez', 'sergio.fernandez@outlook.com', '+34 633778899'),
('Jean', 'Martin', 'jean.martin@outlook.com', '+33 645678901'),
('Ana', 'Lopez', 'ana.lopez@hotmail.com', '+34 622556677'),
('Bernardo', 'Lynce', 'bernardo.lynce@gmail.com', '+351 912345678'),
('Oliver', 'Brown', 'oliver.brown@yahoo.co.uk', '+44 7834455667'),
('Lucia', 'Sanchez', 'lucia.sanchez@gmail.com', '+34 644889900'),
('Thomas', 'Leroy', 'thomas.leroy@hotmail.com', '+33 623456789'),
('Beatriz', 'Fernandes', 'beatriz.fernandes@outlook.com', '+351 945678901'),
('Elena', 'Garcia', 'elena.garcia@gmail.com', '+34 611223344'),
('Miguel', 'Pereira', 'miguel.pereira@yahoo.pt', '+351 934567890'),
('Sofia', 'Costa', 'sofia.costa@hotmail.com', '+351 923456789'),
('Maria', 'Gonzalez', 'maria.gonzalez@hotmail.com', '+34 666777888'),
('Emily', 'Johnson', 'emily.johnson@hotmail.com', '+44 7723344556'),
('Carlos', 'Martinez', 'carlos.martinez@yahoo.es', '+34 612334455'),
('Javier', 'Ruiz', 'javier.ruiz@outlook.com', '+34 677889900'),
('Lucas', 'Müller', 'lucas.mueller@gmail.de', '+49 1523456789'),
('Ava', 'Schmidt', 'ava.schmidt@gmail.de', '+49 1573567890'),
('Noah', 'Johansson', 'noah.johansson@gmail.se', '+46 731234567'),
('Aria', 'Petrov', 'aria.petrov@gmail.ru', '+7 9123456789'),
('Lucas', 'Pereira', 'lucas.pereira@gmail.com', '+34 612334899'),
('Ethan', 'Kowalski', 'ethan.kowalski@gmail.pl', '+48 512345678');

INSERT INTO equipment (EQUIPMENT_ID, CATEGORY, BRAND, SIZE, PRICE_PER_DAY, STOCK) VALUES
-- Helmets (ID starts with 1)
(11, 'HELMET', 'SALOMON', 'M', 20.00, 20),
(12, 'HELMET', 'ROSSIGNOL', 'L', 22.50, 20),
(13, 'HELMET', 'HEAD', 'S', 18.00, 20),
(14, 'HELMET', 'ATOMIC', 'M', 25.00, 20),

-- Goggles (ID starts with 2)
(21, 'GOGGLES', 'SALOMON', 'L', 15.00, 15),
(22, 'GOGGLES', 'HEAD', 'M', 18.00, 15),
(23, 'GOGGLES', 'ROSSIGNOL', 'S', 20.00, 15),
(24, 'GOGGLES', 'ATOMIC', 'L', 17.50, 15),

-- Skis (ID starts with 3)
(31, 'SKIS', 'SALOMON', '150cm', 40.00, 30),
(32, 'SKIS', 'ROSSIGNOL', '170cm', 45.00, 30),
(33, 'SKIS', 'HEAD', '160cm', 42.00, 30),
(34, 'SKIS', 'ATOMIC', '180cm', 48.00, 30),

-- Ski Boots (ID starts with 4)
(41, 'SKI BOOTS', 'SALOMON', '42', 30.00, 25),
(42, 'SKI BOOTS', 'ROSSIGNOL', '44', 32.00, 20),
(43, 'SKI BOOTS', 'HEAD', '40', 28.00, 25),
(44, 'SKI BOOTS', 'ATOMIC', '43', 35.00, 25),
(45, 'SKI BOOTS', 'SALOMON', '39', 28.00, 25),
(46, 'SKI BOOTS', 'ROSSIGNOL', '41', 30.00, 25),
(47, 'SKI BOOTS', 'HEAD', '38', 26.00, 20),
(48, 'SKI BOOTS', 'ATOMIC', '45', 34.00, 20),

-- Snowboards (ID starts with 5)
(51, 'SNOWBOARD', 'SALOMON', '155cm', 50.00, 25),
(52, 'SNOWBOARD', 'ROSSIGNOL', '160cm', 55.00, 25),
(53, 'SNOWBOARD', 'HEAD', '165cm', 53.00, 25),
(54, 'SNOWBOARD', 'ATOMIC', '150cm', 52.00, 25),

-- Snowboard Boots (ID starts with 6)
(61, 'SNOWBOARD BOOTS', 'SALOMON', '42', 35.00, 25),
(62, 'SNOWBOARD BOOTS', 'ROSSIGNOL', '44', 37.00, 20),
(63, 'SNOWBOARD BOOTS', 'HEAD', '41', 33.00, 25),
(64, 'SNOWBOARD BOOTS', 'ATOMIC', '43', 38.00, 25),
(65, 'SNOWBOARD BOOTS', 'SALOMON', '40', 32.00, 25),
(66, 'SNOWBOARD BOOTS', 'ROSSIGNOL', '46', 39.00, 20),
(67, 'SNOWBOARD BOOTS', 'HEAD', '39', 30.00, 25),
(68, 'SNOWBOARD BOOTS', 'ATOMIC', '44', 36.00, 20);


INSERT INTO store (STORE_NAME, MANAGER_ID, STORE_MAINTENANCE_COSTS) VALUES
('Andorra-La-Vella Ski Shop', NULL, 6000), 
('Soldeu Snow Gear', NULL, 9500),          
('Pas de la Casa Ski Rentals', NULL, 1200);


INSERT INTO employee (EMPLOYEE_ID, FIRST_NAME, LAST_NAME, MANAGER_ID, STORE_ID) VALUES
(1, 'Ricardo', 'Martinez', NULL, 1),  
(2, 'Camille', 'Dupont', 1, 1),       
(3, 'Nuria', 'Torres', 1, 1),         
(4, 'François', 'Girard', 1, 1),      

(5, 'Mathieu', 'Benoit', NULL, 2),     
(6, 'Alice', 'Viegas', 5, 2),          
(7, 'Adèle', 'Lemoine', 5, 2),        
(8, 'Pedro', 'Santos', 5, 2),         

(9, 'Olivier', 'Roux', NULL, 3),       
(10, 'Marta', 'Perez', 9, 3),         
(11, 'Lucien', 'Lemoine', 9, 3),      
(12, 'Valentina', 'Bianchi', 9, 3);   

-- Assign managers to each store
UPDATE store SET MANAGER_ID = 1 WHERE STORE_ID = 1;                          -- Assign Ricardo (Employee 1) to Store 1
UPDATE store SET MANAGER_ID = 5 WHERE STORE_ID = 2;                          -- Assign Mathieu (Employee 5) to Store 2
UPDATE store SET MANAGER_ID = 9 WHERE STORE_ID = 3;                          -- Assign Olivier (Employee 9) to Store 3


INSERT INTO rental (customer_id, start_date, return_date, employee_id) VALUES 
-- First ski season (Dec 2022 - May 2023)
(1, '2022-12-22', '2022-12-27', 2),
(2, '2022-12-23', '2022-12-29', 11),
(3, '2023-01-02', '2023-01-08', 8),
(4, '2023-01-10', '2023-01-15', 10),
(5, '2023-01-18', '2023-01-25', 3),
(6, '2023-02-01', '2023-02-05', 4),
(7, '2023-02-10', '2023-02-14', 12),
(8, '2023-03-01', '2023-03-07', 6),
(9, '2023-03-10', '2023-03-16', 7),
(10, '2023-04-01', '2023-04-08', 8),
(11, '2023-04-12', '2023-04-17', 2),
(12, '2023-05-01', '2023-05-05', 6),
(13, '2023-05-12', '2023-05-15', 3),
(14, '2023-05-15', '2023-05-23', 12),

-- Second ski season (Dec 2023 - May 2024)
(13, '2023-12-20', '2023-12-26', 11),
(15, '2023-12-22', '2023-12-28', 10),
(16, '2024-01-05', '2024-01-10', 4),
(17, '2024-01-15', '2024-01-20', 7),
(18, '2024-02-01', '2024-02-07', 6),
(1, '2024-02-10', '2024-02-15', 3),
(19, '2024-03-01', '2024-03-06', 12),
(14, '2024-03-15', '2024-03-22', 2),
(20, '2024-04-01', '2024-04-07', 8),
(21, '2024-04-10', '2024-04-15', 11),
(6, '2024-04-20', '2024-04-25', 4),
(22, '2024-05-01', '2024-05-05', 7),
(23, '2024-05-10', '2024-05-15', 10),
(24, '2024-05-12', '2024-05-18', 3),
(25, '2024-05-17', '2024-05-20', 6),
(11, '2024-05-24', '2024-05-26', 12);


INSERT INTO rental_detail (RENTAL_ID, EQUIPMENT_ID, QUANTITY) VALUES
-- December 2022 to May 2023 Rentals
(1, 11, 1), (1, 22, 1), (1, 31, 1), (1, 43, 1), 
(2, 32, 1), (2, 42, 1),            
(3, 12, 2), (3, 45, 2), (3, 33, 2), (3, 21, 2),            
(4, 14, 1), (4, 33, 1), (4, 47, 1),                       
(5, 52, 3), (5, 62, 3),            
(6, 22, 2), (6, 44, 2), (6, 34, 1),                      
(7, 12, 1), (7, 31, 1), (7, 46, 1),                       
(8, 13, 1), (8, 42, 1), (8, 53, 1),                       
(9, 11, 2), (9, 41, 2),                                  
(10, 12, 1), (10, 32, 1), (10, 21, 1),                  
(11, 21, 4), (11, 43, 3), (11, 34, 5),                    
(12, 14, 1), (12, 53, 1), (12, 67, 1),                    
(13, 13, 1), (13, 45, 1), (13, 23, 1),                    
(14, 11, 2), (14, 31, 2), (14, 43, 2);

INSERT INTO LOG (TIME_STAMP, RENTAL_ID, EVENT_TYPE) VALUES
-- December 2022 to May 2023 Returns
('2022-12-27', 1, 'RETURN'),
('2022-12-29', 2, 'RETURN'),
('2023-01-08', 3, 'RETURN'),
('2023-01-15', 4, 'RETURN'),
('2023-01-25', 5, 'RETURN'),
('2023-02-05', 6, 'RETURN'),
('2023-02-14', 7, 'RETURN'),
('2023-03-07', 8, 'RETURN'),
('2023-03-16', 9, 'RETURN'),
('2023-04-08', 10, 'RETURN'),
('2023-04-17', 11, 'RETURN'),
('2023-05-05', 12, 'RETURN'),
('2023-05-15', 13, 'RETURN'),
('2023-05-23', 14, 'RETURN');

INSERT INTO rental_detail (RENTAL_ID, EQUIPMENT_ID, QUANTITY) VALUES
-- December 2023 to May 2024 Rentals
(15, 22, 1), (15, 48, 1), (15, 32, 1),
(16, 31, 1), (16, 41, 1),                    
(17, 13, 1), (17, 21, 1), (17, 33, 1),                    
(18, 12, 1), (18, 42, 1), (18, 53, 1), (18, 63, 1),      
(19, 14, 2), (19, 33, 2), (19, 64, 2),                   
(20, 11, 2), (20, 52, 1), (20, 68, 1),                    
(21, 22, 1), (21, 44, 1), (21, 31, 1),                    
(22, 12, 2), (22, 31, 2), (22, 47, 2), (22, 21, 2),       
(23, 13, 1), (23, 42, 1), (23, 53, 1), (23, 61, 1),       
(24, 11, 2), (24, 41, 2), (24, 33, 2),                    
(25, 12, 1), (25, 32, 1), (25, 22, 1),                   
(26, 21, 2), (26, 43, 2), (26, 31, 2),                   
(27, 14, 1), (27, 53, 1), (27, 62, 1),                    
(28, 13, 1), (28, 45, 1), (28, 24, 1),                    
(29, 11, 2), (29, 31, 2), (29, 46, 2), (29, 23, 2),      
(30, 22, 1), (30, 44, 1), (30, 31, 1);                  
 
INSERT INTO LOG (TIME_STAMP, RENTAL_ID, EVENT_TYPE) VALUES
-- December 2023 to May 2024 Returns
('2023-12-26', 15, 'RETURN'),
('2023-12-28', 16, 'RETURN'),
('2024-01-10', 17, 'RETURN'),
('2024-01-20', 18, 'RETURN'),
('2024-02-07', 19, 'RETURN'),
('2024-02-15', 20, 'RETURN'),
('2024-03-06', 21, 'RETURN'),
('2024-03-22', 22, 'RETURN'),
('2024-04-07', 23, 'RETURN'),
('2024-04-15', 24, 'RETURN'),
('2024-04-25', 25, 'RETURN'),
('2024-05-05', 26, 'RETURN'),
('2024-05-15', 27, 'RETURN'),
('2024-05-18', 28, 'RETURN'),
('2024-12-20', 29, 'RETURN'),
('2024-05-26', 30, 'RETURN');


INSERT INTO rating (RENTAL_ID, EMPLOYEE_ID, RATING, REVIEW) VALUES
(1, 2, 5, 'Great service, very friendly!'),
(2, 11, 4, 'Good experience, but could improve on equipment variety.'),
(3, 8, 3, 'Average service, not very attentive.'),
(4, 10, 4, 'Nice quality equipment, but a bit slow.'),
(5, 3, 5, 'Fantastic experience, everything was perfect!'),
(6, 4, 2, 'The skis were too big, and I struggled with them.'),
(7, 12, 5, 'Excellent customer service! Will come back.'),
(9, 7, 3, 'Good service, but the helmet wasn’t the right fit.'),
(10, 8, 4, 'Nice experience, I liked the goggles.'),
(11, 2, 5, 'Everything was perfect, I will recommend this to others!'),
(12, 6, 3, 'It was okay, but could have been quicker with rentals.'),
(13, 3, 4, 'Good overall, though they were out of my preferred ski size.'),
(14, 12, 5, 'The snowboarding gear was top-notch!'),
(15, 11, 4, 'Friendly staff, but some equipment options were limited.'),
(17, 4, 3, 'Not the best experience, some equipment was damaged.'),
(18, 7, 5, 'Fantastic rental, the skis were excellent and fit perfectly.'),
(19, 6, 4, 'Very good service, I had no complaints at all.'),
(20, 3, 5, 'Absolutely fantastic experience, very professional staff!'),
(21, 12, 3, 'Okay, the gear wasn’t ideal, but staff was friendly.'),
(22, 2, 4, 'Great experience, will rent here again.'),
(23, 8, 5, 'Excellent service and great equipment, highly recommend!'),
(24, 11, 4, 'Everything was great, but I had to wait a little.'),
(25, 4, 5, 'The boots fit perfectly, and the staff was great.'),
(26, 7, 3, 'Good gear, but had some issues with the ski boots fitting.'),
(27, 10, 5, 'Amazing snowboarding experience, everything was perfect.'),
(29, 6, 5, 'Top-quality gear, the staff was very helpful and attentive.'),
(30, 12, 3, 'Decent service, but the skis were a bit worn out.');





-- BUSINESS QUESTIONS --

#1. What is the store with the best average rating?
SELECT s.STORE_NAME, AVG(rt.RATING) AS AVERAGE_RATING
FROM store AS s
JOIN employee AS e 
ON s.STORE_ID = e.STORE_ID
JOIN rating AS rt 
ON e.EMPLOYEE_ID = rt.EMPLOYEE_ID
GROUP BY s.STORE_ID
ORDER BY AVERAGE_RATING DESC
LIMIT 1;
    
#Ans: Andorra-la-Vella Ski Shop, with an average rating of 4.2222.


#2. Which product category is rented the most?
SELECT e.CATEGORY, SUM(rd.QUANTITY) AS TOTAL_RENTED
FROM rental_detail AS rd
JOIN equipment AS e 
ON rd.EQUIPMENT_ID = e.EQUIPMENT_ID
GROUP BY e.CATEGORY
ORDER BY TOTAL_RENTED DESC
LIMIT 1;
    
#Ans: The most rented product is a pair of ski boots, and it has been rented 33 times.


#3. What was the average rental duration? And the average total spending per rental?
SELECT 
AVG(DATEDIFF(r.return_date, r.start_date)) AS avg_rental_duration,
AVG(p.amount) AS avg_payment_amount
FROM rental AS r
JOIN payment AS p ON r.rental_id = p.rental_id;

#Ans: The average rental duration is 5.2333 days while the average spending per rental is 732.2833€.



#4. What is the store with the highest profit across both seasons?
SELECT s.store_name, SUM(p.amount)-s.store_maintenance_costs*2 AS total_revenue
FROM payment AS p
JOIN rental AS r 
ON p.rental_id = r.rental_id
JOIN employee AS e 
ON r.employee_id = e.employee_id
JOIN store AS s 
ON e.store_id = s.store_id
GROUP BY s.store_id, s.store_name, s.store_maintenance_costs
ORDER BY total_revenue DESC
LIMIT 1;

#Ans: Pas de La Casa Ski Shop has the highest profit, with 3453€.


#5. What was the percentage change in revenue between ski seasons?
SELECT season_1_revenue, season_2_revenue,
  ROUND((season_2_revenue - season_1_revenue) / season_1_revenue * 100, 2) AS percentage_increase
FROM (
  SELECT
    SUM(CASE WHEN PAYMENT_DATE BETWEEN '2022-12-01' AND '2023-05-31' THEN AMOUNT ELSE 0 END) AS season_1_revenue,
    SUM(CASE WHEN PAYMENT_DATE BETWEEN '2023-12-01' AND '2024-05-31' THEN AMOUNT ELSE 0 END) AS season_2_revenue
  FROM payment
  WHERE PAYMENT_DATE BETWEEN '2022-12-01' AND '2024-05-31') AS revenue_summary;

#Ans: Revenue decreased by 7.61% from season 1 to season 2.





-- VIEWS --

CREATE VIEW Invoice_Header AS
SELECT 
	r.RENTAL_ID,
    CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME) AS CUSTOMER_NAME,
    c.EMAIL AS CUSTOMER_EMAIL,
    c.PHONE_NUMBER AS CUSTOMER_PHONE,
    r.START_DATE,
    r.RETURN_DATE,
    CONCAT(p.AMOUNT, '€') AS TOTAL_AMOUNT
FROM rental AS r
JOIN customer AS c ON r.CUSTOMER_ID = c.CUSTOMER_ID
JOIN payment AS p ON r.RENTAL_ID = p.RENTAL_ID;

SELECT * FROM Invoice_Header WHERE RENTAL_ID = 1; -- Replace 1 with the desired rental_id


CREATE VIEW Invoice_Details AS
SELECT 
    r.RENTAL_ID,
    rd.EQUIPMENT_ID,
    e.CATEGORY,
    e.BRAND,
    e.SIZE,
    rd.QUANTITY,
    e.PRICE_PER_DAY,
    (rd.QUANTITY * e.PRICE_PER_DAY * DATEDIFF(r.RETURN_DATE, r.START_DATE)) AS TOTAL_PRICE
FROM rental_detail rd
JOIN rental AS r ON rd.RENTAL_ID = r.RENTAL_ID
JOIN equipment AS e ON rd.EQUIPMENT_ID = e.EQUIPMENT_ID;


SELECT * FROM Invoice_Details WHERE RENTAL_ID = 1; -- Replace 1 with the desired rental_id




-- Testing --

select* from equipment;

INSERT INTO rental (customer_id, start_date, return_date, employee_id) VALUES 
(1, '2025-12-22', '2025-12-27', 2);

INSERT INTO rental_detail (RENTAL_ID, EQUIPMENT_ID, QUANTITY) VALUES
(31, 11, 1), (31, 22, 1), (31, 31, 1), (31, 43, 1); 

select* from equipment;

select * from payment;

select * from log;

INSERT INTO LOG (TIME_STAMP, RENTAL_ID, EVENT_TYPE) VALUES
('2025-12-22', 31, 'RETURN');

select * from log;
