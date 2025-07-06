-- E-Commerce Order Management System
-- Author [Kyrylo Zaiets]
-- Purpose: To build a relational database for managing e-commerce orders, tracking customer activity, and enabling basic reporting and archiving



-- Step 1: Create customers table

CREATE TABLE Customers
(
	customer_id serial,
	customer_email varchar(20) UNIQUE NOT NULL,
	customer_name varchar(200) NOT NULL,
	customer_country char(2) NOT NULL,

	CONSTRAINT PK_customer_customer_id PRIMARY KEY(customer_id)
);

-- Step 2: Create products table and category index

CREATE INDEX idx_product_category ON products(product_category);

CREATE TABLE Products
(
	product_id serial,
	product_price numeric(10,2) CHECK (product_price >= 0),
	product_name varchar(100) NOT NULL,
	product_category varchar(100) NOT NULL,

	CONSTRAINT PK_product_product_id PRIMARY KEY(product_id)
);

-- Step 3: Define order status enum

CREATE TYPE order_status_enum AS ENUM ('in_proccessing', 'dispatched', 'completed');

-- Step 4: Create orders table with foreign key

CREATE TABLE Orders
(
	ship_date date NOT NULL,
	order_date date NOT NULL,
	order_id serial PRIMARY KEY,
	customer_id serial,
	status order_status_enum NOT NULL DEFAULT 'in_proccessing',

	CONSTRAINT fk_orders_customer
		FOREIGN KEY(customer_id) REFERENCES customers(customer_id)
);

-- Step 5: Create order_items junction table with composite primary key

CREATE TABLE Order_items
(
	order_id bigint NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
	product_id bigint NOT NULL REFERENCES products(product_id),
	quantity int NOT NULL CHECK(quantity > 0),
	unit_price numeric(10,2) NOT NULL,
	PRIMARY KEY (order_id, product_id)
);

-- Step 6: Create supporting index on product_id

CREATE INDEX idx_order_items_product ON order_items(product_id);

-- Step 7: Insert seed data into customers

INSERT INTO Customers(customer_email, customer_name, customer_country)
VALUES
  ('anna@mail.pl',   'Anna Nowak',   'PL'),
  ('denisp@gmail.com',    'Denis Pushkar',   'UA'),
  ('chris@uk.co',    'Chris Smith',  'GB');

-- Step 8: Insert seed data into products

INSERT INTO Products(product_price, product_name, product_category)
VALUES
	(2499.99, 'Laptop Pro 13"',   'Electronics'),
    (199.00,  'Wireless Headset', 'Accessories'),
    (79.50,   'Mouse RGB',        'Accessories'),
    (999.00,  'Monitor 27"',      'Electronics');

-- Step 9: Insert orders with FK to customers

INSERT INTO Orders(customer_id, order_date, ship_date, status)
VALUES
	(1, '2025-06-01', '2025-06-02', 'completed'),
    (1, '2025-06-15', '2025-06-17', 'dispatched'),
    (2, '2025-07-03', '2025-07-05', 'completed');

-- Step 10: Insert order items with FK to orders and products

INSERT INTO Order_items (order_id, product_id, quantity, unit_price)
VALUES
	(1, 1, 1, 2499.99),
	(1, 2, 2, 199.00),
    (2, 4, 1, 999.00),
    (2, 3, 3, 79.50),
    (3, 2, 1, 199.00);

-- Step 11: Query total spending by customer

SELECT Customers.customer_id, Customers.customer_name, SUM(Order_items.quantity + Order_items.unit_price) AS total_spent
FROM Customers
JOIN Orders USING(customer_id)
JOIN Order_items USING(order_id)
GROUP BY Customers.customer_id, Customers.customer_name
ORDER BY total_spent DESC;

-- Step 12: Query most frequently ordered products

SELECT Products.product_name, Products.product_id, COUNT(*) AS times_ordered
FROM Products
JOIN Order_items USING(product_id)
GROUP BY Products.product_id, Products.product_name
ORDER BY times_ordered DESC;

-- Step 13: Count PL orders from July 2025

SELECT COUNT(DISTINCT Orders.order_id) AS total_PL_orders
FROM Orders
JOIN Customers USING(customer_id)
WHERE customer_country = 'PL' AND Orders.order_date BETWEEN DATE '2025-07-01' AND DATE '2025-07-31';

-- Step 14: Show orders with totals > 1000

SELECT Orders.order_id, Orders.order_date, Customers.customer_name, SUM(Order_items.quantity + Order_items.unit_price) AS order_total
FROM Orders
JOIN customers USING(customer_id)
JOIN Order_items USING(order_id)
GROUP BY Orders.order_id, Orders.order_date, Customers.customer_name
HAVING SUM(Order_items.quantity + Order_items.unit_price) > 1000
ORDER BY order_total DESC;

-- Step 15: Create view summarizing orders

CREATE VIEW v_customers_orders AS
SELECT  o.order_id,
        o.order_date,
        o.status,
        SUM(oi.quantity * oi.unit_price) AS order_total
FROM Orders o
JOIN Order_items oi USING(order_id)
GROUP BY o.order_id, o.order_date, o.status;

-- Step 16: Create archive tables

CREATE TABLE orders_archieve(LIKE orders INCLUDING ALL);
CREATE TABLE orders_items_archieve(LIKE order_items INCLUDING ALL);

-- Step 17: Create archiving procedure

CREATE OR REPLACE PROCEDURE archieve_old_orders() AS $$
DECLARE cutoff DATE := CURRENT_DATE - INTERVAL '1 year';
BEGIN
	INSERT INTO order_items_archieve
	SELECT * FROM order_items
	WHERE order_id IN(SELECT order_id FROM Orders WHERE order_date < cutoff);

	DELETE FROM order_items
	WHERE order_id IN(SELECT order_id FROM Orders WHERE order_date < cutoff);

	INSERT INTO orders_archieve
	SELECT * FROM Orders
	WHERE order_date < cutoff;

	DELETE FROM Orders
	WHERE order_date < cutoff;
END;
$$ LANGUAGE plpgsql