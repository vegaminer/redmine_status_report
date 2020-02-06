/*

Для подсчета KPI предварительно необходимо произвести определение типов для пользователей по двум категориям _Исполнитель и _Заказчик.

Для этого необходимо в Редмайне создать две группы _Исполнитель и _Заказчик.
В каждую из этих групп необходимо добавить соответствующих пользователей.
Все сотрудники МГТ должны попасть в группу _Заказчик, все сотрудники других организаций в группу _Исполнитель.

Каждый пользователь должен принадлежать только одной из этих групп. Его тип в каждом конкретном проекте
можно изменить (об этом ниже).

Также необходимо создать две роли _Исполнитель и _Заказчик,
названия которых должны совпадать с названиями соответствующих групп.
Роли _Исполнитель и _Заказчик не должны обладать никакими правами ни в одном из проектов.

В проект каждую из этих групп необходимо добавить, указав необходимую роль:
Группа _Исполнитель получает роль _Исполнитель
Группа _Заказчик получает роль _Заказчик

Любому пользователю в рамках конкретного проекта может быть индивидуально назначена роль _Исполнитель или _Заказчик.
Предположим, пользователь user1 по умолчанию включен в состав группы _Исполнитель, 
но в рамках Project1, ему назначена роль _Заказчик, в этом случае роль _Заказчик имеет более высокий приоритет и пользователь
user1 будет иметь тип _Заказчик, а не _Исполнитель.

Пользователь может не входить в состав ни одной из групп _Исполнитель и _Заказчик. В этом случае, для определения его типа
в рамках конкретного проекта ему можно присвоить соответствующую роль.

Если пользователь не входит в состав ни одной из групп _Исполнитель и _Заказчик и ему не присвоена роль _Исполнитель или _Заказчик 
в рамках конкретного проекта, то такой пользователь будет иметь тип по умолчанию _Заказчик (в рамках этого конкретного проекта)

*/

DROP FUNCTION IF EXISTS get_mgt_user_type;
DELIMITER $$
CREATE DEFINER = 'mappl'@'localhost' FUNCTION get_mgt_user_type( aUserId INT, aProjectId INT ) RETURNS VARCHAR(30)
READS SQL DATA
BEGIN
    DECLARE Result VARCHAR(30);
    SET Result = '_Заказчик';
    
    SELECT 
           IFNULL( IFNULL( IFNULL( ( 
                    SELECT 
                        r.name roleName
                    FROM 
                        users u 
                    LEFT JOIN groups_users gu ON u.id = gu.user_id
                    LEFT JOIN users g ON g.id = gu.group_id 
                    LEFT JOIN members m ON m.user_id = u.id  
                    LEFT JOIN member_roles mr ON m.id = mr.member_id
                    LEFT JOIN roles r ON mr.role_id = r.id 
                    WHERE u.id = uu.id
                        AND m.project_id = aProjectId
                        AND g.lastname IN ( '_Исполнитель', '_Заказчик' )
                        AND r.name IN ( '_Исполнитель', '_Заказчик' ) 
                        AND r.name != g.lastname 
                    LIMIT 1
                ) 
                    
                , ( 
                    SELECT 
                        r.name roleName
                    FROM 
                        users u 
                    LEFT JOIN groups_users gu ON u.id = gu.user_id
                    LEFT JOIN users g ON g.id = gu.group_id 
                    LEFT JOIN members m ON m.user_id = u.id 
                    LEFT JOIN member_roles mr ON m.id = mr.member_id
                    LEFT JOIN roles r ON mr.role_id = r.id 
                    WHERE 
                        u.id = uu.id
                        AND m.project_id = aProjectId
                        AND g.lastname IN ( '_Исполнитель', '_Заказчик' ) 
                        AND r.name IN ( '_Исполнитель', '_Заказчик' ) 
                        AND r.name = g.lastname
                    LIMIT 1
                ) 
            )
            
            , ( SELECT 
                    r.name roleName
                FROM 
                    users u 
                LEFT JOIN members m ON m.user_id = u.id 
                LEFT JOIN member_roles mr ON m.id = mr.member_id
                LEFT JOIN roles r ON mr.role_id = r.id 
                WHERE 
                    u.id = uu.id
                    AND m.project_id = aProjectId
                    AND r.name IN ( '_Исполнитель', '_Заказчик' ) 
                LIMIT 1
            )
        )
        , '_Заказчик' ) INTO Result
    FROM 
        users uu
    WHERE
        uu.id = aUserId;
        
    RETURN Result;    
END$$
DELIMITER ;