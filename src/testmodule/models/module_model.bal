const EMPLOYEE_CREATE_ERROR = "{dilhashanazeer/testmodule}EmployeeCreateError";

type EmployeeCreateError error<EMPLOYEE_CREATE_ERROR, record {|string message; error cause?;|}>;

public type Employee object {
    public string orgName;
    public string name;
    public string designation;

    public function __init(string orgName, string name, string designation) returns EmployeeCreateError? {
        self.orgName = orgName;
        self.name = name;
        self.designation = designation;
    }

    public function toString() returns string {
        return string `${self.orgName}/${self.name}:_${self.designation}`;
    }

    public function toJson() returns json {
        json employeeJson = {
            orgName: self.orgName,
            name: self.name,
            designation: self.designation
        };

        return employeeJson;
    }
};

type EmployeeRecord record {|
    string orgName;
    string name;
    string designation;
|};
