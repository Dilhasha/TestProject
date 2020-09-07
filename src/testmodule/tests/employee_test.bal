import ballerina/config;
import ballerina/http;
import ballerina/io;
import ballerina/system;
import ballerina/test;
import ballerinax/java.jdbc;

boolean hasEmployeeDetailsTable = false;

http:Client employeeAPIEP = new ("https://localhost:9090", config = {
    secureSocket: {
        trustStore: {
            path: config:getAsString("TRUSTSTORE_FILE", system:getEnv("BALLERINA_HOME") + "/bre/security/ballerinaTruststore.p12"),
            password: config:getAsString("TRUSTSTORE_PASSWORD", "xxxxxxx")
        },
        verifyHostname: false
    }
});

type InfoSchemaTable record {
    string TABLE_CATALOG;
    string TABLE_SCHEMA;
    string TABLE_NAME;
};

@test:BeforeSuite
public function createDatabaseTable() returns DBSQLError? {
    var testTableExistsQuery = checkpanic testDBCon->select("SELECT TABLE_CATALOG,TABLE_SCHEMA, TABLE_NAME " +
        "FROM information_schema.tables " +
        "WHERE TABLE_SCHEMA = 'TESTDB' " +
        "AND TABLE_NAME = 'EMPLOYEE_DETAILS' " +
        "LIMIT 1;", InfoSchemaTable);
    foreach InfoSchemaTable registryTable in <table<InfoSchemaTable>>testTableExistsQuery {
        hasEmployeeDetailsTable = true;
    }
    if (!hasEmployeeDetailsTable) {
        // If EMPLOYEE_DETAILS table does not exists then create the table
        io:ReadableCharacterChannel sqlInitScriptChannel =
            new (checkpanic io:openReadableFile("src/testmodule/resources/dbscripts/mysql-init.sql"), "UTF-8");
        string sql = checkpanic sqlInitScriptChannel.read(2000);
        jdbc:UpdateResult tableCreated = checkpanic testDBCon->update(<@untainted>sql);
        hasEmployeeDetailsTable = true;
        //Insert sample data for testing
        var employee = getEmployee();
        if (employee is Employee) {
            DBSQLError? insertError = insertEmployeeToDB(employee);
            if (insertError is DBSQLError) {
                return insertError;
            }
        }
    }
}

@test:BeforeSuite
public function mockTestDbClient() {
    string orgName = "WSO2";
    string name = "Dilhasha";
    string designation = "Engineer";
    table<EmployeeRecord>|DBSQLError EmployeeRecordTable = getSingleRecordList(orgName, name, designation);
    if (EmployeeRecordTable is table<EmployeeRecord>) {
        testDBCon = <jdbc:Client>(test:mock(jdbc:Client));
        test:prepare(testDBCon).when("update").thenReturn(getUpdateResult());
        test:prepare(testDBCon).when("select").thenReturn(EmployeeRecordTable);
    }
}

public function getSingleRecordList(string orgName, string name, string designation)
returns @tainted table<EmployeeRecord>|DBSQLError {
    if (!hasEmployeeDetailsTable) {
        DBSQLError? dbCreateError = createDatabaseTable();
        if (dbCreateError is DBSQLError) {
            return dbCreateError;
        }
    }
    var employeeTable = testDBCon->select("SELECT ORG_NAME, NAME, DESIGNATION " +
        "WHERE ORG_NAME=? " +
        "AND NAME=? " +
        "AND DESIGNATION=?", EmployeeRecord, orgName, name, designation);
    if (employeeTable is table<EmployeeRecord>) {
        return employeeTable;
    } else {
        DBSQLError employeeGetError = error(DB_SQL_ERROR, message = string `error getting employee from db store`,
            cause = <error>employeeTable);
        return employeeGetError;
    }
}

public function getUpdateResult() returns jdbc:UpdateResult {
    jdbc:UpdateResult response = {"updatedRowCount": 1, "generatedKeys": {}};
    return response;
}

@test:Config {}
public function pushEmployeeTest() {
    http:Request pushReq = new;
    pushReq.setHeader("JWT-TOKEN", "eyJhbGciOiJSUzI1NiIsICJ0eXAiOiJKV1QifQ==.eyJzdWIiOiJqb2hudyIsICJpc3MiOiJiYWxsZXJpbmEiLCAiZXhwIjoxNTYyODI3MTE5Njg5LCAiaWF0IjoxNTYyODI3MDg5Njg5LCAianRpIjoiNWUzOTRmOWMtM2VjYS00NjNlLThkY2QtOWNjYjdmYzExYzdjIiwgImF1ZCI6WyJodHRwczovL2xvY2FsaG9zdDo5NDQzIl0sICJlbWFpbCI6ImFkbWluQHdzbzIuY29tIiwgIndlYnNpdGUiOiJodHRwczovL3dzbzIuY29tIiwgIm5hbWUiOiJhZG1pbiIsICJmYW1pbHlfbmFtZSI6ImFkbWluIiwgInByZWZlcnJlZF91c2VybmFtZSI6ImFkbWluIiwgImdpdmVuX25hbWUiOiJhZG1pbiIsICJwcm9maWxlIjoiaHR0cHM6Ly93c28yLmNvbSIsICJjb3VudHJ5IjoiU3JpIExhbmthIiwgIm9yZ2FuaXphdGlvbnMiOlt7Im9yZ05hbWUiOiJmb28ifV19.I5b3R3NLRYsf-WHi9DusEs1QK_9IF7MrP8zipvyU5HpwYEq8Zu8CEzKWFls-m1vN_1dGmvYJ_X84DXXajb1DGynb_nntNH_6MnFJn6YBJyZRBiUfn-dudGld1N2ygXYj2Gk26svoJmJSN0t76uDTIH8hhytHNqSOCJ5Cfwz9gG3JtjEkMd3Z2qopg3ToTQj_bUNRxhDeEtPU5ZBEZmZYPfs8ZUwpe6GZsjpWdPodKu-d7fEpG_-bS2AsB_S2075OijyFLcbpDF1jPbGelKlyTgNQlOQ7JlvxL1b2xayiPljc_uwNQEk9FDFqws0XlU054b882R1bK4c6z2tzuR5jhA==");
    http:Response resp = checkpanic employeeAPIEP->post("/employees/", pushReq);
    json moduleJson = checkpanic resp.getJsonPayload();
    test:assertEquals(moduleJson.orgName, "WSO2");
    test:assertEquals(moduleJson.name, "Dilhasha");
    test:assertEquals(moduleJson.designation, "Engineer");
}
