SET TERMOUT ON
PROMPT Building demonstration tables.  Please wait.
SET TERMOUT OFF

ALTER SESSION SET NLS_LANGUAGE = 'ENGLISH';

CREATE TABLE Customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR2(100),
    email VARCHAR2(100),
    phone VARCHAR2(20),
    discount NUMBER(5, 2)
);

CREATE TABLE Services (
    service_id INT PRIMARY KEY,
    name VARCHAR2(100),
    price NUMBER(8, 2)
);

CREATE TABLE Reservations (
    reservation_id INT PRIMARY KEY,
    customer_id INT,
    service_id INT,
    hairdresser_id INT,
    reservation_date DATE,
    reservation_time VARCHAR2(10),
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
    FOREIGN KEY (service_id) REFERENCES Services(service_id)

);

CREATE TABLE Employees (
    employee_id INT PRIMARY KEY,
    name VARCHAR2(100),
    shift_start TIME,
    shift_end TIME
);

CREATE TABLE Employee_Services (
    employee_id INT,
    service_id INT,
    PRIMARY KEY (employee_id, service_id),
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id),
    FOREIGN KEY (service_id) REFERENCES Services(service_id)
);

INSERT INTO Customers (customer_id, name, email, phone, discount)
VALUES (1, 'Steve Jobs', 'steve@something.com', '5647383849', NULL),
       (2, 'Jane Smith', 'smith@something.com', '9948737475', NULL);

INSERT INTO Services (service_id, name, price)
VALUES (1, 'Haircut', 30.00),
       (2, 'Coloring', 50.00),
       (3, 'Styling', 40.00);

INSERT INTO Employees (employee_id, name, shift_start, shift_end)
VALUES (1, 'Mark', '09:00:00', '17:00:00'),
       (2, 'Alex', '10:00:00', '18:00:00');

INSERT INTO Employee_Services (employee_id, service_id)
VALUES (1, 1),
       (1, 2),
       (2, 1),
       (2, 3);


CREATE OR REPLACE PROCEDURE insert_customer(
    p_name IN VARCHAR2,
    p_email IN VARCHAR2,
    p_phone IN VARCHAR2
) AS
BEGIN
    INSERT INTO Customers (customer_id, name, email, phone)
    VALUES (seq_customer_id.NEXTVAL, p_name, p_email, p_phone);
    COMMIT;
END insert_customer;
/


CREATE OR REPLACE PROCEDURE make_reservation(
    p_customer_id IN INT,
    p_service_id IN INT,
    p_hairdresser_id IN INT,
    p_reservation_date IN DATE,
    p_reservation_time IN VARCHAR2
) AS
BEGIN
    INSERT INTO Reservations (reservation_id, customer_id, service_id, hairdresser_id, reservation_date, reservation_time)
    VALUES (seq_reservation_id.NEXTVAL, p_customer_id, p_service_id, p_hairdresser_id, p_reservation_date, p_reservation_time);
    COMMIT;
END make_reservation;
/

CREATE OR REPLACE FUNCTION count_customer_visits(
    p_customer_id IN INT
) RETURN INT AS
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM Reservations
    WHERE customer_id = p_customer_id
    AND reservation_date >= SYSDATE - INTERVAL '2' YEAR;

    RETURN v_count;
END count_customer_visits;
/


CREATE OR REPLACE PROCEDURE give_customer_discount(
    p_customer_id IN INT,
    p_discount IN NUMBER
) AS
BEGIN
    UPDATE Customers
    SET discount = p_discount
    WHERE customer_id = p_customer_id;
    COMMIT;
END give_customer_discount;
/

CREATE OR REPLACE PROCEDURE prepare_receipt(
    p_reservation_id IN INT
) AS
    v_customer_name VARCHAR2(100);
    v_service_name VARCHAR2(100);
    v_hairdresser_name VARCHAR2(100);
    v_reservation_date DATE;
    v_reservation_time VARCHAR2(10);
    v_service_price NUMBER(8, 2);
