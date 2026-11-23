/*
    Customer Cohort & Churn Analytics
    Modelo dimensional para SQL Server / Power BI.

    Grano de FactCustomerChurn: una fila por customerID en el snapshot
    observado. Las tasas describen resultados observados; no son predicciones.

    Ejecucion por etapas:
      1. Ejecutar las secciones 1 a 4 para crear la base y las tablas.
      2. Importar telco_customer_churn_clean.csv a dbo.StgCustomerChurn.
      3. Ejecutar la seccion 5 y luego las secciones 6 y 7.
*/

-- 1. Database Setup
IF DB_ID(N'CustomerChurnDW') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE [CustomerChurnDW]');
END;
GO

USE [CustomerChurnDW];
GO

-- 2. Staging Table
-- Se guardan los valores del CSV como texto para evitar conversiones
-- silenciosas durante la importacion. Las conversiones se validan en la
-- seccion 5. Las columnas corresponden a los encabezados del CSV limpio.
IF OBJECT_ID(N'dbo.StgCustomerChurn', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StgCustomerChurn
    (
        customerID       nvarchar(100) NULL,
        gender           nvarchar(100) NULL,
        SeniorCitizen    nvarchar(100) NULL,
        Partner          nvarchar(100) NULL,
        Dependents       nvarchar(100) NULL,
        tenure           nvarchar(100) NULL,
        PhoneService     nvarchar(100) NULL,
        MultipleLines    nvarchar(100) NULL,
        InternetService  nvarchar(100) NULL,
        OnlineSecurity   nvarchar(100) NULL,
        OnlineBackup     nvarchar(100) NULL,
        DeviceProtection nvarchar(100) NULL,
        TechSupport      nvarchar(100) NULL,
        StreamingTV      nvarchar(100) NULL,
        StreamingMovies  nvarchar(100) NULL,
        Contract         nvarchar(100) NULL,
        PaperlessBilling nvarchar(100) NULL,
        PaymentMethod    nvarchar(100) NULL,
        MonthlyCharges   nvarchar(100) NULL,
        TotalCharges     nvarchar(100) NULL,
        Churn            nvarchar(100) NULL,
        Churn_Flag       nvarchar(100) NULL,
        Tenure_Group     nvarchar(100) NULL
    );
END;
GO

/*
    Para ejecutar todo el archivo en una sola operacion, configurar @CsvPath
    con la ruta real del CSV. BULK INSERT requiere SQL Server 2017+ y que la
    cuenta del servicio SQL Server pueda leer ese archivo.

    Si se prefiere el asistente de SSMS, dejar @CsvPath en NULL:
      1. Ejecutar el script una vez para crear base y staging.
      2. Database > Tasks > Import Data > Flat File Source; elegir el CSV,
         marcar que la primera fila contiene encabezados y usar UTF-8.
      3. Importar a la tabla existente CustomerChurnDW.dbo.StgCustomerChurn,
         mapeando las 23 columnas por nombre. Mantener TotalCharges vacio/NULL
         en sus 11 filas en blanco, sin asignar cero.
      4. Volver a ejecutar el archivo completo.

    No se truncan datos de staging automaticamente. Si staging ya tiene filas,
    la importacion BULK se omite y se procesa lo que ya esta en staging.
*/
DECLARE @CsvPath nvarchar(4000) = NULL;
-- Para carga automatica, reemplazar NULL, por ejemplo:
-- SET @CsvPath = N'C:\ruta\real\telco_customer_churn_clean.csv';

IF @CsvPath IS NOT NULL AND LTRIM(RTRIM(@CsvPath)) <> N''
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.StgCustomerChurn)
    BEGIN
        DECLARE @BulkSql nvarchar(max) =
            N'BULK INSERT dbo.StgCustomerChurn FROM '
            + QUOTENAME(@CsvPath, '''')
            + N' WITH (FORMAT = ''CSV'', FIRSTROW = 2, CODEPAGE = ''65001'', '
            + N'KEEPNULLS, TABLOCK);';
        EXEC sys.sp_executesql @BulkSql;
    END
    ELSE
    BEGIN
        PRINT N'Staging ya contiene filas; se omite BULK INSERT y se usa su contenido actual.';
    END;
END;
GO

-- 3. Dimension Tables
-- DimTenure representa los grupos calculados en Python. El valor exacto
-- tenure (en meses) permanece como atributo numerico en la tabla de hechos.
IF OBJECT_ID(N'dbo.DimTenure', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimTenure
    (
        TenureKey      smallint IDENTITY(1,1) NOT NULL,
        TenureGroup    nvarchar(20) NOT NULL,
        GroupSortOrder tinyint NOT NULL,
        CONSTRAINT PK_DimTenure PRIMARY KEY CLUSTERED (TenureKey),
        CONSTRAINT UQ_DimTenure_TenureGroup UNIQUE (TenureGroup),
        CONSTRAINT UQ_DimTenure_GroupSortOrder UNIQUE (GroupSortOrder),
        CONSTRAINT CK_DimTenure_Group CHECK
        (
            (TenureGroup = N'0-12 meses'  AND GroupSortOrder = 1) OR
            (TenureGroup = N'13-24 meses' AND GroupSortOrder = 2) OR
            (TenureGroup = N'25-48 meses' AND GroupSortOrder = 3) OR
            (TenureGroup = N'49-72 meses' AND GroupSortOrder = 4)
        )
    );
END;
GO

IF OBJECT_ID(N'dbo.DimContract', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimContract
    (
        ContractKey  tinyint IDENTITY(1,1) NOT NULL,
        ContractName nvarchar(30) NOT NULL,
        SortOrder    tinyint NOT NULL,
        CONSTRAINT PK_DimContract PRIMARY KEY CLUSTERED (ContractKey),
        CONSTRAINT UQ_DimContract_ContractName UNIQUE (ContractName),
        CONSTRAINT UQ_DimContract_SortOrder UNIQUE (SortOrder),
        CONSTRAINT CK_DimContract_Values CHECK
        (
            (ContractName = N'Month-to-month' AND SortOrder = 1) OR
            (ContractName = N'One year'        AND SortOrder = 2) OR
            (ContractName = N'Two year'        AND SortOrder = 3)
        )
    );
END;
GO

IF OBJECT_ID(N'dbo.DimPayment', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimPayment
    (
        PaymentKey    tinyint IDENTITY(1,1) NOT NULL,
        PaymentMethod nvarchar(50) NOT NULL,
        CONSTRAINT PK_DimPayment PRIMARY KEY CLUSTERED (PaymentKey),
        CONSTRAINT UQ_DimPayment_PaymentMethod UNIQUE (PaymentMethod)
    );
END;
GO

-- Un perfil de servicios por combinacion distinta de las nueve columnas
-- analizadas por Python. Asi se conserva el detalle sin crear nueve dimensiones.
IF OBJECT_ID(N'dbo.DimService', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimService
    (
        ServiceKey       int IDENTITY(1,1) NOT NULL,
        PhoneService     nvarchar(25) NOT NULL,
        MultipleLines    nvarchar(25) NOT NULL,
        InternetService  nvarchar(25) NOT NULL,
        OnlineSecurity   nvarchar(25) NOT NULL,
        OnlineBackup     nvarchar(25) NOT NULL,
        DeviceProtection nvarchar(25) NOT NULL,
        TechSupport      nvarchar(25) NOT NULL,
        StreamingTV      nvarchar(25) NOT NULL,
        StreamingMovies  nvarchar(25) NOT NULL,
        CONSTRAINT PK_DimService PRIMARY KEY CLUSTERED (ServiceKey),
        CONSTRAINT UQ_DimService_Profile UNIQUE
        (
            PhoneService,
            MultipleLines,
            InternetService,
            OnlineSecurity,
            OnlineBackup,
            DeviceProtection,
            TechSupport,
            StreamingTV,
            StreamingMovies
        )
    );
END;
GO

-- 4. Fact Table
IF OBJECT_ID(N'dbo.FactCustomerChurn', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactCustomerChurn
    (
        CustomerChurnKey bigint IDENTITY(1,1) NOT NULL,
        customerID       nvarchar(50) NOT NULL,
        TenureKey        smallint NOT NULL,
        ContractKey      tinyint NOT NULL,
        PaymentKey       tinyint NOT NULL,
        ServiceKey       int NOT NULL,
        TenureMonths     tinyint NOT NULL,
        MonthlyCharges   decimal(10,2) NOT NULL,
        TotalCharges     decimal(12,2) NULL,
        Churn_Flag       bit NOT NULL,
        CONSTRAINT PK_FactCustomerChurn
            PRIMARY KEY CLUSTERED (CustomerChurnKey),
        CONSTRAINT UQ_FactCustomerChurn_customerID UNIQUE (customerID),
        CONSTRAINT FK_FactCustomerChurn_DimTenure
            FOREIGN KEY (TenureKey) REFERENCES dbo.DimTenure (TenureKey),
        CONSTRAINT FK_FactCustomerChurn_DimContract
            FOREIGN KEY (ContractKey) REFERENCES dbo.DimContract (ContractKey),
        CONSTRAINT FK_FactCustomerChurn_DimPayment
            FOREIGN KEY (PaymentKey) REFERENCES dbo.DimPayment (PaymentKey),
        CONSTRAINT FK_FactCustomerChurn_DimService
            FOREIGN KEY (ServiceKey) REFERENCES dbo.DimService (ServiceKey),
        CONSTRAINT CK_FactCustomerChurn_Tenure
            CHECK (TenureMonths BETWEEN 0 AND 72),
        CONSTRAINT CK_FactCustomerChurn_MonthlyCharges
            CHECK (MonthlyCharges >= 0),
        CONSTRAINT CK_FactCustomerChurn_TotalCharges
            CHECK (TotalCharges IS NULL OR TotalCharges >= 0)
    );
END;
GO

-- Indices para agrupaciones habituales en SQL Server. La clave unica sobre
-- customerID ya crea un indice para identificar/actualizar clientes.
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.FactCustomerChurn')
      AND name = N'IX_FactCustomerChurn_Tenure_Contract'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FactCustomerChurn_Tenure_Contract
        ON dbo.FactCustomerChurn (TenureKey, ContractKey)
        INCLUDE (Churn_Flag, TenureMonths);
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.FactCustomerChurn')
      AND name = N'IX_FactCustomerChurn_Payment'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FactCustomerChurn_Payment
        ON dbo.FactCustomerChurn (PaymentKey)
        INCLUDE (Churn_Flag);
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.FactCustomerChurn')
      AND name = N'IX_FactCustomerChurn_Service'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FactCustomerChurn_Service
        ON dbo.FactCustomerChurn (ServiceKey)
        INCLUDE (Churn_Flag, MonthlyCharges);
END;
GO

-- 5. Data Loading
-- Si staging esta vacia, se omite la carga y el resto del script termina
-- normalmente con consultas vacias.
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF EXISTS (SELECT 1 FROM dbo.StgCustomerChurn)
BEGIN

-- Convierte una sola vez. Los campos obligatorios vacios y las conversiones
-- invalidas se detienen mas abajo; TotalCharges puede permanecer NULL.
IF OBJECT_ID(N'tempdb..#CustomerSource') IS NOT NULL
    DROP TABLE #CustomerSource;

SELECT
    NULLIF(LTRIM(RTRIM(s.customerID)), N'') AS customerID,
    TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(s.tenure)), N'')) AS TenureMonths,
    NULLIF(LTRIM(RTRIM(s.Tenure_Group)), N'') AS TenureGroup,
    NULLIF(LTRIM(RTRIM(s.Contract)), N'') AS ContractName,
    NULLIF(LTRIM(RTRIM(s.PaymentMethod)), N'') AS PaymentMethod,
    NULLIF(LTRIM(RTRIM(s.PhoneService)), N'') AS PhoneService,
    NULLIF(LTRIM(RTRIM(s.MultipleLines)), N'') AS MultipleLines,
    NULLIF(LTRIM(RTRIM(s.InternetService)), N'') AS InternetService,
    NULLIF(LTRIM(RTRIM(s.OnlineSecurity)), N'') AS OnlineSecurity,
    NULLIF(LTRIM(RTRIM(s.OnlineBackup)), N'') AS OnlineBackup,
    NULLIF(LTRIM(RTRIM(s.DeviceProtection)), N'') AS DeviceProtection,
    NULLIF(LTRIM(RTRIM(s.TechSupport)), N'') AS TechSupport,
    NULLIF(LTRIM(RTRIM(s.StreamingTV)), N'') AS StreamingTV,
    NULLIF(LTRIM(RTRIM(s.StreamingMovies)), N'') AS StreamingMovies,
    TRY_CONVERT(decimal(10,2), NULLIF(LTRIM(RTRIM(s.MonthlyCharges)), N''))
        AS MonthlyCharges,
    TRY_CONVERT(decimal(12,2), NULLIF(LTRIM(RTRIM(s.TotalCharges)), N''))
        AS TotalCharges,
    NULLIF(LTRIM(RTRIM(s.Churn)), N'') AS Churn,
    TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(s.Churn_Flag)), N'')) AS ChurnFlag
INTO #CustomerSource
FROM dbo.StgCustomerChurn AS s;

IF EXISTS
(
    SELECT 1
    FROM dbo.StgCustomerChurn AS s
    WHERE NULLIF(LTRIM(RTRIM(s.TotalCharges)), N'') IS NOT NULL
      AND TRY_CONVERT(decimal(12,2), LTRIM(RTRIM(s.TotalCharges))) IS NULL
)
BEGIN
    ;THROW 51001, 'TotalCharges contiene valores no numericos; revise staging.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM #CustomerSource AS s
    WHERE s.customerID IS NULL
       OR s.TenureMonths IS NULL
       OR s.TenureGroup IS NULL
       OR s.ContractName IS NULL
       OR s.PaymentMethod IS NULL
       OR s.PhoneService IS NULL
       OR s.MultipleLines IS NULL
       OR s.InternetService IS NULL
       OR s.OnlineSecurity IS NULL
       OR s.OnlineBackup IS NULL
       OR s.DeviceProtection IS NULL
       OR s.TechSupport IS NULL
       OR s.StreamingTV IS NULL
       OR s.StreamingMovies IS NULL
       OR s.MonthlyCharges IS NULL
       OR s.Churn IS NULL
       OR s.ChurnFlag IS NULL
       OR s.Churn NOT IN (N'No', N'Yes')
       OR s.ChurnFlag NOT IN (0, 1)
       OR (s.Churn = N'No'  AND s.ChurnFlag <> 0)
       OR (s.Churn = N'Yes' AND s.ChurnFlag <> 1)
       OR s.TenureMonths NOT BETWEEN 0 AND 72
       OR NOT
       (
           (s.TenureMonths BETWEEN 0  AND 12 AND s.TenureGroup = N'0-12 meses') OR
           (s.TenureMonths BETWEEN 13 AND 24 AND s.TenureGroup = N'13-24 meses') OR
           (s.TenureMonths BETWEEN 25 AND 48 AND s.TenureGroup = N'25-48 meses') OR
           (s.TenureMonths BETWEEN 49 AND 72 AND s.TenureGroup = N'49-72 meses')
       )
       OR s.MonthlyCharges < 0
       OR s.TotalCharges < 0
       OR s.ContractName NOT IN (N'Month-to-month', N'One year', N'Two year')
)
BEGIN
    ;THROW 51002, 'Staging tiene datos obligatorios invalidos o incompatibles con las transformaciones Python.', 1;
END;

IF EXISTS
(
    SELECT s.customerID
    FROM #CustomerSource AS s
    GROUP BY s.customerID
    HAVING COUNT_BIG(*) > 1
)
BEGIN
    ;THROW 51003, 'Hay customerID duplicados en staging; no se cargo ningun dato.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.DimTenure (TenureGroup, GroupSortOrder)
    SELECT d.TenureGroup,
           CASE d.TenureGroup
               WHEN N'0-12 meses'  THEN 1
               WHEN N'13-24 meses' THEN 2
               WHEN N'25-48 meses' THEN 3
               WHEN N'49-72 meses' THEN 4
           END
    FROM (SELECT DISTINCT TenureGroup FROM #CustomerSource) AS d
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.DimTenure AS existing
        WHERE existing.TenureGroup = d.TenureGroup
    );

    INSERT INTO dbo.DimContract (ContractName, SortOrder)
    SELECT d.ContractName,
           CASE d.ContractName
               WHEN N'Month-to-month' THEN 1
               WHEN N'One year'        THEN 2
               WHEN N'Two year'        THEN 3
           END
    FROM (SELECT DISTINCT ContractName FROM #CustomerSource) AS d
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.DimContract AS existing
        WHERE existing.ContractName = d.ContractName
    );

    INSERT INTO dbo.DimPayment (PaymentMethod)
    SELECT DISTINCT s.PaymentMethod
    FROM #CustomerSource AS s
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.DimPayment AS existing
        WHERE existing.PaymentMethod = s.PaymentMethod
    );

    INSERT INTO dbo.DimService
    (
        PhoneService,
        MultipleLines,
        InternetService,
        OnlineSecurity,
        OnlineBackup,
        DeviceProtection,
        TechSupport,
        StreamingTV,
        StreamingMovies
    )
    SELECT DISTINCT
        s.PhoneService,
        s.MultipleLines,
        s.InternetService,
        s.OnlineSecurity,
        s.OnlineBackup,
        s.DeviceProtection,
        s.TechSupport,
        s.StreamingTV,
        s.StreamingMovies
    FROM #CustomerSource AS s
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.DimService AS existing
        WHERE existing.PhoneService = s.PhoneService
          AND existing.MultipleLines = s.MultipleLines
          AND existing.InternetService = s.InternetService
          AND existing.OnlineSecurity = s.OnlineSecurity
          AND existing.OnlineBackup = s.OnlineBackup
          AND existing.DeviceProtection = s.DeviceProtection
          AND existing.TechSupport = s.TechSupport
          AND existing.StreamingTV = s.StreamingTV
          AND existing.StreamingMovies = s.StreamingMovies
    );

    -- Actualiza clientes existentes (recarga repetible del snapshot), inserta
    -- nuevos y no elimina clientes ausentes de una importacion posterior.
    UPDATE f
       SET f.TenureKey = dt.TenureKey,
           f.ContractKey = dc.ContractKey,
           f.PaymentKey = dp.PaymentKey,
           f.ServiceKey = ds.ServiceKey,
           f.TenureMonths = s.TenureMonths,
           f.MonthlyCharges = s.MonthlyCharges,
           f.TotalCharges = s.TotalCharges,
           f.Churn_Flag = CONVERT(bit, s.ChurnFlag)
    FROM dbo.FactCustomerChurn AS f
    INNER JOIN #CustomerSource AS s
        ON s.customerID = f.customerID
    INNER JOIN dbo.DimTenure AS dt
        ON dt.TenureGroup = s.TenureGroup
    INNER JOIN dbo.DimContract AS dc
        ON dc.ContractName = s.ContractName
    INNER JOIN dbo.DimPayment AS dp
        ON dp.PaymentMethod = s.PaymentMethod
    INNER JOIN dbo.DimService AS ds
        ON ds.PhoneService = s.PhoneService
       AND ds.MultipleLines = s.MultipleLines
       AND ds.InternetService = s.InternetService
       AND ds.OnlineSecurity = s.OnlineSecurity
       AND ds.OnlineBackup = s.OnlineBackup
       AND ds.DeviceProtection = s.DeviceProtection
       AND ds.TechSupport = s.TechSupport
       AND ds.StreamingTV = s.StreamingTV
       AND ds.StreamingMovies = s.StreamingMovies;

    INSERT INTO dbo.FactCustomerChurn
    (
        customerID,
        TenureKey,
        ContractKey,
        PaymentKey,
        ServiceKey,
        TenureMonths,
        MonthlyCharges,
        TotalCharges,
        Churn_Flag
    )
    SELECT
        s.customerID,
        dt.TenureKey,
        dc.ContractKey,
        dp.PaymentKey,
        ds.ServiceKey,
        CONVERT(tinyint, s.TenureMonths),
        s.MonthlyCharges,
        s.TotalCharges,
        CONVERT(bit, s.ChurnFlag)
    FROM #CustomerSource AS s
    INNER JOIN dbo.DimTenure AS dt
        ON dt.TenureGroup = s.TenureGroup
    INNER JOIN dbo.DimContract AS dc
        ON dc.ContractName = s.ContractName
    INNER JOIN dbo.DimPayment AS dp
        ON dp.PaymentMethod = s.PaymentMethod
    INNER JOIN dbo.DimService AS ds
        ON ds.PhoneService = s.PhoneService
       AND ds.MultipleLines = s.MultipleLines
       AND ds.InternetService = s.InternetService
       AND ds.OnlineSecurity = s.OnlineSecurity
       AND ds.OnlineBackup = s.OnlineBackup
       AND ds.DeviceProtection = s.DeviceProtection
       AND ds.TechSupport = s.TechSupport
       AND ds.StreamingTV = s.StreamingTV
       AND ds.StreamingMovies = s.StreamingMovies
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.FactCustomerChurn AS existing
        WHERE existing.customerID = s.customerID
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
END
ELSE
BEGIN
    PRINT N'Staging vacia; se omite la carga. Configure @CsvPath o importe el CSV antes de ejecutar para poblar el modelo.';
END;
GO

-- 6. Data Quality Checks
SELECT COUNT_BIG(*) AS StagingRows
FROM dbo.StgCustomerChurn;

SELECT COUNT_BIG(*) AS FactCustomerRows
FROM dbo.FactCustomerChurn;

-- Cada valor distinto de cero indica una clave dimensional sin correspondencia.
SELECT
    SUM(CASE WHEN dt.TenureKey IS NULL THEN CONVERT(bigint, 1) ELSE 0 END)
        AS MissingTenureDimensionKeys,
    SUM(CASE WHEN dc.ContractKey IS NULL THEN CONVERT(bigint, 1) ELSE 0 END)
        AS MissingContractDimensionKeys,
    SUM(CASE WHEN dp.PaymentKey IS NULL THEN CONVERT(bigint, 1) ELSE 0 END)
        AS MissingPaymentDimensionKeys,
    SUM(CASE WHEN ds.ServiceKey IS NULL THEN CONVERT(bigint, 1) ELSE 0 END)
        AS MissingServiceDimensionKeys
FROM dbo.FactCustomerChurn AS f
LEFT JOIN dbo.DimTenure AS dt ON dt.TenureKey = f.TenureKey
LEFT JOIN dbo.DimContract AS dc ON dc.ContractKey = f.ContractKey
LEFT JOIN dbo.DimPayment AS dp ON dp.PaymentKey = f.PaymentKey
LEFT JOIN dbo.DimService AS ds ON ds.ServiceKey = f.ServiceKey;

SELECT
    COUNT_BIG(*) AS FactRows,
    SUM(CONVERT(bigint, f.Churn_Flag)) AS ChurnedCustomers,
    SUM(CASE WHEN f.TotalCharges IS NULL THEN CONVERT(bigint, 1) ELSE 0 END)
        AS NullTotalCharges
FROM dbo.FactCustomerChurn AS f;

-- 7. Analytical Queries
-- Distribucion del resultado observado en el snapshot.
SELECT
    CASE f.Churn_Flag WHEN 1 THEN N'Yes' ELSE N'No' END AS Churn,
    COUNT_BIG(*) AS Customers,
    CAST(COUNT_BIG(*) * 1.0 / NULLIF(SUM(COUNT_BIG(*)) OVER (), 0) AS decimal(9,4))
        AS ShareOfCustomers
FROM dbo.FactCustomerChurn AS f
GROUP BY f.Churn_Flag
ORDER BY f.Churn_Flag;

-- Churn observado por grupo de antiguedad.
WITH CohortCounts AS
(
    SELECT
        dt.TenureGroup,
        dt.GroupSortOrder,
        COUNT_BIG(*) AS Customers,
        SUM(CONVERT(bigint, f.Churn_Flag)) AS ChurnedCustomers
    FROM dbo.FactCustomerChurn AS f
    INNER JOIN dbo.DimTenure AS dt ON dt.TenureKey = f.TenureKey
    GROUP BY dt.TenureGroup, dt.GroupSortOrder
)
SELECT
    TenureGroup,
    Customers,
    ChurnedCustomers,
    CAST(ChurnedCustomers * 1.0 / NULLIF(Customers, 0) AS decimal(9,4))
        AS ChurnRate,
    CAST(1.0 - ChurnedCustomers * 1.0 / NULLIF(Customers, 0) AS decimal(9,4))
        AS RetentionRate
FROM CohortCounts
ORDER BY GroupSortOrder;

-- Churn observado por tipo de contrato.
WITH ContractCounts AS
(
    SELECT
        dc.ContractName,
        dc.SortOrder,
        COUNT_BIG(*) AS Customers,
        SUM(CONVERT(bigint, f.Churn_Flag)) AS ChurnedCustomers
    FROM dbo.FactCustomerChurn AS f
    INNER JOIN dbo.DimContract AS dc ON dc.ContractKey = f.ContractKey
    GROUP BY dc.ContractName, dc.SortOrder
)
SELECT
    ContractName,
    Customers,
    ChurnedCustomers,
    CAST(ChurnedCustomers * 1.0 / NULLIF(Customers, 0) AS decimal(9,4))
        AS ChurnRate,
    CAST(1.0 - ChurnedCustomers * 1.0 / NULLIF(Customers, 0) AS decimal(9,4))
        AS RetentionRate
FROM ContractCounts
ORDER BY SortOrder;

-- Churn observado por metodo de pago.
WITH PaymentCounts AS
(
    SELECT
        dp.PaymentMethod,
        COUNT_BIG(*) AS Customers,
        SUM(CONVERT(bigint, f.Churn_Flag)) AS ChurnedCustomers
    FROM dbo.FactCustomerChurn AS f
    INNER JOIN dbo.DimPayment AS dp ON dp.PaymentKey = f.PaymentKey
    GROUP BY dp.PaymentMethod
)
SELECT
    PaymentMethod,
    Customers,
    ChurnedCustomers,
    CAST(ChurnedCustomers * 1.0 / NULLIF(Customers, 0) AS decimal(9,4))
        AS ChurnRate,
    CAST(1.0 - ChurnedCustomers * 1.0 / NULLIF(Customers, 0) AS decimal(9,4))
        AS RetentionRate
FROM PaymentCounts
ORDER BY ChurnRate DESC;

-- Analisis combinado de InternetService y TechSupport.
WITH ServiceCounts AS
(
    SELECT
        ds.InternetService,
        ds.TechSupport,
        COUNT_BIG(*) AS Customers,
        SUM(CONVERT(bigint, f.Churn_Flag)) AS ChurnedCustomers
    FROM dbo.FactCustomerChurn AS f
    INNER JOIN dbo.DimService AS ds ON ds.ServiceKey = f.ServiceKey
    GROUP BY ds.InternetService, ds.TechSupport
)
SELECT
    InternetService,
    TechSupport,
    Customers,
    ChurnedCustomers,
    CAST(ChurnedCustomers * 1.0 / NULLIF(Customers, 0) AS decimal(9,4))
        AS ChurnRate,
    CAST(1.0 - ChurnedCustomers * 1.0 / NULLIF(Customers, 0) AS decimal(9,4))
        AS RetentionRate
FROM ServiceCounts
ORDER BY ChurnRate DESC, InternetService, TechSupport;

-- Relacion descriptiva entre MonthlyCharges y resultado observado.
WITH ChargeStats AS
(
    SELECT
        f.Churn_Flag,
        COUNT_BIG(*) OVER (PARTITION BY f.Churn_Flag) AS Customers,
        AVG(f.MonthlyCharges) OVER (PARTITION BY f.Churn_Flag)
            AS MeanMonthlyCharges,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.MonthlyCharges)
            OVER (PARTITION BY f.Churn_Flag) AS MedianMonthlyCharges,
        ROW_NUMBER() OVER
            (PARTITION BY f.Churn_Flag ORDER BY f.CustomerChurnKey) AS RowNumber
    FROM dbo.FactCustomerChurn AS f
)
SELECT
    CASE Churn_Flag WHEN 1 THEN N'Yes' ELSE N'No' END AS Churn,
    Customers,
    MeanMonthlyCharges,
    MedianMonthlyCharges
FROM ChargeStats
WHERE RowNumber = 1
ORDER BY Churn_Flag;

-- Matriz observada de retencion por grupo de antiguedad y contrato.
WITH RetentionCounts AS
(
    SELECT
        dt.TenureGroup,
        dt.GroupSortOrder,
        dc.ContractName,
        dc.SortOrder AS ContractSortOrder,
        COUNT_BIG(*) AS Customers,
        SUM(CONVERT(bigint, f.Churn_Flag)) AS ChurnedCustomers
    FROM dbo.FactCustomerChurn AS f
    INNER JOIN dbo.DimTenure AS dt ON dt.TenureKey = f.TenureKey
    INNER JOIN dbo.DimContract AS dc ON dc.ContractKey = f.ContractKey
    GROUP BY
        dt.TenureGroup,
        dt.GroupSortOrder,
        dc.ContractName,
        dc.SortOrder
)
SELECT
    TenureGroup,
    ContractName,
    Customers,
    ChurnedCustomers,
    CAST(1.0 - ChurnedCustomers * 1.0 / NULLIF(Customers, 0) AS decimal(9,4))
        AS RetentionRate
FROM RetentionCounts
ORDER BY GroupSortOrder, ContractSortOrder;
GO