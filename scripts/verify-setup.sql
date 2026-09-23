-- Verifica rapida del setup: connessione OK + AdventureWorks presente e popolato.
-- Esegui questo script dopo esserti connesso con l'estensione mssql (F5 / "Execute Query").

USE AdventureWorks;
GO

SELECT
    DB_NAME()                                   AS database_corrente,
    @@VERSION                                   AS versione_sql_server,
    (SELECT COUNT(*) FROM Person.Person)        AS n_persone,
    (SELECT COUNT(*) FROM Sales.SalesOrderHeader) AS n_ordini;
GO

PRINT 'Se vedi righe con conteggi > 0 sopra, il setup è verificato con successo.';
