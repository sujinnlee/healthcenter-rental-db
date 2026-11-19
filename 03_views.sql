USE HealthCenterRental;
GO

-- 현재 대여 현황 + 연체 여부
CREATE OR ALTER VIEW vw_CurrentRentals AS
SELECT r.rental_id, u.student_no, u.name, i.item_name, r.approved_at, r.due_date,
       CASE WHEN r.due_date < CAST(SYSDATETIME() AS DATE) THEN N'연체' ELSE N'정상' END AS rental_state
FROM Rentals r
JOIN Users u ON u.user_id = r.user_id
JOIN Items i ON i.item_id = r.item_id
WHERE r.status = 'APPROVED';
GO

-- 물품별 재고 현황
CREATE OR ALTER VIEW vw_ItemStock AS
SELECT item_name, total_qty, available_qty, total_qty - available_qty AS rented_qty
FROM Items;
GO