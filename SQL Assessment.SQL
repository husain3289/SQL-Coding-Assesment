USE[DBNAME]
GO
/*
--**********************EXPLANATION***************************--
	Created 3 tables
o	Product
o	Product Attributes (PRODUCTID from product table as foreign key)
o	Order (PRODUCTID from product table as foreign key, PRODCUTATTRIBUTESID from Product attributes table as a foreign key)
o	Audit History table to capture the updates made to the product table
o	Entity Type table to define table entities.

	Created an update procedure to update/insert records in product and product attributes table.
	Created a procedure to get all the order item details.
	Created a bulk insert procedure through which we can read the source file and can insert data into one temp table and then by using cursor we can iterate through each row and can decide whether to insert or to update based on certain condition.
*/

--*********************************************************************************************************************
--PRODUCT TABLE
IF OBJECT_ID (N'PRODUCT', N'U') IS NOT NULL 
DROP TABLE PRODUCT
GO
CREATE TABLE PRODUCT
(
	PRODUCTID INT IDENTITY PRIMARY KEY,
	PRODUCTNAME VARCHAR(200),
	INSERTDATE DATETIME,
	INSERTBY VARCHAR(50),
	UPDATEDATE DATETIME,
	UPDATEBY VARCHAR(50)
)
GO
--************************************************************--
--PRODUCT ATTRIBUTES TABLE
IF OBJECT_ID (N'PRODUCTATTRIBUTES', N'U') IS NOT NULL 
DROP TABLE PRODUCTATTRIBUTES
GO
CREATE TABLE PRODUCTATTRIBUTES
(
	PRODUCTATTRIBUTESID INT IDENTITY PRIMARY KEY,
	PRODUCTID INT FOREIGN KEY REFERENCES PRODUCT(PRODUCTID),
	PRODUCTPRICE DECIMAL(17,2),
	SIZE VARCHAR(20),
	COLOR VARCHAR(20),
	INSERTDATE DATETIME,
	INSERTBY VARCHAR(50),
	UPDATEDATE DATETIME,
	UPDATEBY VARCHAR(50)
)
GO
--************************************************************--
--ORDER TABLE
IF OBJECT_ID (N'[ORDER]', N'U') IS NOT NULL 
DROP TABLE [ORDER]
GO

CREATE TABLE [ORDER]
(
	ORDERID INT IDENTITY PRIMARY KEY,
	PRODUCTID INT FOREIGN KEY REFERENCES PRODUCT(PRODUCTID),
	PRODUCTATTRIBUTESID INT FOREIGN KEY REFERENCES PRODUCTATTRIBUTES(PRODUCTATTRIBUTESID),
	QUANTITYORDERED INT,
	INSERTDATE DATETIME,
	INSERTBY VARCHAR(50),
	UPDATEDATE DATETIME,
	UPDATEBY VARCHAR(50)
)
GO
--************************************************************--
--AUDIT HISTORY TABLE (TO TRACK THE UPDATES)
IF OBJECT_ID (N'AUDITHISTORY', N'U') IS NOT NULL 
DROP TABLE AUDITHISTORY
GO
CREATE TABLE AUDITHISTORY
(
	AUDITHISTORYID INT IDENTITY PRIMARY KEY,
	ENTITYID INT,
	ENTITYTYPEID INT,
	OLDVALUE VARCHAR(100),
	NEWVALUE VARCHAR(100),
	INSERTBY VARCHAR(100),
	INSERTDATE DATE
)
--************************************************************--
IF OBJECT_ID (N'ENTITYTYPE', N'U') IS NOT NULL 
DROP TABLE ENTITYTYPE
GO
CREATE TABLE ENTITYTYPE
(
	ENTITYTYPEID INT IDENTITY PRIMARY KEY,
	ENTITYNAME VARCHAR(100),
	INSERTBY VARCHAR(100),
	INSERTDATE DATE
)

INSERT INTO ENTITYTYPE(ENTITYNAME, INSERTBY, INSERTDATE)
VALUES ('PRODUCT', 'HUSAIN', GETDATE()),
		('PRODUCTATTRIBUTES', 'HUSAIN', GETDATE())