BEGIN

    SELECT c.name, s.name, e.name, r.reservation_date, r.reservation_time, s.price
    INTO v_customer_name, v_service_name, v_hairdresser_name, v_reservation_date, v_reservation_time, v_service_price
    FROM Reservations r
    JOIN Customers c ON r.customer_id = c.customer_id
    JOIN Services s ON r.service_id = s.service_id
    JOIN Employees e ON r.hairdresser_id = e.employee_id
    WHERE r.reservation_id = p_reservation_id;

    DBMS_OUTPUT.PUT_LINE('Receipt');
    DBMS_OUTPUT.PUT_LINE('Customer Name: ' || v_customer_name);
    DBMS_OUTPUT.PUT_LINE('Service: ' || v_service_name);
    DBMS_OUTPUT.PUT_LINE('Hairdresser: ' || v_hairdresser_name);
    DBMS_OUTPUT.PUT_LINE('Date: ' || TO_CHAR(v_reservation_date, 'DD-MON-YYYY'));
    DBMS_OUTPUT.PUT_LINE('Time: ' || v_reservation_time);
    DBMS_OUTPUT.PUT_LINE('Price: $' || v_service_price);
END prepare_receipt;
/


CREATE OR REPLACE PROCEDURE calculate_salary AS
BEGIN
    FOR emp IN (
        SELECT e.employee_id, e.name,
               SUM(s.price) AS total_earnings
        FROM Employees e
        LEFT JOIN Reservations r ON e.employee_id = r.hairdresser_id
        LEFT JOIN Services s ON r.service_id = s.service_id
        GROUP BY e.employee_id, e.name
    ) LOOP

        UPDATE Employees
        SET salary = (5000 + emp.total_earnings * 0.1) -- Assuming 10% commission
        WHERE employee_id = emp.employee_id;
    END LOOP;
    COMMIT;
END calculate_salary;
/


CREATE OR REPLACE PROCEDURE find_replacement_for_sick_employee(
    p_sick_employee_id IN INT
) AS
BEGIN
    FOR service_rec IN (
        SELECT DISTINCT service_id
        FROM Reservations
        WHERE hairdresser_id = p_sick_employee_id
    ) LOOP
        FOR replacement_emp IN (
            SELECT e.employee_id
            FROM Employees e
            WHERE e.employee_id != p_sick_employee_id
            AND e.shift_start = (SELECT shift_start FROM Employees WHERE employee_id = p_sick_employee_id)
            AND e.shift_end = (SELECT shift_end FROM Employees WHERE employee_id = p_sick_employee_id)
            AND EXISTS (
                SELECT 1
                FROM Employee_Services es
                WHERE es.employee_id = e.employee_id
                AND es.service_id = service_rec.service_id
            )
        ) LOOP

            UPDATE Reservations
            SET hairdresser_id = replacement_emp.employee_id
            WHERE hairdresser_id = p_sick_employee_id
            AND service_id = service_rec.service_id;
        END LOOP;
    END LOOP;
    COMMIT;
END find_replacement_for_sick_employee;
/

CREATE OR REPLACE TRIGGER trg_check_customer_id
BEFORE INSERT OR UPDATE OF customer_id ON Reservations
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM Customers
    WHERE customer_id = :NEW.customer_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Invalid customer ID');
    END IF;
END;
/


CREATE OR REPLACE TRIGGER trg_check_service_id
BEFORE INSERT OR UPDATE OF service_id ON Reservations
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM Services
    WHERE service_id = :NEW.service_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Invalid service ID');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_check_hairdresser_id
BEFORE INSERT OR UPDATE OF hairdresser_id ON Reservations
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM Employees
    WHERE employee_id = :NEW.hairdresser_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Invalid hairdresser ID');
    END IF;
END;
/

COMMIT;