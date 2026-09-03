
-- ================================================================
--  MODULO 2 - SEZIONE 1 | Subquery, CTE e Viste
-- ================================================================

USE AdventureWorks;
GO


-- ==============================================================================
--   1. SUBQUERY
-- ==============================================================================


-- 1.1  SUBQUERY SCALARE NEL WHERE
-- Scalare = produce un singolo valore (una riga, una colonna). Può essere usata in WHERE, SELECT, HAVING.
SELECT  p.Name,
        p.ListPrice
FROM    Production.Product AS p
WHERE   p.ListPrice > (
            SELECT  AVG(ListPrice)
            FROM    Production.Product
            WHERE   ListPrice > 0          -- esclude i prodotti gratuiti dalla media
        )
ORDER BY p.ListPrice DESC;
GO


-- 1.2  SUBQUERY SCALARE NELLA SELECT
-- Aggiunge una colonna calcolata per ogni riga. Attenzione: se la subquery e'
-- correlata (come qui) viene valutata per ogni riga -> meglio usare un JOIN/CTE
-- quando il volume dati può essere grosso.
SELECT  p.Name,
        p.ListPrice,
        (
            SELECT  COUNT(*)
            FROM    Sales.SalesOrderDetail AS sod
            WHERE   sod.ProductID = p.ProductID
        ) AS NumeroOrdini
FROM    Production.Product AS p
WHERE   p.ListPrice > 0
ORDER BY NumeroOrdini DESC;
GO


-- 1.3  SUBQUERY MULTI-RIGA con IN 
-- La subquery restituisce un SET di valori. Si usa con operatori come la IN/NOT IN, EXISTS/NOT EXISTS, ANY/ALL.
SELECT  pc.Name AS Categoria
FROM    Production.ProductCategory AS pc
WHERE   pc.ProductCategoryID IN (
            SELECT  ps.ProductCategoryID
            FROM    Production.ProductSubcategory AS ps
            JOIN    Production.Product            AS p
                ON  p.ProductSubcategoryID = ps.ProductSubcategoryID
            WHERE   p.ListPrice > 500
        );
GO


--  1.4  TRAPPOLA: NOT IN con valori NULL
--  Se la subquery restituisce anche un solo NULL, NOT IN restituisce SEMPRE 0 righe 
--  La soluzione robusta e' NOT EXISTS.

-- Setup dimostrativo: tabella con un NULL
IF OBJECT_ID('tempdb..#Categorie') IS NOT NULL DROP TABLE #Categorie;
CREATE TABLE #Categorie (CategoriaID INT NULL);
INSERT INTO #Categorie (CategoriaID) VALUES (1), (2), (NULL);   -- nota il NULL