--*********************************************************************************************************************
--PROCEDURE WHICH WILL UPDATE AND INSERT RECORDS INTO PRODUCT AND PRODUCT ATTRIBUTES TABLE
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'pBCu_ProductAndPRODUCTATTRIBUTESUpdate')
DROP PROCEDURE pBCu_ProductAndPRODUCTATTRIBUTESUpdate
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE pBCu_ProductAndPRODUCTATTRIBUTESUpdate
(
	@aProductId INT,
	@aPRODUCTATTRIBUTESID INT,
	@aProductName VARCHAR(100),
	@aProductPrice DECIMAL(17,2),
	@aSize VARCHAR(20),
	@aColor VARCHAR(20),
	@aInsertByOrUpdateBy VARCHAR(50),
	@aEntityState INT 
)
AS       
BEGIN  
	
	IF (@aEntityState = 4)--INSERT
	BEGIN

		INSERT INTO PRODUCT (PRODUCTNAME, INSERTBY, INSERTDATE)
		SELECT @aProductName, @aInsertByOrUpdateBy, GETDATE()

		SET @aProductId = SCOPE_IDENTITY()

		INSERT INTO PRODUCTATTRIBUTES (PRODUCTID, PRODUCTPRICE, SIZE, COLOR, UPDATEBY, UPDATEDATE)
		SELECT @aProductId, @aProductPrice, @aSize, @aColor, @aInsertByOrUpdateBy, GETDATE()

	END
	ELSE IF (@aEntityState = 8)--UPDATE
	BEGIN

		UPDATE 
			PRODUCT
		SET
			PRODUCTNAME = @aProductName,
			UPDATEDATE = GETDATE(),
			UPDATEBY = @aInsertByOrUpdateBy
		WHERE 
			PRODUCTID = @aProductId
		
		UPDATE 
			PRODUCTATTRIBUTES
		SET
			PRODUCTPRICE = @aProductPrice,
			SIZE = @aSize,
			COLOR = @aColor,
			UPDATEDATE = GETDATE(),
			UPDATEBY = @aInsertByOrUpdateBy
		WHERE 
			PRODUCTATTRIBUTESID = @aPRODUCTATTRIBUTESID
	END
END
GO
--*********************************************************************************************************************
--Below trigger will capture the updates carried  over PRODUCT table
IF EXISTS (SELECT 1 FROM sys.triggers WHERE Name = 'tBCu_ProductUpdate')
DROP TRIGGER tBCu_ProductUpdate
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[tBCu_ProductUpdate] ON [dbo].[PRODUCT] AFTER UPDATE      
AS      
BEGIN  
       
DECLARE  
	@pProductID INT,
	@pOldProductName VARCHAR(100), @pNewProductName VARCHAR(100),
	@pUpdateBy VARCHAR(100),
	@pEntityTypeID INT = (SELECT ENTITYTYPEID FROM ENTITYTYPE WHERE ENTITYNAME = 'PRODUCT')

 DECLARE Product_Cursor CURSOR FAST_FORWARD LOCAL FOR     
     
   SELECT   
     I.PRODUCTID   
   , I.PRODUCTNAME, D.PRODUCTNAME 
   , I.UPDATEBY   
  FROM 
	INSERTED I   
    INNER JOIN DELETED D ON I.PRODUCTID = D.PRODUCTID  

  OPEN Product_Cursor    
     
 FETCH NEXT FROM Product_Cursor   
 INTO  
     @pProductID   
   , @pOldProductName, @pNewProductName
   , @pUpdateBy   
  
     
WHILE @@FETCH_STATUS = 0    
BEGIN    
     
	IF UPDATE(PRODUCTNAME) AND @pOldProductName <> @pNewProductName  
	BEGIN  
		INSERT INTO AUDITHISTORY (ENTITYID, ENTITYTYPEID, OLDVALUE, NEWVALUE, INSERTDATE, INSERTBY)
		SELECT @pProductID, @pEntityTypeID, @pOldProductName, @pNewProductName, GETDATE(), @pUpdateBy
	END  
  

	FETCH NEXT FROM Product_Cursor   
	INTO  
		@pProductID   
		, @pOldProductName, @pNewProductName
		, @pUpdateBy  
  
	END    

	CLOSE Product_Cursor    
	DEALLOCATE Product_Cursor    
  
