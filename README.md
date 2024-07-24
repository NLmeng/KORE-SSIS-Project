# MINT-SSIS-HomeTask

## Setup Instructions

#### 1. Clone the Repository

#### 2. Restore the Database Backup

- Find and unzip the Zipped `.bak` file in [`Backup` dir](https://github.com/NLmeng/KORE-SSIS-Project/tree/main/Backup)
- Open **SQL Server Management Studio (SSMS)**.
- Connect to your SQL Server instance.
- Right-click on **Databases** and select **Restore Database...**.
- In the **Source** section, select **From device** and click the ellipsis button (...).
- Click **Add** then find and use the provided `.bak` file.
- Click **OK** to restore the database.

Troubleshoot

- Verify necessary permission for the directories being read to.
- Use the latest (newest) backup from the `.bak` if somehow there are multiple.

#### 3. Open the SSIS Solution

- Open **SQL Server Data Tools (SSDT)** or **Microsoft Visual Studio**.
- Go to **File > Open > Project/Solution**.
- Navigate to the cloned repository and select the `.sln` file found in [`SSIS` dir](https://github.com/NLmeng/KORE-SSIS-Project/tree/main/SSIS) to open the SSIS solution.

#### 4. Configure the Connection Managers

- In SSDT, open the SSIS package (typically a `.dtsx` file).
- Right-click on each **Connection Manager** at the bottom of the screen and select **Edit**.
- Update the connection strings to point to your SQL Server instance and the location of your CSV file. There should be 2 connection strings, one for SQL Server and one for CSV connection.
  - for SQL Server: Update the server or file name to your own server that you just used to restore the database (Under `Initial Catalog` should be `KoreAssignment_Lymeng_Naret` if name unchanged when restoring).
  - for CSV: Update the file path to the location of your CSV file (also found in [`Data` dir](https://github.com/NLmeng/KORE-SSIS-Project/tree/main/Data)). (Code page should be kept 65001 (UTF-8) to avoid issues)

#### 5. Execute the SSIS Package

- In SSDT, right-click on the SSIS package or `.dtsx` and select **Execute Package**.
- You can verify manually via SSDT tool or using the scripts provided [here](https://github.com/NLmeng/KORE-SSIS-Project/tree/main/SQLScripts)

#### Executing the SSIS Package

NOTE: you may find more records than expected as the backuped database already had some records previously. however, the production table should still remain the same given that you executed on the same CSV.

## Task Process

### 1. Extract and Load to Staging

**Overview**: extract data from a CSV file, transform it, and load it into a staging table with appropriate data types.

#### Steps:

1. **Flat File Source**: reads data from the CSV file (also found in this repo's `Data` dir).

   - **Configuration**:
     - Set the file path to the CSV file.
     - Ensure column names in the first data row are checked.
     - All columns initially read as `DT_STR` (string).
     - I chose to use Flat File Source because we need to handle a CSV File, and in order to keep consistent between an empty field and a field with the string "null," I added a script to make them the same.

2. **Derived Column Transformation - Null Validation**:

   - **Configuration**:
     - For each column, set an expression to check if data conversion is possible or not.
     - Examples:
       - `UserID`: `(DT_I4)UserID == (DT_I4)UserID ? (DT_I4)UserID : NULL(DT_I4)`

3. **Data Conversion Transformation**: converts columns to appropriate data types.

   - **Configuration**:
     - Convert each column from `DT_STR` to an appropriate data type.
     - Examples:
       - `UserID`: `four-byte signed integer [DT_I4]`

4. **OLE DB Destination - Destination Staging**: loads the transformed data into the staging table.
   - **Configuration**:
     - Set the destination table to `stg.Users`.
     - Map the columns from the data conversion output to the staging table columns.

#### Outcomes:

- **Successful Records**:
  - Successfully extracted, transformed, and loaded into the `stg.Users` table.

### 2. Data Cleaning: Remove Duplicates

**Overview**: identify and remove duplicate records in the staging table based on the UserID, ensuring to keep track (assuming we want to sum the total) of the total purchase amount, the oldest registration date, and the most recent login date.

#### Steps:

1. **Execute SQL Task: Transform - Remove Duplicates**: executes SQL statements to remove duplicate records in the `stg.Users` table, keeping the relevant information. I merged dupes with the same UserID by summing purchase total, keep min reg date, keep max log date, and keep other info same as the entry with max login date.

2. **SQL Script**:

   ```sql
   -- Assuming we want to keep track (sum) of all purchases, it also makes sense to keep the oldest registration date and the newest login date
   ;WITH CTE AS (
       SELECT
           UserID,
           MIN(RegistrationDate) AS MinRegistrationDate,
           MAX(LastLoginDate) AS MaxLoginDate,
           SUM(PurchaseTotal) AS TotalPurchase
       FROM
           stg.Users
       GROUP BY
           UserID
   ),

   -- Filter for the one entry to keep (use for eliminating duplicates later)
   DataToKeep AS (
       SELECT
           stg.UserID,
           stg.FullName,
           stg.Age,
           stg.Email,
           stg.StgID,
           CTE.MinRegistrationDate AS RegistrationDate,
           CTE.MaxLoginDate AS LastLoginDate,
           CTE.TotalPurchase AS PurchaseTotal,
           ROW_NUMBER() OVER (PARTITION BY stg.UserID ORDER BY stg.LastLoginDate DESC, stg.StgID DESC) AS RowNum
       FROM
           stg.Users stg
       INNER JOIN
           CTE ON stg.UserID = CTE.UserID
   )

   -- Store results in a temporary table for scoping
   SELECT *
       INTO #TempDataToKeep
       FROM DataToKeep;

   -- Delete duplicates
   DELETE u
       FROM stg.Users u
       INNER JOIN #TempDataToKeep t ON u.UserID = t.UserID AND u.StgID = t.StgID
       WHERE t.RowNum > 1;

   -- Update the data back into the stg.Users table
   UPDATE u
       SET
           u.RegistrationDate = t.RegistrationDate,
           u.LastLoginDate = t.LastLoginDate,
           u.PurchaseTotal = t.PurchaseTotal
       FROM stg.Users u
       INNER JOIN #TempDataToKeep t ON u.UserID = t.UserID
       WHERE t.RowNum = 1;

   -- Clean the temporary table
   DROP TABLE #TempDataToKeep;
   ```

#### Outcomes:

- **Successful Records**:
  - Duplicate records are removed while retaining essential information like the total purchase amount, the oldest registration date, and the most recent login date.

### 3. Data Cleaning: Error Handling

**Overview**: isolate and handle records that do not meet data quality standards by directing them to an error table.

#### Steps:

1. **Conditional Split Transformation**: direct rows to different outputs based on specified conditions to identify error records. Create error handling for invalid records. Remove if: null UserID, null RegistrationDate, null FullName, null Email, null or non-positive Age, null or negative PurchaseTotal, future LastLoginDate, future RegistrationDate, RegistrationDate after LastLoginDate, invalid email format (missing "@" or ".").

2. **OLE DB Destination - Users_Errors**: writes error records to the `stg.Users_Errors` table.

   - **Configuration**:
     - Set the destination table to `stg.Users_Errors`.
     - Map columns from the conditional split output to the error table columns.

3. **OLE DB Source - Users**: Reads data from the `stg.Users` table.

   - **Configuration**:
     - Connect to the `stg.Users` table to fetch records for error handling.

4. **Union All Transformation**: combines multiple error outputs into a single flow before directing them to the error table.
   - **Configuration**:
     - Combine outputs from the Conditional Split to handle various error types.

#### Error Handling:

- **General**:
  - Redirects rows with errors to the `stg.Users_Errors` table adn ensures that records with data quality issues are isolated for further review.

#### Outcomes:

- **Error Records**:
  - Records with data quality issues are redirected to the `stg.Users_Errors` table.

### 4. Data Cleaning: Isolation of Error Records

**Overciew**: remove records from the `stg.Users` table that have been identified as error records and are present in the `stg.Users_Errors` table.

#### Steps:

1. **Execute SQL Task: Transform - Isolation** executes SQL statements to remove entries with errors from the `stg.Users` table.

   - **Configuration**:

     - Set the **ConnectionType** to **OLE DB**.
     - use the following SQL statement:

       ```sql
       -- Delete entries from stg.Users that are present in stg.Users_Errors
       DELETE u
       FROM stg.Users u
       INNER JOIN stg.Users_Errors e ON u.StgID = e.StgID;
       ```

### Outcomes:

- **Successful Records**:
  - Records that meet data quality standards (as defined in step 3.) remain in the `stg.Users` table.
- **Error Records**:
  - Records identified as errors are removed from the `stg.Users` table and inserted in the `stg.Users_Errors` table for further review.

### 5. Incremental Load to Production

**Overview**: load data from the staging table to the production table, ensuring that new records are inserted and existing records are updated based on the `UserID`.

#### Steps:

1. **OLE DB Source - Staging Users**: reads data from the `stg.Users` table.

   - **Configuration**:
     - Set the source table to `stg.Users`.
     - Select all relevant columns.

2. **Lookup Transformation**: Differentiates between new and existing records by matching `UserID` with the production table.

   - **Configuration**:
     - Set the connection to the production database.
     - Configure the lookup to match `UserID` in the `prod.Users` table.
     - Set the lookup to redirect rows with no matching entries to the **No Match Output** (new records).
     - Map the columns from the input to the lookup columns:

3. **OLE DB Destination - Production Users (Insert New Records)** Inserts new records into the `prod.Users` table.

   - **Configuration**:
     - Set the destination table to `prod.Users`.
     - Map the columns from the no match output to the destination columns.

4. **OLE DB Command - Production Users (Update Existing Records)**: updates existing records in the `prod.Users` table.

   - **Configuration**:

     - Set the connection to the production database.
     - use the following SQL statement:

       ```sql
       UPDATE prod.Users
       SET
           FullName = ?,
           Age = ?,
           Email = ?,
           RegistrationDate = ?,
           LastLoginDate = ?,
           PurchaseTotal = ?,
           RecordLastUpdated = GETDATE()
       WHERE UserID = ?
       ```

   - **Parameter Mapping**:
     - Map the following input columns to the corresponding parameters:
       - `FullName` to `Param_0`
       - `Age` to `Param_1`
       - `Email` to `Param_2`
       - `RegistrationDate` to `Param_3`
       - `LastLoginDate` to `Param_4`
       - `PurchaseTotal` to `Param_5`
       - `UserID` to `Param_6`

### Outcomes:

- New records are inserted into the `prod.Users` table.
- Existing records are updated with the latest data from the `stg.Users` table.
- Any errors encountered during the process are sent into `stg.Users_Errors` for further review.

### Result of Execution:

In the extraction stage, all 33 records are inserted into the staging table. In the first cleaning stage, 3 records are identified as duplicates and removed. At this stage, 2 records throw an error or cant be type casted, so they are sent to a database `dbo.Error_Log_For_Null_Validation` for manual inspection (one is non-number age and the other is a future date). Then, during the error handling stage, 8 records are found, whether because of null UserID, null/malformed Email, null registration date, negative or null age, negative purchase total, future dates, etc. In the incremental load stage, after removing the 3 duplicates and isolated the 10 records, there are 20 records left that will be loaded into production table. If the number of record differs, please see [NOTE](#executing-the-ssis-Package).

The most challenging part for me is definitely making my best assumption to come up with appropriate criteria such as what to filter out, what counts as error, what should be kept and sent to production table. I think this would be resolved in real-world by having a clear communication with the stakeholders and understanding the business requirements better, but since this is a home task, I had to make my best guess. It was also a bit of a challenge to handle the fail-path, for example I am unsure of how much to handle and the best practices for it. As a solution, I decided to create a new table `stg.Users_Errors` to insert malformed entries for manual inspection. There are also other `dbo.*` databases that I used to store results that caused an error during parts that I think may be crucial or sensitive.