-- ✗ PERICOLOSO: a causa del NULL, questa restituisce 0 righe
SELECT  pc.ProductCategoryID, pc.Name
FROM    Production.ProductCategory AS pc
WHERE   pc.ProductCategoryID NOT IN (SELECT CategoriaID FROM #Categorie);

-- ✓ SICURO: NOT EXISTS gestisce correttamente i NULL
SELECT  pc.ProductCategoryID, pc.Name
FROM    Production.ProductCategory AS pc
WHERE   NOT EXISTS (
            SELECT  1
            FROM    #Categorie AS c
            WHERE   c.CategoriaID = pc.ProductCategoryID
        );

DROP TABLE #Categorie;
GO

--  1.5  TABELLA INLINE (subquery nel FROM)
--  Si comporta come una tabella virtuale. 
SELECT  p.Name,
        sub.TotOrdini
FROM    Production.Product AS p
JOIN    (   -- subquery nel FROM: tabella derivata
            SELECT  ProductID,
                    SUM(OrderQty) AS TotOrdini
            FROM    Sales.SalesOrderDetail
            GROUP BY ProductID
        ) AS sub
    ON  sub.ProductID = p.ProductID
ORDER BY sub.TotOrdini DESC;
GO

--  1.6  SUBQUERY CORRELATA: EXISTS vs IN
--  La subquery correlata fa riferimento all'alias esterno (c.CustomerID).
--  EXISTS cortocircuita al primo match -> preferibile a IN su set grandi.

-- ✓ PREFERIRE: EXISTS cortocircuita al primo match
SELECT  c.CustomerID,
        c.AccountNumber
FROM    Sales.Customer AS c
WHERE   EXISTS (
            SELECT  1
            FROM    Sales.SalesOrderHeader AS soh
            WHERE   soh.CustomerID = c.CustomerID    -- riferimento correlato
            AND     soh.TotalDue   > 1000
        );
GO

-- ✗ EVITARE su set grandi: IN valuta l'intero set della subquery
SELECT  c.CustomerID,
        c.AccountNumber
FROM    Sales.Customer AS c
WHERE   c.CustomerID IN (
            SELECT  CustomerID
            FROM    Sales.SalesOrderHeader
            WHERE   TotalDue > 1000
        );
GO





-- ==============================================================================
--  2. PERFORMANCE DELLE SUBQUERY
--  Eseguire con "Include Actual Execution Plan" attivo e leggere
--  l'output di SET STATISTICS IO ON nella scheda Messages.
-- ==============================================================================


--  2.1  L'OPTIMIZER PUO' RISCRIVERE "IN" IN UNA SEMI-JOIN
--  Le due query seguenti producono spesso lo STESSO piano di esecuzione:
--  SQL Server converte la subquery IN in una semi-join.
--  Confrontare i due piani per verificarlo.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Versione con IN
SELECT  c.CustomerID
FROM    Sales.Customer AS c
WHERE   c.CustomerID IN (
            SELECT  CustomerID
            FROM    Sales.SalesOrderHeader
        );

-- Versione con JOIN esplicito (DISTINCT per equivalenza logica)
SELECT  DISTINCT c.CustomerID
FROM    Sales.Customer AS c
JOIN    Sales.SalesOrderHeader AS soh
    ON  soh.CustomerID = c.CustomerID;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


--  2.2  CORRELATA SENZA INDICE vs CON INDICE
--  Una subquery correlata che filtra su una colonna non indicizzata causa
--  una scan per ogni riga esterna. Un indice trasforma il costo.
SET STATISTICS IO ON;

-- Correlata: per ogni cliente conta gli ordini sopra una certa soglia
SELECT  c.CustomerID,
        (
            SELECT  COUNT(*)
            FROM    Sales.SalesOrderHeader AS soh
            WHERE   soh.CustomerID = c.CustomerID
            AND     soh.TotalDue   > 1000
        ) AS OrdiniRilevanti
FROM    Sales.Customer AS c
ORDER BY OrdiniRilevanti DESC;

-- Indice suggerito per ridurre le letture
CREATE NONCLUSTERED INDEX IX_SOH_Customer_CustomerID
    ON Sales.SalesOrderHeader (CustomerID);

SELECT  c.CustomerID,
        (
            SELECT  COUNT(*)
            FROM    Sales.SalesOrderHeader AS soh
            WHERE   soh.CustomerID = c.CustomerID
            AND     soh.TotalDue   > 1000
        ) AS OrdiniRilevanti
FROM    Sales.Customer AS c
ORDER BY OrdiniRilevanti DESC;

-- Indice di copertura suggerito per ridurre le letture
CREATE NONCLUSTERED INDEX IX_SOH_Customer_TotalDue
    ON Sales.SalesOrderHeader (CustomerID, TotalDue);

SELECT  c.CustomerID,
        (
            SELECT  COUNT(*)
            FROM    Sales.SalesOrderHeader AS soh
            WHERE   soh.CustomerID = c.CustomerID
            AND     soh.TotalDue   > 1000
        ) AS OrdiniRilevanti
FROM    Sales.Customer AS c
ORDER BY OrdiniRilevanti DESC;

DROP INDEX IX_SOH_Customer_TotalDue ON Sales.SalesOrderHeader;
DROP INDEX IX_SOH_Customer_CustomerID ON Sales.SalesOrderHeader;

SET STATISTICS IO OFF;
GO


-- ==============================================================================
-- 3. CTE — COMMON TABLE EXPRESSION
-- ==============================================================================


--  3.1  CTE SEMPLICE
--  Definita con WITH ... AS(). Esiste solo per la query corrente.
--  Nota: filtro sargable sulle date (>= AND <) invece di YEAR(OrderDate).
WITH OrdiniImportoAlto AS (
    SELECT  CustomerID,
            SUM(TotalDue) AS TotaleCliente
    FROM    Sales.SalesOrderHeader
    WHERE   OrderDate >= '2013-01-01'
    AND     OrderDate <  '2014-01-01'
    GROUP BY CustomerID
    HAVING  SUM(TotalDue) > 1000
)
SELECT  c.AccountNumber,
        oa.TotaleCliente
FROM    OrdiniImportoAlto AS oa
JOIN    Sales.Customer AS c
    ON  c.CustomerID = oa.CustomerID
ORDER BY oa.TotaleCliente DESC;
GO


--  3.2  CTE MULTIPLE
--  Piu' CTE separate da virgola. Ogni CTE puo' referenziare le precedenti.
--  Decompone una logica complessa in passi.
WITH
-- Passo 1: vendite aggregate per prodotto
VenditePerProdotto AS (
    SELECT  ProductID,
            SUM(OrderQty) AS TotQty
    FROM    Sales.SalesOrderDetail
    GROUP BY ProductID
),
-- Passo 2: media delle vendite (usa la CTE precedente)
MediaVendite AS (
    SELECT  AVG(TotQty) AS MediaQty
    FROM    VenditePerProdotto
)
-- Query finale: prodotti sopra la media
SELECT  p.Name,
        vpp.TotQty
FROM    Production.Product       AS p
JOIN    VenditePerProdotto       AS vpp  ON vpp.ProductID = p.ProductID
CROSS JOIN MediaVendite          AS mv
WHERE   vpp.TotQty > mv.MediaQty
ORDER BY vpp.TotQty DESC;
GO


--  3.3  CTE RICORSIVA — esplosione di una distinta base
--  Tre elementi: anchor member (radice) + recursive member + UNION ALL.
--  Il recursive member e' un semplice JOIN sulla CTE stessa:
--  il componente padre di un livello (ComponentID) diventa l'assieme da esplodere
--  al livello successivo (ProductAssemblyID). 
--  OPTION (MAXRECURSION N) limita la profondita' (default 100; 0 = infinito).

WITH Distinta AS (
    -- Anchor: componenti diretti del prodotto-assieme 800
    SELECT  bom.ProductAssemblyID,
            bom.ComponentID,
            bom.PerAssemblyQty,
            0 AS Livello
    FROM    Production.BillOfMaterials AS bom
    WHERE   bom.ProductAssemblyID = 800
    AND     bom.EndDate IS NULL

    UNION ALL

    -- Recursive member: sotto-componenti del livello precedente
    -- (il ComponentID padre diventa il ProductAssemblyID figlio)
    SELECT  b.ProductAssemblyID,
            b.ComponentID,
            b.PerAssemblyQty,
            d.Livello + 1
    FROM    Production.BillOfMaterials AS b
    JOIN    Distinta                   AS d -- recursive member: join sulla CTE stessa
        ON  b.ProductAssemblyID = d.ComponentID
    WHERE   b.EndDate IS NULL
)
SELECT  d.Livello,
        d.ProductAssemblyID,
        d.ComponentID,
        p.Name AS Componente,
        d.PerAssemblyQty
FROM    Distinta AS d
JOIN    Production.Product AS p
    ON  p.ProductID = d.ComponentID
ORDER BY d.Livello, d.ComponentID
OPTION (MAXRECURSION 20);
GO


/*==============================================================================
  4. PERFORMANCE DELLE CTE
==============================================================================*/


--  4.1  LA CTE NON E' MATERIALIZZATA
--  Una CTE referenziata piu' volte viene RIESEGUITA ad ogni riferimento: SQL
-- Server la espande inline, non la calcola una volta sola. 
SET STATISTICS IO ON;

WITH OrdinatoPerVenditore AS (
    SELECT  poh.VendorID,
            SUM(pod.LineTotal) AS TotOrdinato
    FROM    Purchasing.PurchaseOrderHeader AS poh
    JOIN    Purchasing.PurchaseOrderDetail AS pod
        ON  pod.PurchaseOrderID = poh.PurchaseOrderID
    GROUP BY poh.VendorID
)
SELECT  opv.VendorID,
        opv.TotOrdinato
FROM    OrdinatoPerVenditore AS opv
WHERE   opv.TotOrdinato > (SELECT AVG(TotOrdinato) FROM OrdinatoPerVenditore)
ORDER BY opv.TotOrdinato DESC;

SET STATISTICS IO OFF;
GO


  -- 4.2  ALTERNATIVA: TABELLA TEMPORANEA
  -- Se l'aggregazione e' costosa e serve piu' volte, materializzarla una sola
  -- volta in una #TempTable evita il ricalcolo
SET STATISTICS IO ON;

IF OBJECT_ID('tempdb..#OrdinatoPerVenditore') IS NOT NULL
    DROP TABLE #OrdinatoPerVenditore;

-- Aggregazione calcolata UNA sola volta
SELECT  poh.VendorID,
        SUM(pod.LineTotal) AS TotOrdinato
INTO    #OrdinatoPerVenditore
FROM    Purchasing.PurchaseOrderHeader AS poh
JOIN    Purchasing.PurchaseOrderDetail AS pod
    ON  pod.PurchaseOrderID = poh.PurchaseOrderID
GROUP BY poh.VendorID;

-- Riferimenti multipli: ora leggono la temp, non ricalcolano
SELECT  t.VendorID,
        t.TotOrdinato
FROM    #OrdinatoPerVenditore AS t
WHERE   t.TotOrdinato > (SELECT AVG(TotOrdinato) FROM #OrdinatoPerVenditore)
ORDER BY t.TotOrdinato DESC;

DROP TABLE #OrdinatoPerVenditore;

SET STATISTICS IO OFF;
GO


/*==============================================================================
  5. VISTE
==============================================================================*/


-- 5.1  CREATE VIEW standard
-- Una query salvata con un nome. Si interroga come una tabella.
IF OBJECT_ID('Production.vProdottiAttivi', 'V') IS NOT NULL
    DROP VIEW Production.vProdottiAttivi;
GO

CREATE VIEW Production.vProdottiAttivi
AS
SELECT  p.ProductID,
        p.Name        AS Prodotto,
        p.ListPrice   AS Prezzo,
        pc.Name       AS Categoria,
        ps.Name       AS Sottocategoria
FROM    Production.Product             AS p
JOIN    Production.ProductSubcategory  AS ps
    ON  ps.ProductSubcategoryID = p.ProductSubcategoryID
JOIN    Production.ProductCategory     AS pc
    ON  pc.ProductCategoryID    = ps.ProductCategoryID
WHERE   p.DiscontinuedDate IS NULL;
GO

-- Uso: identico a una tabella. L'ORDER BY va QUI, non nella definizione.
SELECT  Prodotto, Prezzo
FROM    Production.vProdottiAttivi
WHERE   Categoria = 'Bikes'
ORDER BY Prezzo DESC;
GO


  -- 5.2  VISTA con SCHEMABINDING
  -- SCHEMABINDING lega la vista allo schema delle tabelle base: protegge da
  -- ALTER/DROP accidentali ed e' PREREQUISITO per la vista indicizzata (5.3).
  -- Richiede nomi a due parti (schema.tabella) per tutti gli oggetti.
IF OBJECT_ID('Sales.vVenditePerProdotto', 'V') IS NOT NULL
    DROP VIEW Sales.vVenditePerProdotto;
GO

CREATE VIEW Sales.vVenditePerProdotto
WITH SCHEMABINDING
AS
SELECT  sd.ProductID,
        COUNT_BIG(*)       AS NumRighe,        -- obbligatorio con GROUP BY per indexed view
        SUM(sd.OrderQty)   AS TotQty,
        SUM(sd.LineTotal)  AS TotFatturato
FROM    Sales.SalesOrderDetail AS sd
GROUP BY sd.ProductID;
GO


  -- 5.3  INDEXED VIEW (vista materializzata)
  -- Aggiungendo un CLUSTERED INDEX UNIVOCO la vista viene materializzata su disco
  -- e mantenuta automaticamente ad ogni DML sulle tabelle base.
CREATE UNIQUE CLUSTERED INDEX IX_vVenditePerProdotto
    ON Sales.vVenditePerProdotto (ProductID);
GO

-- Ora la lettura attinge direttamente dall'indice materializzato
SELECT  ProductID, TotQty, TotFatturato
FROM    Sales.vVenditePerProdotto with (NOEXPAND)  
WHERE   TotFatturato > 100000
ORDER BY TotFatturato DESC;
GO

-- Pulizia (rimuovere indice e viste create in questo file)
DROP INDEX IX_vVenditePerProdotto ON Sales.vVenditePerProdotto;
DROP VIEW Sales.vVenditePerProdotto;
DROP VIEW Production.vProdottiAttivi;
GO


/*==============================================================================
  6. REFACTORING — da subquery annidata a CTE leggibile
  Stesso risultato, leggibilita' molto diversa. Confrontare anche i piani:
  spesso sono identici (la CTE non e' materializzata).
==============================================================================*/

-- ✗ PRIMA: subquery annidate, difficile da leggere: la stessa aggregazione ripetuta due volte
SELECT  v.Name AS Fornitore, sub.TotOrdinato
FROM    Purchasing.Vendor AS v
JOIN    (
            SELECT  poh.VendorID,
                    SUM(pod.LineTotal) AS TotOrdinato
            FROM    Purchasing.PurchaseOrderHeader AS poh
            JOIN    Purchasing.PurchaseOrderDetail AS pod
                ON  pod.PurchaseOrderID = poh.PurchaseOrderID
            GROUP BY poh.VendorID
        ) AS sub
    ON  sub.VendorID = v.BusinessEntityID
WHERE   sub.TotOrdinato > (
            SELECT  AVG(TotOrdinato)
            FROM    (
                        SELECT  SUM(pod.LineTotal) AS TotOrdinato
                        FROM    Purchasing.PurchaseOrderHeader AS poh
                        JOIN    Purchasing.PurchaseOrderDetail AS pod
                            ON  pod.PurchaseOrderID = poh.PurchaseOrderID
                        GROUP BY poh.VendorID
                    ) AS x
        )
ORDER BY sub.TotOrdinato DESC;

-- ✓ L'aggregazione è definita UNA volta e riusata
WITH OrdinatoPerFornitore AS (
    SELECT  poh.VendorID,
            SUM(pod.LineTotal) AS TotOrdinato
    FROM    Purchasing.PurchaseOrderHeader AS poh
    JOIN    Purchasing.PurchaseOrderDetail AS pod
        ON  pod.PurchaseOrderID = poh.PurchaseOrderID
    GROUP BY poh.VendorID
)
SELECT  v.Name AS Fornitore,
        opf.TotOrdinato
FROM    OrdinatoPerFornitore AS opf
JOIN    Purchasing.Vendor    AS v
    ON  v.BusinessEntityID = opf.VendorID
WHERE   opf.TotOrdinato > (SELECT AVG(TotOrdinato) FROM OrdinatoPerFornitore)
ORDER BY opf.TotOrdinato DESC;