END  
GO
--*********************************************************************************************************************
--Below trigger will capture the updates carried  over PRODUCT table
IF EXISTS (SELECT 1 FROM sys.triggers WHERE Name = 'tBCu_PRODUCTATTRIBUTES')
DROP TRIGGER tBCu_PRODUCTATTRIBUTES
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[tBCu_PRODUCTATTRIBUTES] ON [dbo].[PRODUCTATTRIBUTES] AFTER UPDATE      
AS      
BEGIN  
       
DECLARE  
	@pPRODUCTATTRIBUTESID INT,
	@pOldSize VARCHAR(100), @pNewSize VARCHAR(100),
	@pOldColor VARCHAR(100), @pNewColor VARCHAR(100),
	@pOldProductPrice VARCHAR(100), @pNewProductPrice VARCHAR(100),
	@pUpdateBy VARCHAR(100),
	@pEntityTypeID INT = (SELECT ENTITYTYPEID FROM ENTITYTYPE WHERE ENTITYNAME = 'PRODUCTATTRIBUTES')

 DECLARE PRODUCTATTRIBUTES_Cursor CURSOR FAST_FORWARD LOCAL FOR     
     
   SELECT   
     I.PRODUCTATTRIBUTESID   
   , I.SIZE, D.SIZE 
   , I.COLOR, D.COLOR
   , I.PRODUCTPRICE, D.PRODUCTPRICE 
   , I.UPDATEBY   
  FROM 
	INSERTED I   
    INNER JOIN DELETED D ON I.PRODUCTID = D.PRODUCTID  

  OPEN PRODUCTATTRIBUTES_Cursor    
     
 FETCH NEXT FROM PRODUCTATTRIBUTES_Cursor   
 INTO  
     @pPRODUCTATTRIBUTESID,
	@pOldSize, @pNewSize ,
	@pOldColor , @pNewColor ,
	@pOldProductPrice , @pNewProductPrice ,
	@pUpdateBy  
  
     
WHILE @@FETCH_STATUS = 0    
BEGIN    
     
	IF UPDATE(SIZE) AND @pOldSize <> @pNewSize  
	BEGIN  
		INSERT INTO AUDITHISTORY (ENTITYID, ENTITYTYPEID, OLDVALUE, NEWVALUE, INSERTDATE, INSERTBY)
		SELECT @pPRODUCTATTRIBUTESID, @pEntityTypeID, @pOldSize, @pNewSize, GETDATE(), @pUpdateBy
	END  
	IF UPDATE(COLOR) AND @pOldColor <> @pNewColor  
	BEGIN  
		INSERT INTO AUDITHISTORY (ENTITYID, ENTITYTYPEID, OLDVALUE, NEWVALUE, INSERTDATE, INSERTBY)
		SELECT @pPRODUCTATTRIBUTESID, @pEntityTypeID, @pOldColor, @pNewColor, GETDATE(), @pUpdateBy
	END 
	IF UPDATE(PRODUCTPRICE) AND @pOldProductPrice <> @pNewProductPrice  
	BEGIN  
		INSERT INTO AUDITHISTORY (ENTITYID, ENTITYTYPEID, OLDVALUE, NEWVALUE, INSERTDATE, INSERTBY)
		SELECT @pPRODUCTATTRIBUTESID, @pEntityTypeID, @pOldProductPrice, @pNewProductPrice, GETDATE(), @pUpdateBy
	END 
  

	FETCH NEXT FROM PRODUCTATTRIBUTES_Cursor   
	INTO    
     @pPRODUCTATTRIBUTESID,
	@pOldSize, @pNewSize ,
	@pOldColor , @pNewColor ,
	@pOldProductPrice , @pNewProductPrice ,
	@pUpdateBy  
  
  
END    

	CLOSE PRODUCTATTRIBUTES_Cursor    
	DEALLOCATE PRODUCTATTRIBUTES_Cursor    
  
END  
GO
--*********************************************************************************************************************
--PROCEDURE TO VIEW ORDER ITEM DETAILS
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'pBCg_OrderItemDetails')
DROP PROCEDURE pBCg_OrderItemDetails
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE pBCg_OrderItemDetails
AS       
BEGIN  
	
	SELECT 
		P.PRODUCTNAME AS 'Product Name', 
		PR.PRODUCTPRICE AS 'Price', 
		O.QUANTITYORDERED AS 'Ordered Quantity', 
		PR.SIZE AS 'Size', 
		PR.COLOR AS 'Color', 
		O.INSERTDATE AS	'Order Created Date'
	FROM
	[ORDER] O WITH(NOLOCK)
	INNER JOIN PRODUCT P WITH(NOLOCK) ON P.PRODUCTID = O.PRODUCTID
	INNER JOIN PRODUCTPROPERTIES PR WITH(NOLOCK) ON PR.PRODUCTID  = P.PRODUCTID AND O.PRODUCTATTRIBUTESID = PR.PRODUCTATTRIBUTESID
	
