-- ============================================================================
-- MODULO 1 – SEZIONE 2: Joins e operazioni insiemistiche
-- Corso SQL Server – Luca Murzio
-- Database: AdventureWorks 2022
-- ============================================================================

-- ============================================================================
-- 1. INNER JOIN – Solo le righe che corrispondono in entrambe le tabelle
-- ============================================================================

-- Esempio 1.1: Prodotti con la loro sottocategoria
SELECT 
    p.ProductID,
    p.Name            AS Prodotto,
    p.ListPrice       AS PrezzoListino,
    ps.Name           AS Sottocategoria
FROM Production.Product p
INNER JOIN Production.ProductSubcategory ps
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
WHERE p.ListPrice > 0
ORDER BY ps.Name, p.Name;
GO

-- Esempio 1.2: JOIN su più tabelle – Prodotto → Sottocategoria → Categoria
SELECT 
    p.Name            AS Prodotto,
    ps.Name           AS Sottocategoria,
    pc.Name           AS Categoria,
    p.ListPrice       AS PrezzoListino
FROM Production.Product p
INNER JOIN Production.ProductSubcategory ps
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
INNER JOIN Production.ProductCategory pc
    ON ps.ProductCategoryID = pc.ProductCategoryID
ORDER BY pc.Name, ps.Name, p.Name;
GO

-- ============================================================================
-- 2. LEFT JOIN – Tutte le righe della tabella a sinistra, anche senza match
-- ============================================================================

-- Esempio 2.1: Tutti i prodotti, con sottocategoria se presente
-- I prodotti senza sottocategoria avranno NULL nella colonna Sottocategoria
SELECT 
    p.ProductID,
    p.Name            AS Prodotto,
    ps.Name           AS Sottocategoria
FROM Production.Product p
LEFT JOIN Production.ProductSubcategory ps
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
ORDER BY ps.Name, p.Name;
GO

-- Esempio 2.2: Trovare i prodotti SENZA sottocategoria (anti-join pattern)
-- Performance: LEFT JOIN + IS NULL è tipicamente più efficiente di NOT IN
SELECT 
    p.ProductID,
    p.Name            AS Prodotto
FROM Production.Product p
LEFT JOIN Production.ProductSubcategory ps
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
WHERE ps.ProductSubcategoryID IS NULL
ORDER BY p.Name;
GO

-- ============================================================================
-- 3. RIGHT JOIN – Tutte le righe della tabella a destra
-- ============================================================================

-- Esempio 3.1: Equivalente logico del LEFT JOIN precedente, invertito
-- In pratica si usa raramente: meglio riscrivere come LEFT JOIN per leggibilità
SELECT 
    p.ProductID,
    p.Name            AS Prodotto,
    ps.Name           AS Sottocategoria
FROM Production.ProductSubcategory ps
RIGHT JOIN Production.Product p
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
ORDER BY ps.Name, p.Name;
GO

-- ============================================================================
-- 4. FULL OUTER JOIN – Tutte le righe di entrambe le tabelle
-- ============================================================================

-- Esempio 4.1: Confronto completo tra venditori e territori
-- Mostra venditori senza territorio E territori senza venditore
SELECT 
    sp.BusinessEntityID,
    per.FirstName + ' ' + per.LastName  AS Venditore,
    st.Name                             AS Territorio
FROM Sales.SalesPerson sp
FULL OUTER JOIN Sales.SalesTerritory st
    ON sp.TerritoryID = st.TerritoryID
LEFT JOIN Person.Person per
    ON sp.BusinessEntityID = per.BusinessEntityID
ORDER BY per.LastName;
GO

-- ============================================================================
-- 5. CROSS JOIN – Prodotto cartesiano
-- ============================================================================

-- Esempio 5.1: Generare tutte le combinazioni colore × taglia (piccola tabella)
-- Attenzione: su tabelle grandi il CROSS JOIN genera N × M righe!
SELECT 
    c.Name AS Colore,
    s.Name AS Taglia
FROM (SELECT DISTINCT Color AS Name FROM Production.Product WHERE Color IS NOT NULL) c
CROSS JOIN (SELECT DISTINCT Size AS Name FROM Production.Product WHERE Size IS NOT NULL) s
ORDER BY c.Name, s.Name;
GO

