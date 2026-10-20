/* ============================================================================
   Modulo 3 — Sezione 3
   VINCOLI (CONSTRAINT) — script di esempi e demo
   ============================================================================ */

USE tempdb;
GO

DROP TABLE IF EXISTS dbo.Demo_Riga;
DROP TABLE IF EXISTS dbo.Demo_Ordine;
DROP TABLE IF EXISTS dbo.Demo_Cliente;
GO

CREATE TABLE dbo.Demo_Cliente
(
    ClienteID   INT           NOT NULL,
    RagSociale  NVARCHAR(80)  NOT NULL,
    PartitaIVA  CHAR(11)      NULL,
    CONSTRAINT PK_Demo_Cliente PRIMARY KEY CLUSTERED (ClienteID)
);

CREATE TABLE dbo.Demo_Ordine
(
    OrdineID        INT           NOT NULL,
    ClienteID       INT           NOT NULL,
    Stato           CHAR(1)       NOT NULL
        CONSTRAINT DF_Demo_Ordine_Stato DEFAULT ('A'),
    DataOrdine      DATETIME2(0)  NOT NULL
        CONSTRAINT DF_Demo_Ordine_Data  DEFAULT (SYSDATETIME()),
    DataSpedizione  DATETIME2(0)  NULL,
    Importo         DECIMAL(12,2) NULL,
    CONSTRAINT PK_Demo_Ordine PRIMARY KEY CLUSTERED (OrdineID)
);

CREATE TABLE dbo.Demo_Riga
(
    RigaID      INT           NOT NULL IDENTITY(1,1),
    OrdineID    INT           NOT NULL,
    Descrizione NVARCHAR(60)  NOT NULL,
    Quantita    INT           NOT NULL,
    CONSTRAINT PK_Demo_Riga PRIMARY KEY CLUSTERED (RigaID)
);
GO

INSERT INTO dbo.Demo_Cliente (ClienteID, RagSociale, PartitaIVA)
VALUES (1, N'Rossi SpA',   '01234567890'),
       (2, N'Bianchi Srl', '09876543210');

INSERT INTO dbo.Demo_Ordine (OrdineID, ClienteID, Importo)
VALUES (100, 1, 250.00),
       (101, 2, 480.00);

INSERT INTO dbo.Demo_Riga (OrdineID, Descrizione, Quantita)
VALUES (100, N'Telaio', 1),
       (100, N'Ruota',  2),
       (101, N'Sella',  1);
GO

SELECT * FROM dbo.Demo_Ordine;
GO


/* ============================================================================
   1. NOT NULL E DEFAULT
   ============================================================================ */

SELECT * FROM sys.columns
WHERE object_id = OBJECT_ID('dbo.Demo_Ordine');

-- Colonna assente dalla INSERT: il DEFAULT scatta
INSERT INTO dbo.Demo_Ordine (OrdineID, ClienteID, Importo)
VALUES (102, 1, 90.00);

SELECT *
FROM   dbo.Demo_Ordine
WHERE  OrdineID = 102;
GO

-- NULL esplicito: il DEFAULT non scatta e il NOT NULL rifiuta la riga
INSERT INTO dbo.Demo_Ordine (OrdineID, ClienteID, Stato, Importo)
VALUES (103, 1, NULL, 90.00);
GO


/* ============================================================================
   2. PRIMARY KEY
   ============================================================================ */

-- La PK ha creato l'indice clustered: è la struttura fisica della tabella
SELECT
    Indice    = i.name,
    Tipo      = i.type_desc,
    Univoco   = i.is_unique,
    DaVincolo = i.is_primary_key
FROM   sys.indexes AS i
WHERE  i.object_id = OBJECT_ID('tempdb.dbo.Demo_Ordine')
       AND i.index_id > 0;
       
-- ERRORE ATTESO 2627 — Violation of PRIMARY KEY constraint 'PK_Demo_Ordine'
INSERT INTO dbo.Demo_Ordine (OrdineID, ClienteID, Importo)
VALUES (100, 1, 10.00);
GO

GO


/* ============================================================================
   3. UNIQUE E IL PROBLEMA DEL SECONDO NULL
   ============================================================================ */

ALTER TABLE dbo.Demo_Cliente
    ADD CONSTRAINT UQ_Demo_Cliente_PIVA UNIQUE (PartitaIVA);
GO

-- Primo cliente senza partita IVA: passa
INSERT INTO dbo.Demo_Cliente (ClienteID, RagSociale, PartitaIVA)
VALUES (3, N'Verdi (privato)', NULL);
GO

-- Secondo cliente senza partita IVA
-- ERRORE ATTESO 2627 — il secondo NULL è considerato un duplicato
INSERT INTO dbo.Demo_Cliente (ClienteID, RagSociale, PartitaIVA)
VALUES (4, N'Neri (privato)', NULL);
GO