END
GO
--*********************************************************************************************************************
--PROCEDURE TO VIEW ORDER ITEM DETAILS
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'pBCu_ProductBulkUpdate')
DROP PROCEDURE pBCu_ProductBulkUpdate
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE pBCu_ProductBulkUpdate
AS       
BEGIN 
	DECLARE @pProductName VARCHAR(100), @PSIZE VARCHAR(20), @PCOLOR VARCHAR(20), @PPRODUCTPRICE DECIMAL(17,2), @pProductID INT, @PProductAttributesID INT

	BULK INSERT #TempProduct
	FROM 'C:\NewProduct.csv'
	WITH
	(
	  FIELDTERMINATOR = ',',
	  ROWTERMINATOR = '\n',
	  ROWS_PER_BATCH = 10000,
	  FIRSTROW = 2,
	  TABLOCK
	)

	DECLARE BULKINSERT_CURSOR CURSOR FAST_FORWARD LOCAL FOR     
     
	   SELECT   
		PRODUCTNAME, SIZE, COLOR, PRODUCTPRICE
	  FROM 
		#TEMPPRODUCT

	  OPEN BULKINSERT_CURSOR    
     
	 FETCH NEXT FROM BULKINSERT_CURSOR   
	 INTO  
		 @pProductName,
		@PSIZE, 
		@PCOLOR,
		@PPRODUCTPRICE
     
	WHILE @@FETCH_STATUS = 0    
	BEGIN    
		IF NOT EXISTS (SELECT 1 FROM PRODUCT P 
			INNER JOIN PRODUCTATTRIBUTES AR ON AR.PRODUCTID = P.PRODUCTID
			WHERE P.PRODUCTNAME = @pProductName
									AND AR.SIZE = @PSIZE
									AND AR.COLOR = @PCOLOR)
		BEGIN

			INSERT INTO PRODUCT (PRODUCTNAME, INSERTBY, INSERTDATE)
			SELECT @pProductName, 'BULK INSERT', GETDATE() 

			SET @pProductID = SCOPE_IDENTITY()

			INSERT INTO PRODUCTATTRIBUTES (PRODUCTID, PRODUCTPRICE, SIZE, COLOR, INSERTBY, UPDATEDATE)
			SELECT @pProductID, @PPRODUCTPRICE, @PSIZE, @PCOLOR, 'BULK INSERT', GETDATE()

		END
		ELSE
		BEGIN
		
			SELECT @pProductID = P.PRODUCTID, @PProductAttributesID = AR.PRODUCTATTRIBUTESID FROM PRODUCT P 
			INNER JOIN PRODUCTATTRIBUTES AR ON AR.PRODUCTID = P.PRODUCTID
			WHERE P.PRODUCTNAME = @pProductName
									AND AR.SIZE = @PSIZE
									AND AR.COLOR = @PCOLOR
			UPDATE 
				PRODUCT
			SET
				PRODUCTNAME = @pProductName,
				UPDATEDATE = GETDATE(),
				UPDATEBY = 'BULK INSERT'
			WHERE 
				PRODUCTID = @pProductID
		
			UPDATE 
				PRODUCTATTRIBUTES
			SET
				PRODUCTPRICE = @PPRODUCTPRICE,
				SIZE = @PSIZE,
				COLOR = @PCOLOR,
				UPDATEDATE = GETDATE(),
				UPDATEBY = 'BULK INSERT'
			WHERE 
				PRODUCTATTRIBUTESID = @PProductAttributesID 

		END
		FETCH NEXT FROM BULKINSERT_CURSOR   
	 INTO  
		 @pProductName,
		@PSIZE, 
		@PCOLOR,
		@PPRODUCTPRICE
	END
	CLOSE BULKINSERT_CURSOR    
	DEALLOCATE BULKINSERT_CURSOR   
END