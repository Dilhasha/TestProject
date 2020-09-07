import ballerina/config;
import ballerina/log;
import ballerinax/java.jdbc;

const DB_EMPLOYEE_NOT_FOUND = "{dilhashanazeer/testmodule}DBEmployeeNotFound";
const DB_INVALID_DDL = "{dilhashanazeer/testmodule}DBInvalidDDL";
const DB_SQL_ERROR = "{dilhashanazeer/testmodule}DBSQLError";
type DBEmployeeNotFound error<DB_EMPLOYEE_NOT_FOUND, record {|string message; error cause?;|}>;
type DBInvalidDDL error<DB_INVALID_DDL, record {|string message; error cause?;|}>;
type DBSQLError error<DB_SQL_ERROR, record {|string message; error cause;|}>;

jdbc:Client testDBCon = new ({
    url: config:getAsString("DB_URL", "jdbc:mysql://localhost:3306/TESTDB?useSSL=false"),
    username: config:getAsString("DB_USERNAME", "user"),
    password: config:getAsString("DB_PASSWORD", "password"),
    poolOptions: {maximumPoolSize: config:getAsInt("DB_MAX_POOL_SIZE", 100)}
});

function insertEmployeeToDB(Employee employee) returns DBSQLError? {
    log:printDebug(string `inserting employee to db: ${employee.toString()}`);
    jdbc:UpdateResult|error insertEmployee = testDBCon->update("INSERT INTO EMPLOYEE_DETAILS" +
        "(ORG_NAME, NAME,DESIGNATION) " +
        "VALUES (?,?,?)",
        employee.orgName, employee.name, employee.designation);
    if (insertEmployee is jdbc:UpdateResult) {
        log:printDebug(string `inserted employee to db: ${employee.toString()}`);
        return;
    } else {
        DBSQLError insertError = error(DB_SQL_ERROR, message = "error inserting employee to db store: " + employee.toString(), cause = insertEmployee);
        return insertError;
    }
}

function getEmployeeFromDB(string orgName, string name, string designation) returns Employee|DBSQLError|DBEmployeeNotFound|DBInvalidDDL {
    log:printDebug(string `getting from db: ${orgName}/${name}:${designation}`);
    var employeeTable = testDBCon->select("SELECT ORG_NAME, NAME, DESIGNATION " +
        "FROM EMPLOYEE_DETAILS " +
        "WHERE ORG_NAME=? " +
        "AND NAME=? " +
        "AND DESIGNATION=?", EmployeeRecord,
        orgName, name, designation);
    if (employeeTable is table<EmployeeRecord>) {
        Employee? employee = ();
        foreach EmployeeRecord m in employeeTable {
            if (employee is ()) {
                employee = recordToEmployee(m);
                if (employee is Employee) {
                    log:printDebug(string `employee found from db: ${employee.toString()}`);
                    return employee;
                }
            } else {
                DBInvalidDDL multipleEmployeesFound = error(DB_INVALID_DDL, message = string `more than one employee found in db store: ${orgName}/${name}:${designation}`);
                return multipleEmployeesFound;
            }
        }

        if (employee is Employee) {
            return employee;
        } else {
            DBEmployeeNotFound employeeNotFound = error(DB_EMPLOYEE_NOT_FOUND, message = string `employee not found in db store: ${orgName}/${name}:${designation}`);
            return employeeNotFound;
        }
    } else {
        DBSQLError employeeGetError = error(DB_SQL_ERROR, message = string `error getting employee from db store: ${orgName}/${name}:${designation}`, cause = <error>employeeTable);
        return <@untainted>employeeGetError;
    }
}

function recordToEmployee(EmployeeRecord employeeRecord) returns Employee {
    Employee employee = checkpanic new Employee(employeeRecord.orgName,
        employeeRecord.name,
        employeeRecord.designation);
    return employee;
}