INSERT INTO dbo.Demo_Cliente (ClienteID, RagSociale, PartitaIVA)
VALUES (5, N'Duplicato Srl', '01234567890');



CREATE UNIQUE NONCLUSTERED INDEX UX_Demo_Cliente_PIVA
    ON dbo.Demo_Cliente (PartitaIVA)
GO

-- L'unicità resta garantita dove il valore c'è
-- ERRORE ATTESO 2601 — Cannot insert duplicate key row ... UX_Demo_Cliente_PIVA
INSERT INTO dbo.Demo_Cliente (ClienteID, RagSociale, PartitaIVA)
VALUES (6, N'Duplicato Srl', '01234567890');
GO


/* ============================================================================
   4. CHECK E LA TRAPPOLA DEL NULL
   ============================================================================ */

ALTER TABLE dbo.Demo_Ordine
    ADD CONSTRAINT CK_Demo_Ordine_Importo CHECK (Importo > 0);

ALTER TABLE dbo.Demo_Ordine
    ADD CONSTRAINT CK_Demo_Ordine_Date CHECK (DataSpedizione >= DataOrdine);
GO

-- ERRORE ATTESO 547 — conflitto con CK_Demo_Ordine_Importo
INSERT INTO dbo.Demo_Ordine (OrdineID, ClienteID, Importo)
VALUES (104, 1, -50.00);
GO

-- Stesso vincolo, valore NULL: la riga viene ACCETTATA perchè check verifica e prende TRUE e UNKNOWN.
INSERT INTO dbo.Demo_Ordine (OrdineID, ClienteID, Importo)
VALUES (105, 1, NULL);

SELECT OrdineID, Importo
FROM   dbo.Demo_Ordine
WHERE  OrdineID = 105;   -- la riga c'è: il CHECK non l'ha fermata
GO

-- La condizione va chiusa esplicitamente (o la colonna dichiarata NOT NULL)
DELETE FROM dbo.Demo_Ordine WHERE OrdineID = 105;

ALTER TABLE dbo.Demo_Ordine DROP CONSTRAINT CK_Demo_Ordine_Importo;

ALTER TABLE dbo.Demo_Ordine
    ADD CONSTRAINT CK_Demo_Ordine_Importo
    CHECK (Importo IS NOT NULL AND Importo >= 0);
GO

-- ERRORE ATTESO 547 — adesso anche il NULL viene rifiutato
INSERT INTO dbo.Demo_Ordine (OrdineID, ClienteID, Importo)
VALUES (105, 1, NULL);
GO


/* ============================================================================
   5. FOREIGN KEY
   ============================================================================ */

ALTER TABLE dbo.Demo_Riga
    ADD CONSTRAINT FK_Demo_Riga_Ordine FOREIGN KEY (OrdineID)
    REFERENCES dbo.Demo_Ordine (OrdineID);

-- Riga orfana
-- ERRORE ATTESO 547 — conflitto con FK_Demo_Riga_Ordine
INSERT INTO dbo.Demo_Riga (OrdineID, Descrizione, Quantita)
VALUES (999999, N'Riga fantasma', 1);
GO

-- Cancellazione del padre con figli collegati
-- ERRORE ATTESO 547 — The DELETE statement conflicted with the REFERENCE constraint
DELETE FROM dbo.Demo_Ordine WHERE OrdineID = 100;
GO



/* ============================================================================
   6. AZIONI REFERENZIALI: ON DELETE CASCADE
   ============================================================================ */

ALTER TABLE dbo.Demo_Riga DROP CONSTRAINT FK_Demo_Riga_Ordine;

ALTER TABLE dbo.Demo_Riga
    ADD CONSTRAINT FK_Demo_Riga_Ordine FOREIGN KEY (OrdineID)
    REFERENCES dbo.Demo_Ordine (OrdineID)
    ON DELETE CASCADE;
GO

SELECT  COUNT(*) AS NumRighe FROM dbo.Demo_Riga WHERE OrdineID = 100;

-- Ora la DELETE sul padre riesce e porta via anche i figli
DELETE FROM dbo.Demo_Ordine WHERE OrdineID = 100;

SELECT  COUNT(*) AS NumRighe FROM dbo.Demo_Riga WHERE OrdineID = 100;
GO

/* La cancellazione è avvenuta su due tabelle con una sola istruzione: comodo
   quando è voluto, pericoloso quando la relazione non è padre/figlio */

/* ============================================================================
   PULIZIA
   ============================================================================ */

USE tempdb;
GO

DROP TABLE IF EXISTS dbo.Demo_Riga;
DROP TABLE IF EXISTS dbo.Demo_Ordine;
DROP TABLE IF EXISTS dbo.Demo_Cliente;
GO

SELECT Ambiente_pulito = 1;
GO
