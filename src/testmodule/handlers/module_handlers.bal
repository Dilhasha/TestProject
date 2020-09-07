import ballerina/log;

const MODULE_NOT_FOUND_ERROR = "{dilhashanazeer/testmodule}EmployeeNotFound";
const USER_ERROR = "{dilhashanazeer/testmodule}UserError";
const SYSTEM_ERROR = "{dilhashanazeer/testmodule}SystemError";
type EmployeeNotFoundError error<MODULE_NOT_FOUND_ERROR, record {|string message; error cause?;|}>;
type UserError error<USER_ERROR, record {|string message; error cause?;|}>;
type SystemError error<SYSTEM_ERROR, record {|string message; error cause?;|}>;

function handlePush(Employee employee) returns Employee|UserError|SystemError {
    Employee|DBSQLError|DBEmployeeNotFound|DBInvalidDDL existingEmployee = getEmployeeFromDB(employee.orgName, employee.name, employee.designation);
    if (existingEmployee is Employee) {
        return existingEmployee;
    } else if (existingEmployee is DBSQLError || existingEmployee is DBInvalidDDL) {
        log:printError("error occurred when checking for existing employees: " + employee.toString(), err = existingEmployee);
        SystemError sysErr = error(SYSTEM_ERROR, message = "unexpected error occured while pushing employee: " + employee.toString());
        return sysErr;
    } else {
        UserError employeeAlreadyExistsError = error(USER_ERROR, message = "employee not available: " + existingEmployee.toString());
        return employeeAlreadyExistsError;
    }
}
