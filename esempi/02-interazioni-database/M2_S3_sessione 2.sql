
-- ==================================================================
-- 4 - Fenomeni di concorrenza: DIRTY READ (procedura a DUE sessioni)

-- Apri prima sessione 1 in altra finestra
-- ==================================================================
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- Legge il valore 'sporco' modificato ma non ancora committato
SELECT ProductID, ListPrice AS prezzo_sporco
FROM   Production.Product
WHERE  ProductID = 1;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;  -- ripristina il default


-- ==================================================================
-- 4.1 - Fenomeni di concorrenza:  REPEATABLE READ (procedura a DUE sessioni)

-- Apri prima sessione 1 in altra finestra
-- ==================================================================

UPDATE Production.Product
SET    ListPrice = ListPrice + 500
WHERE  ProductID = 1;


-- ==================================================================
-- 4.2 - Fenomeni di concorrenza: PHANTOM READ (procedura a DUE sessioni)

-- Apri prima sessione 1 in altra finestra
-- ==================================================================

INSERT INTO Production.Product
      (Name, ProductNumber, SafetyStockLevel, ReorderPoint,
       StandardCost, ListPrice, DaysToManufacture, SellStartDate)
VALUES (N'Phantom Widget', N'PH-0001', 100, 75, 50.00, 150.00, 1, GETDATE());

DELETE FROM Production.Product WHERE ProductNumber = N'PH-0001';


-- ==================================================================
-- 4.3 - Fenomeni di concorrenza: LOST UPDATE (procedura a DUE sessioni)

-- Apri prima sessione 1 in altra finestra
-- ==================================================================
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;

SELECT ListPrice AS PrezzoLetto
INTO   #s2
FROM   Production.Product WHERE ProductID = 1;   -- legge 1000.00

UPDATE Production.Product
SET    ListPrice = (SELECT PrezzoLetto FROM #s2) + 50
WHERE  ProductID = 1;

COMMIT TRANSACTION;      -- ora vale 1050.00
DROP TABLE #s2;