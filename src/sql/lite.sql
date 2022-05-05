WITH
transactions AS (
    SELECT
        t.ID                                                          AS charge_id,
        td.ID                                                         AS transaction_id,
        CONCAT(t.labtestidentifier, lc.longname, t.ProcedureID)       AS charge_key,
        td."Type"                                                     AS type_id,
        t.servicedate                                                 AS service_date,
        td.Amount                                                     AS charged_amount,
        t.cpt                                                         AS cpt_code,
        claim.payerid                                                 AS payer_id,
        claim.submitteddate                                           AS submitted_date,
        t.clientid                                                    AS client_id,
        t.providerid                                                  AS provider_id,
        td.postdate                                                   AS post_date,
        td.amount                                                     AS amount
    FROM dbo.tbltransaction_detail AS td WITH (nolock)
    LEFT JOIN dbo.tbltransaction AS t WITH (nolock)
        ON (t.id = td.transactionid)
    LEFT JOIN dbo.tbllabcompany AS lc WITH (nolock)
        ON (t.performinglabid = lc.id)
    LEFT JOIN dbo.tblclaims AS claim WITH (nolock)
        ON (td.claimid = claim.id)
),
transactions_payments_without_remittances AS (
   SELECT
       STRING_AGG(REPLACE(CAST(t.type_id AS CHAR(2)), ' ', ''), ';') WITHIN GROUP (ORDER BY t.type_id) AS type_list,
       charge_id
   FROM transactions AS t with (nolock)
   GROUP BY charge_id
   HAVING STRING_AGG(REPLACE(CAST(t.type_id AS CHAR(2)), ' ', ''), ';') WITHIN GROUP (ORDER BY t.type_id) NOT LIKE '%5%'
       AND STRING_AGG(REPLACE(CAST(t.type_id AS CHAR(2)), ' ', ''), ';') WITHIN GROUP (ORDER BY t.type_id) LIKE '%3%'
),
payments_without_remittances AS (
   SELECT
    t.charge_id,
    t.transaction_id,
    t.charge_key,
    t.type_id,
    t.service_date,
    t.charged_amount,
    t.cpt_code,
    t.payer_id,
    t.submitted_date,
    t.client_id,
    t.provider_id,
    t.post_date,
    t.amount
   FROM transactions_payments_without_remittances AS pwr with(nolock)
    LEFT JOIN transactions AS t with(nolock)
       ON (pwr.charge_id = t.charge_id)
   WHERE t.type_id = 3 --Payer Payments
       AND t.amount < 0 AND t.payer_id IS NOT NULL
),
charge_transactions_with_payments_without_remittances AS (
    SELECT t.* FROM transactions AS t with(nolock)
    WHERE t.type_id = 1 -- Charge
    UNION
    SELECT * FROM payments_without_remittances with(nolock)
),
charges AS (
    SELECT
        ct.charge_key,
        ct.transaction_id,
        ROW_NUMBER() OVER (PARTITION BY ct.charge_key ORDER BY ct.transaction_id DESC, ct.post_date DESC) AS seq
    FROM charge_transactions_with_payments_without_remittances AS ct WITH (nolock)
),
unique_transaction_advices AS (
    SELECT
        crta.TransactionDetailID AS transaction_id,
        crta.ClaimTransactionRemittanceID,
        crta.Code,
        td.postdate,
        td."Type",
        CONCAT(t.labtestidentifier, lc.longname, t.ProcedureID) AS charge_key,
        ROW_NUMBER() OVER (PARTITION BY CONCAT(t.labtestidentifier, lc.longname, t.ProcedureID) ORDER BY TransactionDetailID DESC, Code DESC, Sequence DESC) AS seq
    FROM dbo.tblclaim_remittance_transaction_advice AS crta WITH (nolock)
    INNER JOIN dbo.tbltransaction_detail AS td WITH (nolock)
        ON (crta.TransactionDetailID = td.ID)
    LEFT JOIN dbo.tbltransaction AS t WITH (nolock)
        ON (t.id = td.transactionid)
    LEFT JOIN dbo.tbllabcompany AS lc WITH (nolock)
        ON (t.performinglabid = lc.id)
    WHERE crta.Code IS NOT NULL
      AND crta.Code <> ' '
),
remittance_advices AS (
    SELECT
        remittance.ClaimTransactionRemittanceID,
        STRING_AGG(REPLACE(remittance.Code, ' ', ''), ';') WITHIN GROUP (ORDER BY remittance.Code) AS advice_list
    FROM unique_transaction_advices AS remittance WITH (nolock)
    GROUP BY remittance.ClaimTransactionRemittanceID
),
payers AS (
    SELECT
        payer.id AS id,
        payer.financialclassid,
        payer.code AS code,
        COALESCE(payer.LongName, payer.Name) AS name
    FROM dbo.tblpayer AS payer WITH (nolock)
),
unique_payers AS (
    SELECT DISTINCT
        id AS id,
        name AS name
    FROM payers WITH (nolock)
),
counted_payer_names AS (
    SELECT
        COUNT(id) AS num_occurrence,
        name AS name
    FROM unique_payers WITH (nolock)
    GROUP BY name
),
distinct_clients AS (
    SELECT DISTINCT
        t.id AS id,
        t.Name AS name
    FROM dbo.tblClient AS t WITH (nolock)
),
counted_client_names AS (
    SELECT
        COUNT(*) AS num_occurrence,
        name AS name
    FROM distinct_clients WITH (nolock)
    GROUP BY name
),
providers AS (
    SELECT
        id AS id,
        code AS code,
        RTRIM(
            CASE
                WHEN LEN(provider.firstname) > 0 THEN provider.firstname + ' '
                ELSE ''
            END +
            CASE
                WHEN LEN(provider.mi) > 0 THEN provider.mi + ' '
                ELSE ''
            END +
            CASE
                WHEN LEN(provider.lastname) > 0 THEN provider.lastname + ' '
                ELSE ''
            END +
            CASE
                WHEN LEN(provider.suffix) > 0 THEN provider.suffix + ' '
                ELSE ''
                END +
            CASE
                WHEN LEN(provider.degree) > 0 THEN provider.degree + ' '
                ELSE ''
            END
        ) AS name
    FROM dbo.tblprovider AS provider WITH (nolock)
),
distinct_providers AS (
    SELECT DISTINCT
        id AS id,
        name AS name
    FROM providers WITH (nolock)
),
counted_provider_names AS (
    SELECT
        COUNT(*) AS num_occurrence,
        name AS name
    FROM distinct_providers WITH (nolock)
    GROUP BY name
),
primary_diagnosis_code AS (
    SELECT
        CASE COALESCE(CHARINDEX(';', tdx.dxcode), 0)
            WHEN 0 THEN tdx.dxcode
            ELSE SUBSTRING(tdx.dxcode, 0, CHARINDEX(';', tdx.dxcode))
        END AS code,
        ct.transaction_id
    FROM charges AS ch WITH (nolock)
    LEFT JOIN charge_transactions_with_payments_without_remittances AS ct WITH (nolock)
        ON (ch.transaction_id = ct.transaction_id)
    LEFT JOIN (
        SELECT DISTINCT tdx2.transactionid,
            Substring(
                (
                    SELECT ';' + tdx1.dxcode AS [text()]
                    FROM dbo.tbltransaction_dx AS tdx1 WITH (nolock)
                    WHERE (tdx1.transactionid = tdx2.transactionid)
                    ORDER BY tdx1.transactionid, tdx1.sequence
                    FOR xml path ('')
                ), 2, 1000
            ) dxcode
        FROM dbo.tbltransaction_dx AS tdx2 WITH (nolock)
    ) AS tdx
        ON (ct.charge_id = tdx.transactionid)
)
SELECT
    ct.charge_id                                                               AS charge_id,
    ct.submitted_date                                                          AS submitted_date,
    CASE
        WHEN ct.type_id = 3 THEN ct.post_date
        ELSE crta.postdate
    END                                                                        AS remittance_date,
    ct.cpt_code                                                                AS cpt_code,
    pdc.code                                                                   AS diagnosis_code,
    CASE
        WHEN cpn.num_occurrence > 1 THEN CONCAT(cpn.name, CONCAT(' (', CONCAT(payer.code, ')')))
        ELSE cpn.name
    END                                                                        AS payer,
    ct.payer_id                                                                AS payer_id,
    fc.Description                                                             AS payer_group,
    CASE
        WHEN ccn.num_occurrence > 1 THEN CONCAT(ccn.name, CONCAT(' (', CONCAT(client.code, ')')))
        ELSE ccn.name
    END                                                                        AS client,
    ct.client_id                                                               AS client_id,
    CASE
        WHEN cprn.num_occurrence > 1 THEN CONCAT(cprn.name, CONCAT(' (', CONCAT(provider.code, ')')))
        ELSE cprn.name
    END                                                                        AS provider,
    ct.provider_id                                                             AS provider_id,
    CASE
        WHEN ((ra.advice_list IS NULL OR ra.advice_list = '') AND (type_id=3)) THEN 'PWA'
        ELSE ra.advice_list
    END                                                                        AS advice_list
