import ballerina/config;
import ballerina/http;
import ballerina/jwt;
import ballerina/log;
import ballerina/stringutils;
import ballerina/system;

const JWT_TOKEN_ERROR = "{dilhashanazeer/testmodule}JWTTokenError";

type JwtTokenError error<JWT_TOKEN_ERROR, record {|string message; error cause?;|}>;

listener http:Listener employeeEP = new (config:getAsInt("EMPLOYEE_API_SERVICE_PORT", 9090), config = {
    secureSocket: {
        keyStore: {
            path: config:getAsString("KEYSTORE_FILE", system:getEnv("BALLERINA_HOME") + "/bre/security/ballerinaKeystore.p12"),
            password: config:getAsString("KEYSTORE_PASSWORD", "ballerina")
        }
    }
});

@http:ServiceConfig {
    basePath: "/employees",
    cors: {
        allowOrigins: stringutils:split(config:getAsString("CORS_ORIGINS", "*"), ","),
        allowCredentials: true
    }
}
service employeeAPI on employeeEP {
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/"
    }
    resource function push(http:Caller caller, http:Request req) {
        http:Response res = new;
        string|JwtTokenError username = extractUsername(req);
        if (username is JwtTokenError) {
            log:printError("invalid request received.", err = username);
            json invalidUsername = {message: "invalid request received. " + username.detail()?.message};
            res.setJsonPayload(invalidUsername);
            res.statusCode = http:STATUS_BAD_REQUEST;
        } else {
            Employee|EmployeeCreateError newEmployee = getEmployee();
            if (newEmployee is EmployeeCreateError) {
                log:printError("unable to parse employee.", err = newEmployee);
                json invalidEmployee = {message: "invalid request received. " + newEmployee.detail()?.message};
                res.setJsonPayload(<@untainted>invalidEmployee);
                res.statusCode = http:STATUS_BAD_REQUEST;
            } else {
                Employee|UserError|SystemError insertedEmployee = <@untainted>handlePush(newEmployee);
                if (insertedEmployee is UserError) {
                    log:printError("invalid request received.", err = insertedEmployee);
                    json mimeErrJson = {message: insertedEmployee.detail()?.message};
                    res.setJsonPayload(<@untainted>mimeErrJson);
                    res.statusCode = http:STATUS_BAD_REQUEST;
                } else if (insertedEmployee is SystemError) {
                    log:printError("system error occurred.", err = insertedEmployee);
                    json errorJson = {message: "unexpected error occurred."};
                    res.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
                    res.setJsonPayload(errorJson);
                } else {
                    json insertedEmployeeJson = insertedEmployee.toJson();
                    res.setJsonPayload(<@untainted>insertedEmployeeJson);
                    res.statusCode = http:STATUS_OK;
                }
            }
        }

        error? responseToCaller = caller->respond(res);
        if (responseToCaller is error) {
            log:printError("error sending response to caller.", err = responseToCaller);
        }
    }
}

function extractUsername(http:Request req) returns string|JwtTokenError {
    if (!req.hasHeader("JWT-TOKEN")) {
        JwtTokenError jwtTokenMissingErr = error(JWT_TOKEN_ERROR, message = "cannot find JWT-TOKEN header.");
        return jwtTokenMissingErr;
    } else {
        string token = req.getHeader("JWT-TOKEN");
        jwt:JwtValidatorConfig validatorConfig = {
            issuer: "ballerina",
            audience: ["https://localhost:9443"],
            trustStoreConfig: {
                certificateAlias: "ballerina",
                trustStore: {
                    path: config:getAsString("TRUSTSTORE_FILE", system:getEnv("BALLERINA_HOME") + "/bre/security/ballerinaTruststore.p12"),
                    password: config:getAsString("TRUSTSTORE_PASSWORD", "ballerina")
                }
            }
        };

        jwt:JwtPayload|error jwtPayload = jwt:validateJwt(token, validatorConfig);
        if (jwtPayload is error) {
            log:printError("error validating JWT token. " + <string>jwtPayload.detail()?.message);
            JwtTokenError invalidJwtErr = error(JWT_TOKEN_ERROR, message = "invalid JWT token.");
            return invalidJwtErr;
        } else {
            string? userSubject = jwtPayload?.sub;
            if (userSubject is ()) {
                log:printError("error validating JWT token. 'sub' field is missing.");
                JwtTokenError invalidJwtErr = error(JWT_TOKEN_ERROR, message = "invalid JWT token. 'sub' field is missing.");
                return invalidJwtErr;
            } else {
                return <@untainted>userSubject;
            }
        }
    }
}

function getEmployee() returns Employee|EmployeeCreateError {
    Employee|EmployeeCreateError newEmployee = new Employee("WSO2", "Dilhasha", "Engineer");
    return <@untainted>newEmployee;
}

