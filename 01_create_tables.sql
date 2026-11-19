CREATE DATABASE HealthCenterRental;
GO
USE HealthCenterRental;
GO

-- 학생
CREATE TABLE Users (
    user_id     INT IDENTITY(1,1) PRIMARY KEY,
    student_no  VARCHAR(20)  NOT NULL UNIQUE,
    name        NVARCHAR(50) NOT NULL
);

-- 물품 (총수량 / 대여 가능 수량)
CREATE TABLE Items (
    item_id       INT IDENTITY(1,1) PRIMARY KEY,
    item_name     NVARCHAR(50) NOT NULL UNIQUE,
    total_qty     INT NOT NULL CHECK (total_qty >= 0),
    available_qty INT NOT NULL,
    rental_days   INT NOT NULL DEFAULT 7,
    CONSTRAINT CK_Items_Stock CHECK (available_qty BETWEEN 0 AND total_qty)  -- 재고가 음수가 되는 것을 DB가 막음
);

-- 대여 신청 (신청 → 승인 → 반납 상태 관리)
CREATE TABLE Rentals (
    rental_id    INT IDENTITY(1,1) PRIMARY KEY,
    user_id      INT NOT NULL REFERENCES Users(user_id),
    item_id      INT NOT NULL REFERENCES Items(item_id),
    status       VARCHAR(10) NOT NULL DEFAULT 'REQUESTED'
                 CHECK (status IN ('REQUESTED','APPROVED','REJECTED','RETURNED')),
    requested_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    approved_at  DATETIME2 NULL,
    due_date     DATE NULL,
    returned_at  DATETIME2 NULL
);

-- 같은 학생이 같은 물품을 '신청 중/대여 중'으로 2건 가질 수 없음 (중복 대여 방지의 최종 안전장치)
CREATE UNIQUE INDEX UX_Rentals_Active
ON Rentals(user_id, item_id)
WHERE status IN ('REQUESTED','APPROVED');
GO

-- 샘플 데이터 (한글 앞에는 N을 붙여야 깨지지 않음)
INSERT INTO Users (student_no, name) VALUES
('60230001', N'김명지'), ('60230002', N'이학생'), ('60230003', N'박학생');

INSERT INTO Items (item_name, total_qty, available_qty, rental_days) VALUES
(N'응급키트', 5, 5, 3), (N'휠체어', 1, 1, 7), (N'목발', 3, 3, 14);