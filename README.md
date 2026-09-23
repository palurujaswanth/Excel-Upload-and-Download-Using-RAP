# Excel Upload & Download Using SAP BTP ABAP RAP

A full-stack, transactional enterprise application developed using the **SAP RESTful Application Programming Model (RAP)** on **SAP BTP ABAP Environment**. This solution enables business users to dynamically generate and download standardized `.xlsx` templates, ingest spreadsheet records via binary streaming using the native **XCO Library**, perform schema and key-matching validations, and persist child line items transactionally through Fiori Elements.

---

##  Key Features

* **Dynamic Excel Template Export (`DownloadExcel`)**:
  * Generates formatted `.xlsx` templates dynamically at runtime using `xco_cp_xlsx` write operations without relying on pre-stored static files.
  * Auto-populates root entity file attachments and synchronizes UI template availability states (`TemplateStatus`).

* **Direct Binary Ingestion (`uploadExcelData`)**:
  * Reads raw attachment streams directly from the database table (`ztdb_user_parent`) and extracts rows using coordinate-bound pattern selections (`A1:E`)
  * Eliminates third-party transformation tools by using the native ABAP Cloud XCO XLSX library.

* **Strict Validation & Data Normalization Engine**:
  * **Header Validation**: Verifies all 5 mandatory columns (`User Id`, `Development Id`, `Development Description`, `Object Type`, `Object Name`) with uppercase normalization and whitespace trimming.
  * **Key Normalization**: Solves leading-zero mismatches across numeric domain keys (`NUMC` screen keys vs. raw unpadded spreadsheet strings).
  * **Sanitization**: Filters out empty or corrupted spreadsheet rows automatically.

* **Transactional Child Record Persistence**:
  * Uses association-based transactional modification (`MODIFY ENTITIES ... CREATE BY \_UserDev`).
  * Automatically assigns sequential line item keys (`SerialNo`) and wipes obsolete records before committing new rows.

* **Dynamic UX & Instance Feature Control**:
  * **Determinations**: Auto-calculates lifecycle statuses (`File Selected`, `Excel Uploaded`, `Template Present/Absent`) upon attachment modification.
  * **Dynamic Feature Control**: Toggles the availability of action buttons based on real-time instance state.
  * **UI Criticality**: Highlights lifecycle statuses with standard SAP Fiori color codes.

---

## 🏗️ Technical Architecture & Data Model

### 1. Persistence Layer (Transparent Tables)
* **Parent Table (`ztdb_user_parent`)**: Stores header keys (`emp_id`, `dev_id`), development details, attachment binary stream (`attachment`), MIME type, and administrative timestamps.
* **Child Table (`zt2123_user_dev`)**: Stores line-item child objects (`emp_id`, `dev_id`, `serial_no`, `object_type`, `object_name`).

### 2. Core Data Services (CDS) Layer
* **`zi_user_pc`**: Parent Interface Root CDS View Entity establishing the composition hierarchy to `_UserDev`.
* **`ZI_user_c`**: Child Interface CDS View Entity defining line item properties and association back to `_User`.
* **`ZC_USER_P`**: Parent Projection/Consumption View exposed for transactional consumption.
* **`ZC_USER_C`**: Child Projection/Consumption View.

### 3. Behavior Layer (RAP Managed Scenario)
* **`zi_user_pc` (BDEF)**: Defines managed lifecycle operations, determinations (`FillFileStatus`, `FillSelectedStatus`), instance feature control, and custom actions.
* **`zbp_i_user_pc` (Behavior Pool Class)**: Contains handler methods for:
  * `DownloadExcel`: Populates and writes the Excel template binary stream.
  * `uploadExcelData`: Parses spreadsheet cells, validates headers/keys, and creates child records via composition.
  * `get_instance_features`: Enables/disables actions dynamically.

---

## 📋 Spreadsheet Structure

The system expects an `.xlsx` workbook where the first sheet follows this exact schema:

| Column A | Column B | Column C | Column D | Column E |
| :--- | :--- | :--- | :--- | :--- |
| **User Id** | **Development Id** | **Development Description** | **Object Type** | **Object Name** |
| `1100` | `SAP0011` | `Upload In Excel` | `Table` | `ZTDB_CUSTOM_TAB` |
| `1100` | `SAP0011` | `Upload In Excel` | `Class` | `ZCL_TEST_SERVICE` |
| `1100` | `SAP0011` | `Upload In Excel` | `Structure` | `ZS_EMPLOYEE_DATA` |

>  **Note**: Rows must match the `User Id` and `Development Id` of the currently open parent Object Page.

---
## The Architecture of The Project
<img width="1070" height="1470" alt="image" src="https://github.com/user-attachments/assets/5fc4790d-0107-4735-b4a0-abe46ddc73f8" />
---
---

## 💻 Tech Stack

* **Platform**: SAP BTP ABAP Environment (ABAP Cloud)
* **Development Tool**: ABAP Development Tools (ADT) in Eclipse
* **Architecture**: ABAP RESTful Application Programming Model (RAP)
* **Office Integration**: SAP XCO Library (`xco_cp_xlsx`)
* **UI**: SAP Fiori Elements (List Report & Object Page)
* **Protocol**: OData V2 / V4 via Business Service Binding

---

## 🛠️ How to Test in the Fiori UI

1. Open the **Fiori Elements List Report** preview from your Service Binding.
2. Click **Create** or open an existing parent record (e.g., `1100` / `SAP0011`).
3. Click the **Download Excel** action button in the header toolbar to fetch the formatted template.
4. Fill in the required child line items in the spreadsheet and save as `.xlsx`.
5. On the Object Page, click **Edit**, choose the file under **Choose Excel File**, and click **Save**.
6. Click **Upload Data**.
7. The status updates to **Excel Uploaded**, and all line items immediately populate the **Developed Objects** table.

---

##  Author
* **Paluru Jaswanth**
* GitHub: [@palurujaswanth](https://github.com/palurujaswanth)



