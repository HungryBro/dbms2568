CREATE TABLE doctor (
    doctor_id INT PRIMARY KEY,
    ssn VARCHAR (13),
    name VARCHAR (50),
    specialty VARCHAR (100),
    experience_year INT
);

CREATE TABLE patient (
    patient_id INT PRIMARY KEY,
    ssn VARCHAR (13),
    name VARCHAR (50),
    address VARCHAR (100),
    age INT,
    doctor_id INT,
    FOREIGN KEY (doctor_id) REFERENCES doctor(doctor_id)
);

CREATE TABLE drug (
    drug_id INT PRIMARY KEY,
    trade_name VARCHAR (100),
    formula VARCHAR (100)
);

CREATE TABLE pharmacy (
    pharmacy_id INT PRIMARY KEY,
    name VARCHAR (100),
    address VARCHAR (200),
    phone VARCHAR (10)
);

CREATE TABLE pharm_co (
    pharm_co_id INT PRIMARY KEY,
    name VARCHAR (100),
    phone VARCHAR (13)
);

CREATE TABLE sell (
    sell_id INT PRIMARY KEY,
    pharmacy_id INT,
    drug_id INT,
    price decimal,
    FOREIGN KEY (pharmacy_id) REFERENCES pharmacy(pharmacy_id),
    FOREIGN KEY (drug_id) REFERENCES drug(drug_id)
);

CREATE TABLE contract (
    contract_id INT PRIMARY KEY,
    pharmacy_id INT,
    pharm_co_id INT,
    drug_id INT,
    start_date DATE,
    end_date DATE,
    contract_note VARCHAR(200),
    supervisor VARCHAR (100),
    FOREIGN KEY (pharmacy_id) REFERENCES pharmacy(pharmacy_id),
    FOREIGN KEY (drug_id) REFERENCES drug(drug_id),
    FOREIGN KEY (pharm_co_id) REFERENCES pharm_co(pharm_co_id)
);

CREATE TABLE prescription(
    prescription_id INT PRIMARY KEY,
    patient_id INT,
    doctor_id INT,
    drug_id INT,
    prescription_date DATE,
    quantity INT,
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES doctor(doctor_id),
    FOREIGN KEY (drug_id) REFERENCES drug(drug_id)
);

"ความสัมพันธ์ ผู้ป่วย แพทย์ ความชำนาญแพทย์"
SELECT
    p.name as patient,
    d.name as doctor,
    d.specialty
FROM
    patient p
INNER JOIN
    doctor d
ON
    p.doctor_id = d.doctor_id;

"ความสัมพันธ์ ผู้ป่วย แพทย์ ยา ปริมาณเท่าไหร่"
SELECT
    pa.name as patient,
    d.name as doctor,
    dr.trade_name as drug,
    p.quantity
FROM
    prescription p
INNER JOIN
    patient pa ON p.patient_id = pa.patient_id
INNER JOIN
    doctor d ON p.doctor_id = d.doctor_id
INNER JOIN
    drug dr ON p.drug_id = dr.drug_id;

"เปรียบเทียบราคาของยาในแต่ละร้าน ร้านยา ยา ราคา"
SELECT
    p.name as pharmacy,
    d.trade_name as drug,
    s.price
FROM
    sell s
INNER JOIN
    pharmacy p ON s.pharmacy_id = p.pharmacy_id
INNER JOIN
    drug d ON s.drug_id = d.drug_id;

"ร้านยา บริษัทที่ทำสัญญา ยาอะไร เริ่ม สิ้นสุด"
SELECT
    p.name as pharmacy,
    pc.name as pharm_co,
    d.trade_name as drug,
    c.start_date,
    c.end_date
FROM
    contract c
INNER JOIN
    pharmacy p on c.pharmacy_id = p.pharmacy_id
INNER JOIN
    pharm_co pc on c.pharm_co_id = pc.pharm_co_id
INNER JOIN
    drug d on c.drug_id  = d.drug_id;