FROM charges AS ch WITH (nolock)
LEFT JOIN charge_transactions_with_payments_without_remittances AS ct WITH (nolock)
    ON (ch.transaction_id = ct.transaction_id AND ch.seq = 1)
LEFT JOIN payers AS payer WITH (nolock )
    ON (ct.payer_id = payer.id)
LEFT JOIN counted_payer_names AS cpn WITH (nolock)
    ON (cpn.name = payer.name)
LEFT JOIN dbo.tblclient AS client WITH (nolock)
    ON (ct.client_id = client.id)
LEFT JOIN counted_client_names AS ccn WITH (nolock)
    ON (ccn.name = client.name)
LEFT JOIN dbo.tblfinancialclass AS fc WITH (nolock)
    ON (payer.financialclassid = fc.id)
LEFT JOIN unique_transaction_advices AS crta WITH (nolock)
    ON (ch.charge_key = crta.charge_key and crta.seq = 1)
LEFT JOIN remittance_advices AS ra WITH (nolock)
    ON (ra.ClaimTransactionRemittanceID = crta.ClaimTransactionRemittanceID)
LEFT JOIN providers AS provider WITH (nolock)
    ON (ct.provider_id = provider.id)
LEFT JOIN counted_provider_names AS cprn WITH (nolock)
    ON (cprn.name = provider.name)
LEFT JOIN primary_diagnosis_code AS pdc WITH (nolock)
    ON (pdc.transaction_id = ct.transaction_id)
WHERE payer_id IS NOT NULL;
