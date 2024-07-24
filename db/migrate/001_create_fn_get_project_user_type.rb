class CreateFnGetProjectUserType < ActiveRecord::Migration[5.2]
    def self.up

        execute 'DROP FUNCTION IF EXISTS get_mgt_user_type'  
        execute 'DROP FUNCTION IF EXISTS get_project_user_type'
        execute <<-SQL
        /*

        Предварительно необходимо произвести определение типов для пользователей по двум категориям _Исполнитель и _Заказчик.

        Для этого необходимо в Редмайне создать две группы _Исполнитель и _Заказчик.
        В каждую из этих групп необходимо добавить соответствующих пользователей.
        Все сотрудники МГТ должны попасть в группу _Заказчик, все сотрудники других организаций в группу _Исполнитель.
        Если пользователь не принадлежит ни одной из этих групп, то по умолчанию его тип равен _Заказчик
        
        Каждый пользователь должен принадлежать только одной из этих групп. Его тип в каждом конкретном проекте
        можно изменить (об этом ниже).

        Также необходимо (желательно) создать две роли _Исполнитель и _Заказчик,
        названия которых должны совпадать с названиями соответствующих групп.
        Роли _Исполнитель и _Заказчик не должны обладать никакими правами ни в одном из проектов.

        Группы _Исполнитель и _Заказчик не нужно добавлять ни в один из проектов.

        Любому пользователю в рамках конкретного проекта может быть индивидуально назначена роль _Исполнитель или _Заказчик.
        Предположим, пользователь user_1 по умолчанию включен в состав группы _Исполнитель, 
        но в рамках Project1, ему назначена роль _Заказчик, в этом случае роль _Заказчик имеет более высокий приоритет и пользователь
        user_1 будет иметь тип _Заказчик, а не _Исполнитель.

        Пользователь может не входить в состав ни одной из групп _Исполнитель и _Заказчик. В этом случае, для определения его типа
        в рамках конкретного проекта ему можно присвоить соответствующую роль _Исполнитель илт _Заказчик.

        Если пользователь не входит в состав ни одной из групп _Исполнитель и _Заказчик и ему не присвоена роль _Исполнитель или _Заказчик 
        в рамках конкретного проекта, то такой пользователь будет иметь тип по умолчанию _Заказчик (в рамках этого конкретного проекта)

        */

        CREATE FUNCTION get_project_user_type( aUserId INT, aProjectId INT ) RETURNS VARCHAR(30)
        READS SQL DATA
        SQL SECURITY INVOKER
        COMMENT 'Get user type Client/Contractor in project'
        BEGIN
            DECLARE Result VARCHAR(30);
            DECLARE clientName VARCHAR(30);
            DECLARE contractorName VARCHAR(30);
            DECLARE clientAlias VARCHAR(30);
            DECLARE contractorAlias VARCHAR(30);
            DECLARE unknownAlias VARCHAR(30);
            
            SET clientName = '_Заказчик';
            SET clientAlias = 'client';
            SET contractorName = '_Исполнитель';
            SET contractorAlias = 'contractor';
            SET unknownAlias = 'unknown';
            SET Result = unknownAlias;
            
            SELECT 
                    IFNULL( IFNULL( IFNULL( IFNULL( ( 
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
                                AND g.lastname IN ( clientName, contractorName )
                                AND r.name IN ( clientName, contractorName ) 
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
                                AND g.lastname IN ( clientName, contractorName ) 
                                AND r.name IN ( clientName, contractorName ) 
                                AND r.name = g.lastname
                            LIMIT 1
                        ) 
                    )
                    
                    , ( 
                        SELECT 
                            r.name roleName
                        FROM 
                            users u 
                        LEFT JOIN members m ON m.user_id = u.id 
                        LEFT JOIN member_roles mr ON m.id = mr.member_id
                        LEFT JOIN roles r ON mr.role_id = r.id 
                        WHERE 
                            u.id = uu.id
                            AND m.project_id = aProjectId
                            AND r.name IN ( clientName, contractorName ) 
                        LIMIT 1
                    ) )
                    , ( -- В проекте пользователя нет, ищем по названию группы
                        SELECT
                            g.lastname groupName
                        FROM 
                            groups_users gu 
                        LEFT JOIN users g ON g.id = gu.group_id 
                        WHERE 
                            gu.user_id = uu.id
                            AND g.lastname IN ( clientName, contractorName ) 
                        LIMIT 1               
                    )
                )
                , unknownAlias ) INTO Result
            FROM 
                users uu
            WHERE
                uu.id = aUserId;
                
            RETURN IF( Result = clientName, clientAlias, IF ( Result = contractorName, contractorAlias, unknownAlias ) );
        END
      SQL
    end  

    def self.down
    end
end