-- Esempio 5.2: CROSS JOIN utile – generare un calendario
SELECT TOP 30
    DATEADD(DAY, n.Numero, d.DataInizio) AS DataCalendario,
    DATENAME(WEEKDAY, DATEADD(DAY, n.Numero, d.DataInizio)) AS GiornoSettimana
FROM (
    SELECT ROW_NUMBER() OVER (ORDER BY BusinessEntityID) - 1 AS Numero
    FROM Person.Person
) AS n
CROSS JOIN (
    SELECT CAST('2024-01-01' AS DATE) AS DataInizio
) AS d
ORDER BY DataCalendario;
GO

-- ============================================================================
-- 6. SELF JOIN – Una tabella unita a se stessa
-- ============================================================================

-- Esempio 6.1: Clienti nella stessa città (versione semplice)
SELECT 
    a.City,
    a.AddressLine1  AS Indirizzo_A,
    b.AddressLine1  AS Indirizzo_B
FROM Person.Address a
INNER JOIN Person.Address b
    ON a.City = b.City
    AND a.AddressID < b.AddressID   -- evita duplicati (A,B) e (B,A)
WHERE a.City = 'Seattle'            -- limitiamo per demo
ORDER BY a.City;
GO

-- ============================================================================
-- 7. CONDIZIONI DI JOIN vs WHERE – Differenza cruciale con OUTER JOIN
-- ============================================================================

-- Esempio 7.1: Filtro nella clausola ON (mantiene tutte le righe LEFT)
-- Restituisce TUTTI i prodotti; la sottocategoria appare solo se = 'Bikes'
SELECT 
    p.Name   AS Prodotto,
    ps.Name  AS Sottocategoria
FROM Production.Product p
LEFT JOIN Production.ProductSubcategory ps
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    AND ps.Name = 'Bikes'   -- filtro nella ON
ORDER BY ps.Name DESC, p.Name;
GO

-- Esempio 7.2: Filtro nella clausola WHERE (elimina le righe senza match)
-- Restituisce SOLO i prodotti con sottocategoria = 'Bikes'
-- Il LEFT JOIN si comporta come un INNER JOIN!
SELECT 
    p.Name   AS Prodotto,
    ps.Name  AS Sottocategoria
FROM Production.Product p
LEFT JOIN Production.ProductSubcategory ps
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
WHERE ps.Name = 'Bikes'     -- filtro nella WHERE
ORDER BY p.Name;
GO

-- ============================================================================
-- 8. JOIN E PERFORMANCE – Suggerimenti pratici
-- ============================================================================

-- Esempio 8.1: Confronto – EXISTS vs LEFT JOIN anti-pattern
-- Metodo 1: EXISTS (spesso più efficiente, cortocircuita al primo match)
SELECT p.ProductID, p.Name
FROM Production.Product p
WHERE EXISTS (
    SELECT 1 
    FROM Sales.SalesOrderDetailEnlarged sod 
    WHERE sod.ProductID = p.ProductID
);
GO

-- Metodo 2: INNER JOIN con DISTINCT (meno efficiente se molte righe duplicate)
SELECT DISTINCT p.ProductID, p.Name
FROM Production.Product p
INNER JOIN Sales.SalesOrderDetailEnlarged sod
    ON p.ProductID = sod.ProductID;
GO

-- Esempio 8.2: Evitare funzioni nella condizione di JOIN (SARGability)
-- ❌ Non sargable: la funzione impedisce l'uso dell'indice
SELECT 
    soh.SalesOrderID,
    soh.OrderDate,
    soh.TotalDue
FROM Sales.SalesOrderHeaderEnlarged soh
INNER JOIN Sales.SalesTerritory st
    ON CAST(soh.TerritoryID AS VARCHAR) = CAST(st.TerritoryID AS VARCHAR);
GO

-- ✅ Sargable: join diretto su colonne native
SELECT 
    soh.SalesOrderID,
    soh.OrderDate,
    soh.TotalDue
FROM Sales.SalesOrderHeaderEnlarged soh
INNER JOIN Sales.SalesTerritory st
    ON soh.TerritoryID = st.TerritoryID;
