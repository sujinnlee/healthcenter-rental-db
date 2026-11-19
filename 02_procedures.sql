USE HealthCenterRental;
GO

-- ① 대여 신청: 이미 신청했거나 대여 중이면 거부
CREATE OR ALTER PROCEDURE usp_RequestRental
    @user_id INT, @item_id INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM Rentals
               WHERE user_id = @user_id AND item_id = @item_id
                 AND status IN ('REQUESTED','APPROVED'))
        THROW 50001, N'이미 신청했거나 대여 중인 물품입니다.', 1;

    INSERT INTO Rentals (user_id, item_id) VALUES (@user_id, @item_id);
    SELECT SCOPE_IDENTITY() AS new_rental_id;
END
GO

-- ② 승인: 재고 차감 + 상태 변경을 하나의 트랜잭션으로
CREATE OR ALTER PROCEDURE usp_ApproveRental
    @rental_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;   -- 오류가 나면 전부 되돌림
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @item_id INT, @days INT;

        -- 신청 상태인 건만, 잠금을 걸고 조회 (동시에 같은 건을 두 번 승인하지 못하게)
        SELECT @item_id = r.item_id, @days = i.rental_days
        FROM Rentals r WITH (UPDLOCK, ROWLOCK)
        JOIN Items i ON i.item_id = r.item_id
        WHERE r.rental_id = @rental_id AND r.status = 'REQUESTED';

        IF @item_id IS NULL
            THROW 50002, N'승인할 수 있는 신청이 아닙니다.', 1;

        -- 재고가 남아 있을 때만 1 차감 (확인과 차감을 한 문장으로 처리)
        UPDATE Items
        SET available_qty = available_qty - 1
        WHERE item_id = @item_id AND available_qty > 0;

        IF @@ROWCOUNT = 0
            THROW 50003, N'재고가 부족합니다.', 1;

        UPDATE Rentals
        SET status = 'APPROVED',
            approved_at = SYSDATETIME(),
            due_date = DATEADD(DAY, @days, CAST(SYSDATETIME() AS DATE))
        WHERE rental_id = @rental_id;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

-- ③ 반납: 상태 변경 + 재고 복구를 하나의 트랜잭션으로
CREATE OR ALTER PROCEDURE usp_ReturnRental
    @rental_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @item_id INT;

        SELECT @item_id = item_id
        FROM Rentals WITH (UPDLOCK, ROWLOCK)
        WHERE rental_id = @rental_id AND status = 'APPROVED';

        IF @item_id IS NULL
            THROW 50004, N'대여 중인 건이 아닙니다.', 1;

        UPDATE Rentals SET status = 'RETURNED', returned_at = SYSDATETIME()
        WHERE rental_id = @rental_id;

        UPDATE Items SET available_qty = available_qty + 1
        WHERE item_id = @item_id;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO