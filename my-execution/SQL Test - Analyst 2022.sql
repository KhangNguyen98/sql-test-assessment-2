USE Class3_Descriptive_Analytics
GO

--PART 1
	--1. Show list of transactions occurring in February 2018 with SHIPPED status
		SELECT * 
		FROM Transactions 
		WHERE YEAR(transaction_date) = 2018 AND 
			  MONTH(transaction_date) = 2 AND 
			  status = 'SHIPPED'

	--2. Show list of transactions occurring from midnight to 9 AM
		SELECT * 
		FROM transactions 
		WHERE CAST(transaction_date AS TIME) BETWEEN '00:00:00' AND '9:00:00'

	--3. Show a list of only the last transactions from each vendor
		SELECT vendor, transaction_date
		FROM 
		(
			SELECT vendor, transaction_date, DENSE_RANK() OVER (PARTITION BY vendor ORDER BY transaction_date DESC) AS Rnk  
			FROM transactions  
		) Tmp
		WHERE Rnk = 1

	--4. Show a list of only the second last transactions from each vendor
		SELECT vendor, transaction_date
		FROM 
		(
			SELECT vendor, transaction_date, DENSE_RANK() OVER (PARTITION BY vendor ORDER BY transaction_date DESC) AS Rnk  
			FROM transactions  
		) Tmp
		WHERE Rnk = 2

	--5. Count the transactions from each vendor with the status CANCELLED per day
		SELECT vendor, CONVERT(DATE, transaction_date) AS 'date', COUNT(order_id) AS total_transaction_per_day 
		FROM transactions 
		WHERE status = 'CANCELLED' 
		GROUP BY vendor, CONVERT(DATE, transaction_date)

	--6. Show a list of customers who made more than 1 SHIPPED purchases
		SELECT customer_id, status, COUNT(status) AS total_purchases 
		FROM transactions  
		WHERE status = 'SHIPPED' 
		GROUP BY customer_id, status 
		HAVING COUNT(status) > 1

	--7. Show the total transactions (volume) and category of each vendors by following these criteria:
		--a. Superb: More than 2 SHIPPED and 0 CANCELLED transactions
			SELECT B.* INTO #Superb 
			FROM
			(
				SELECT DISTINCT vendor 
				FROM transactions 
				WHERE vendor NOT IN 
				(
					SELECT DISTINCT vendor FROM transactions WHERE status = 'CANCELLED'
				) 
			) A JOIN
			(
				SELECT vendor, status, COUNT(status) AS total_transactions
				FROM transactions WHERE status = 'SHIPPED' GROUP BY vendor, status HAVING COUNT(status) >= 2
			) B
			ON A.vendor = B.vendor

		--b. Good: More than 2 SHIPPED and 1 or more CANCELLED transactions
			SELECT vendor, COUNT(order_id) AS total_transactions INTO #Good 
			FROM transactions
			WHERE vendor IN 
			(
				SELECT vendor AS total_transactions 
				FROM
				(
					SELECT vendor, status, COUNT(status) AS total_each_transaction_status  
					FROM transactions 
					WHERE status = 'SHIPPED' 
					GROUP BY vendor, status 
					HAVING COUNT(status) >= 2
				) A
				WHERE vendor NOT IN (SELECT vendor FROM #Superb)
			)
			GROUP BY vendor

		--c. Normal: other than Superb and Good criteria
			SELECT vendor, COUNT(order_id) AS total_transactions INTO #Normal
			FROM transactions  
			WHERE vendor NOT IN (SELECT vendor FROM #Superb) AND 
				  vendor NOT IN (SELECT vendor FROM #Good)
			GROUP BY vendor

		-- Order  the  vendors  by  the  best  category  (Superb,  Good,  Normal),  then  by  the  biggest transaction volume
			SELECT vendor, total_transactions, 1 AS Rnk FROM #Superb
			UNION
			SELECT vendor, total_transactions, 2 AS Rnk FROM #Good
			UNION
			SELECT vendor, total_transactions, 3 AS Rnk FROM #Normal
			ORDER BY Rnk, total_transactions DESC

	--8. Group the transactions by hour of transaction_date
		SELECT FORMAT(DATEPART(HOUR, transaction_date), '00')  AS 'Hour of the Day',
			   COUNT(id) AS 'Total Transaction' 
		FROM transactions 
		GROUP BY DATEPART(HOUR, transaction_date)

	--9. Group the transactions by day and statuses as the example below
		SELECT CONVERT(DATE, transaction_date) AS 'Date',
			   SUM(CASE WHEN status = 'SHIPPED' THEN 1 ELSE 0 END) AS 'SHIPPED',
			   SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) AS 'CANCELLED',
			   SUM(CASE WHEN status != 'SHIPPED' AND status != 'CANCELLED'  THEN 1 ELSE 0 END) AS 'PROCESSING'
		FROM transactions
		GROUP BY CONVERT(DATE, transaction_date)

	--10. Calculate the average, minimum and maximum of days interval of each transaction (how many days from one transaction to the next)
		SELECT STR(ROUND(AVG(interval), 2)) + ' day(s)' AS 'Average Interval', 
			   STR(MIN(interval)) + ' day(s)' AS 'Minium Interval', 
			   STR(MAX(interval) ) + ' day(s)' AS 'Maximum Interval' 
		FROM
		(
			SELECT  DATEDIFF(DAY, transaction_date, LEAD(transaction_date) OVER (ORDER BY transaction_date ASC)) AS 'Interval' FROM transactions
		) Tmp

--PART 2 
	--1. Show  the  sum  of  the  total  value  of  the  products  shipped  along  with  the  Distributor Commissions
		SELECT product_name AS 'Product Name',
			   quantity * price AS 'Value (quantity x price)',
			   CASE WHEN SUM(quantity)  <= 100 THEN 2 * SUM(quantity * price) / 100
					ELSE  4 * SUM(quantity * price) / 100
			   END AS 'Distributor Comission'
		FROM transaction_details
	GROUP BY product_name

	--2. Show total quantity of “Indomie (all variant)” shipped within February 2018
		SELECT SUM(quantity) AS 'total_quantity'
		FROM transaction_details
		WHERE product_name LIKE 'Indomie%' AND 
			  trx_id IN 
			  (
				SELECT Id
				FROM transactions
				WHERE status = 'SHIPPED' AND 
				DATEPART(MONTH, transaction_date) = 2 AND 
				DATEPART(YEAR, transaction_date) = 2018	
			  )

	--3. For each product, show the ID of the last transaction which contained that particular product
		SELECT product_name AS 'Product Name', MAX(trx_id) AS 'LAST Transaction ID' 
		FROM transaction_details 
		GROUP BY product_name