GO

-- ============================================================================
-- 9. UNION / UNION ALL – Combinare set di risultati verticalmente
-- ============================================================================

-- Esempio 9.1: UNION ALL – include i duplicati, più veloce
-- Tutte le città con sede aziendale o indirizzo di spedizione
SELECT a.City
FROM Person.Address a
INNER JOIN Person.BusinessEntityAddress bea
    ON a.AddressID = bea.AddressID

UNION ALL -- include i duplicati

SELECT a.City
FROM Person.Address a
INNER JOIN Sales.SalesOrderHeader soh
    ON a.AddressID = soh.ShipToAddressID
ORDER BY City;
GO

-- Esempio 9.2: UNION – rimuove i duplicati (aggiunge un DISTINCT implicito)
-- Tutte le città con sede aziendale o indirizzo di spedizione
SELECT a.City
FROM Person.Address a
INNER JOIN Person.BusinessEntityAddress bea
    ON a.AddressID = bea.AddressID

UNION  -- rimuove duplicati

SELECT a.City
FROM Person.Address a
INNER JOIN Sales.SalesOrderHeader soh
    ON a.AddressID = soh.ShipToAddressID
ORDER BY City;
GO

-- ============================================================================
-- 10. INTERSECT e EXCEPT – Operazioni insiemistiche avanzate
-- ============================================================================

-- Esempio 10.1: INTERSECT – Città presenti sia come sede che come destinazione
SELECT a.City, sp.Name AS Stato
FROM Person.Address a
INNER JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
INNER JOIN Person.BusinessEntityAddress bea ON a.AddressID = bea.AddressID

INTERSECT

SELECT a.City, sp.Name AS Stato
FROM Person.Address a
INNER JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
INNER JOIN Sales.SalesOrderHeader soh ON a.AddressID = soh.ShipToAddressID
ORDER BY Stato, City;
GO

-- Esempio 10.2: EXCEPT – Città sede che NON sono destinazioni di spedizione
SELECT a.City, sp.Name AS Stato
FROM Person.Address a
INNER JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
INNER JOIN Person.BusinessEntityAddress bea ON a.AddressID = bea.AddressID

EXCEPT

SELECT a.City, sp.Name AS Stato
FROM Person.Address a
INNER JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
INNER JOIN Sales.SalesOrderHeader soh ON a.AddressID = soh.ShipToAddressID
ORDER BY Stato, City;
GO

-- ============================================================================
-- 11. APPLY – CROSS APPLY e OUTER APPLY
-- ============================================================================

-- Esempio 11.1: CROSS APPLY – I 3 ordini più recenti per ogni venditore
SELECT 
    per.FirstName + ' ' + per.LastName AS Venditore,
    recenti.SalesOrderID,
    recenti.OrderDate,
    recenti.TotalDue
FROM Sales.SalesPerson sp
INNER JOIN Person.Person per
    ON sp.BusinessEntityID = per.BusinessEntityID
CROSS APPLY (
    SELECT TOP 3 
        soh.SalesOrderID, 
        soh.OrderDate, 
        soh.TotalDue
    FROM Sales.SalesOrderHeader soh
    WHERE soh.SalesPersonID = sp.BusinessEntityID
    ORDER BY soh.OrderDate DESC
) recenti
ORDER BY Venditore, recenti.OrderDate DESC;
GO

-- Esempio 11.2: OUTER APPLY – Come CROSS APPLY ma include venditori senza ordini
SELECT 
    per.FirstName + ' ' + per.LastName AS Venditore,
    recenti.SalesOrderID,
    recenti.OrderDate,
    recenti.TotalDue
FROM Sales.SalesPerson sp
INNER JOIN Person.Person per
    ON sp.BusinessEntityID = per.BusinessEntityID
OUTER APPLY (
    SELECT TOP 3 
        soh.SalesOrderID, 
        soh.OrderDate, 
        soh.TotalDue
    FROM Sales.SalesOrderHeader soh
    WHERE soh.SalesPersonID = sp.BusinessEntityID
    ORDER BY soh.OrderDate DESC
) recenti
ORDER BY Venditore, recenti.OrderDate DESC;
GO


