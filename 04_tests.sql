USE HealthCenterRental;
GO

-- 초기화 (테스트 시작 전 실행)
DELETE FROM Rentals;                          -- 신청 기록 전부 삭제
DBCC CHECKIDENT ('Rentals', RESEED, 0);       -- rental_id 번호를 다시 1부터
UPDATE Items SET available_qty = total_qty;   -- 재고 원상복구

-- ※ 아래 테스트는 한 줄씩 실행

-- T1 정상 흐름: 신청 → 승인 → 반납
EXEC usp_RequestRental 1, 3;
EXEC usp_ApproveRental 1;
SELECT * FROM vw_CurrentRentals;
EXEC usp_ReturnRental 1;
SELECT * FROM vw_ItemStock;

-- T2 중복 대여 → 두 번째 줄에서 50001 오류
EXEC usp_RequestRental 1, 1;
EXEC usp_RequestRental 1, 1;

-- T3 재고 초과 (휠체어 1대) → 마지막 줄에서 50003 오류
EXEC usp_RequestRental 2, 2;
EXEC usp_RequestRental 3, 2;
EXEC usp_ApproveRental 3;
EXEC usp_ApproveRental 4;

-- T4 반납 두 번 → 두 번째 줄에서 50004 오류
EXEC usp_ReturnRental 3;
EXEC usp_ReturnRental 3;

-- T5 동시 승인 (창 A)
DELETE FROM Rentals;
DBCC CHECKIDENT ('Rentals', RESEED, 0);
UPDATE Items SET available_qty = total_qty;

EXEC usp_RequestRental 1, 2;   -- 김명지 휠체어 신청 → rental_id 1
EXEC usp_RequestRental 2, 2;   -- 이학생 휠체어 신청 → rental_id 2

BEGIN TRAN;
EXEC usp_ApproveRental 1;      -- 1번 승인 (잠금 유지)
WAITFOR DELAY '00:00:15';      -- 15초 동안 COMMIT하지 않고 대기
COMMIT;

-- T5 (창 B) : 위 4줄 실행 직후 다른 쿼리 창에서 실행
-- EXEC usp_ApproveRental 2;   → 대기 후 50003 오류

-- 결과 확인
SELECT * FROM Rentals;