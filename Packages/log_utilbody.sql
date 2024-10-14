CREATE OR REPLACE PACKAGE BODY log_util IS

    --PROCEDURE to_log
    PROCEDURE to_log(p_appl_proc IN VARCHAR2, p_message IN VARCHAR2) IS
        PRAGMA autonomous_transaction;
    BEGIN
        INSERT INTO logs(id, appl_proc, message)
        VALUES(log_seq.NEXTVAL, p_appl_proc, p_message);
        COMMIT;
    END to_log;

    --PROCEDURE log_start
    PROCEDURE log_start(p_proc_name IN VARCHAR2, p_text IN VARCHAR2 DEFAULT NULL) IS
        v_text VARCHAR2(5000);
    BEGIN
        IF p_text IS NULL THEN
            v_text := 'Старт логування, назва процесу = ' || p_proc_name;
        ELSE
            v_text := p_text;
        END IF;

        to_log(p_appl_proc => p_proc_name, p_message => v_text);
    END log_start;

    --PROCEDURE log_finish
    PROCEDURE log_finish(p_proc_name IN VARCHAR2, p_text IN VARCHAR2 DEFAULT NULL) IS
        v_text VARCHAR2(5000);
    BEGIN
        IF p_text IS NULL THEN
            v_text := 'Завершення логування, назва процесу = ' || p_proc_name;
        ELSE
            v_text := p_text;
        END IF;

        to_log(p_appl_proc => p_proc_name, p_message => v_text);
    END log_finish;

    --PROCEDURE log_error
    PROCEDURE log_error(p_proc_name IN VARCHAR2, p_sqlerrm IN VARCHAR2, p_text IN VARCHAR2 DEFAULT NULL) IS
        v_text VARCHAR2(5000);
    BEGIN
        IF p_text IS NULL THEN
            v_text := 'В процедурі ' || p_proc_name || ' сталася помилка. ' || p_sqlerrm;
        ELSE
            v_text := p_text;
        END IF;

        to_log(p_appl_proc => p_proc_name, p_message => v_text);
    END log_error;

    PROCEDURE add_employee(
    p_first_name     IN VARCHAR2,
    p_last_name      IN VARCHAR2,
    p_email          IN VARCHAR2,
    p_phone_number   IN VARCHAR2,
    p_hire_date      IN DATE DEFAULT TRUNC(SYSDATE, 'DD'),
    p_job_id         IN VARCHAR2,
    p_salary         IN NUMBER,
    p_commission_pct IN VARCHAR2 DEFAULT NULL,
    p_manager_id     IN NUMBER,
    p_department_id  IN NUMBER DEFAULT 100
    ) IS
    v_max_employee_id NUMBER;
    v_min_salary      NUMBER;
    v_max_salary      NUMBER;
    v_department_name VARCHAR2(100);
    v_job_title       VARCHAR2(100);
    v_work_time       VARCHAR2(100);
    v_error_message   VARCHAR2(1000);
    BEGIN

    --Виклик log_start
    log_util.log_start(p_proc_name => 'add_employee');

    --Перевірка p_job_id
    BEGIN
        SELECT job_title, min_salary, max_salary
        INTO v_job_title, v_min_salary, v_max_salary
        FROM jobs
        WHERE job_id = p_job_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Введено неіснуючий код посади');
    END;

    --Перевірка p_department_id
    BEGIN
        SELECT department_name
        INTO v_department_name
        FROM departments
        WHERE department_id = p_department_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Введено неіснуючий ідентифікатор відділу');
    END;

    --Перевірка відповідності ЗП
    IF p_salary < v_min_salary OR p_salary > v_max_salary THEN
        RAISE_APPLICATION_ERROR(-20003, 'Зарплата не відповідає діапазону для даної посади');
    END IF;

    --Перевірка бізнс часу
    v_work_time := TO_CHAR(SYSDATE, 'HH24:MI');
    IF TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') IN ('SAT', 'SUN') OR v_work_time NOT BETWEEN '08:00' AND '18:00' THEN
       RAISE_APPLICATION_ERROR(-20004, 'Ви не можете додати нового співробітника в позаробочий час');
    END IF;


    --Находим employee_id для нового працвника
    SELECT MAX(employee_id) + 1 INTO v_max_employee_id FROM employees;

    --Вставка нового працівника
    INSERT INTO employees (
        employee_id, first_name, last_name, email, phone_number, hire_date, job_id, salary,
        commission_pct, manager_id, department_id
    ) VALUES (
        v_max_employee_id, p_first_name, p_last_name, p_email, p_phone_number, p_hire_date,
        p_job_id, p_salary, p_commission_pct, p_manager_id, p_department_id
    );

    COMMIT;

    --Якщо успішно - логуємо
    log_util.log_finish(p_proc_name => 'add_employee', p_text => 'Співробітник доданий: ' ||
        p_first_name || ' ' || p_last_name || ', Посада: ' || p_job_id || ', Відділ: ' || p_department_id);

        EXCEPTION
           WHEN OTHERS THEN
    --Логуєм помилку
        v_error_message := SQLERRM;
        log_util.log_error(p_proc_name => 'add_employee', p_sqlerrm => v_error_message);
        RAISE;
        END add_employee;

       PROCEDURE check_business_time IS
        v_work_time VARCHAR2(10);
        v_day_of_week VARCHAR2(10);
    BEGIN
        v_work_time := TO_CHAR(SYSDATE, 'HH24:MI');
        v_day_of_week := TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH');

        IF v_day_of_week IN ('SAT', 'SUN') OR v_work_time NOT BETWEEN '08:00' AND '18:00' THEN
     --Виклик to_log
            log_util.to_log(
                p_appl_proc => 'check_business_time',
                p_message => 'Ви можете видаляти співробітника лише в робочий час '
            );
            RAISE_APPLICATION_ERROR(-20002, 'Ви можете видаляти співробітника лише в робочий час');
        END IF;
    END check_business_time;


      --PROCEDURE fire_an_employee
    PROCEDURE fire_an_employee(p_employee_id IN NUMBER) IS
        v_first_name     VARCHAR2(20);
        v_last_name      VARCHAR2(25);
        v_job_id         VARCHAR2(10);
        v_department_id  NUMBER(4);
        v_error_message  VARCHAR2(100);
    BEGIN
       --Виклик log_start
        log_util.log_start(p_proc_name => 'fire_an_employee');

      --Перевірка чи є співробітник
        BEGIN
            SELECT first_name, last_name, job_id, department_id
            INTO v_first_name, v_last_name, v_job_id, v_department_id
            FROM employees
            WHERE employee_id = p_employee_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'Переданий співробітник не існує');
        END;

       --Перевірка бізнес часу
        check_business_time;

        --Записуєм в історію якщо співробітник є
        BEGIN
            INSERT INTO employees_history (employee_id, first_name, last_name, email, phone_number,
                                           hire_date, job_id, salary, commission_pct, manager_id,
                                           department_id, fire_date)
            SELECT employee_id, first_name, last_name, email, phone_number, hire_date, job_id, salary,
                   commission_pct, manager_id, department_id, SYSDATE
            FROM employees
            WHERE employee_id = p_employee_id;

            -- Видалення співробітника
            DELETE FROM employees
            WHERE employee_id = p_employee_id;

            COMMIT;

            -- Якщо все пройшло успішно, логуємо успішний результат
            log_util.log_finish(p_proc_name => 'fire_an_employee',
                                p_text => 'Співробітник ' || v_first_name || ' ' || v_last_name ||
                                          ', Посада: ' || v_job_id || ', Відділ: ' || v_department_id || ' - успішно звільнений.');
        EXCEPTION
            WHEN OTHERS THEN
                -- Логування помилки в разі будь-яких виключень
                v_error_message := SQLERRM;
                log_util.log_error(p_proc_name => 'fire_an_employee', p_sqlerrm => v_error_message);
                RAISE;
        END;

    END fire_an_employee;

    PROCEDURE change_attribute_employee (
        p_employee_id      IN NUMBER,
        p_first_name       IN VARCHAR2 DEFAULT NULL,
        p_last_name        IN VARCHAR2 DEFAULT NULL,
        p_email            IN VARCHAR2 DEFAULT NULL,
        p_phone_number     IN VARCHAR2 DEFAULT NULL,
        p_job_id           IN VARCHAR2 DEFAULT NULL,
        p_salary           IN NUMBER DEFAULT NULL,
        p_commission_pct   IN VARCHAR2 DEFAULT NULL,
        p_manager_id       IN NUMBER DEFAULT NULL,
        p_department_id    IN NUMBER DEFAULT NULL
    ) IS
        v_set_param     VARCHAR2(4000);
        v_first   BOOLEAN := TRUE;
        v_error_message VARCHAR2(4000);
    BEGIN
        --Виклик log_start
        log_util.log_start(p_proc_name => 'change_attribute_employee');

        -- Перевірка параметрів
        IF p_first_name IS NULL AND p_last_name IS NULL AND p_email IS NULL AND p_phone_number IS NULL AND
           p_job_id IS NULL AND p_salary IS NULL AND p_commission_pct IS NULL AND p_manager_id IS NULL AND
           p_department_id IS NULL THEN
            log_util.log_finish(p_proc_name => 'change_attribute_employee',
                                p_text => 'Не передано жодних значень для оновлення');
            RAISE_APPLICATION_ERROR(-20001, 'Не передано жодних значень для оновлення');
        END IF;

        v_set_param := 'UPDATE employees SET ';


        IF p_first_name IS NOT NULL THEN
            v_set_param := v_set_param || 'first_name = ''' || p_first_name || '''';
            v_first := FALSE;
        END IF;

        IF p_last_name IS NOT NULL THEN
            IF NOT v_first THEN
                v_set_param := v_set_param || ', ';
            END IF;
            v_set_param := v_set_param || 'last_name = ''' || p_last_name || '''';
            v_first := FALSE;
        END IF;

        IF p_email IS NOT NULL THEN
            IF NOT v_first THEN
                v_set_param := v_set_param || ', ';
            END IF;
            v_set_param := v_set_param || 'email = ''' || p_email || '''';
            v_first := FALSE;
        END IF;

        IF p_phone_number IS NOT NULL THEN
            IF NOT v_first THEN
                v_set_param := v_set_param || ', ';
            END IF;
            v_set_param := v_set_param || 'phone_number = ''' || p_phone_number || '''';
            v_first := FALSE;
        END IF;

        IF p_job_id IS NOT NULL THEN
            IF NOT v_first THEN
                v_set_param := v_set_param || ', ';
            END IF;
            v_set_param := v_set_param || 'job_id = ''' || p_job_id || '''';
            v_first := FALSE;
        END IF;

        IF p_salary IS NOT NULL THEN
            IF NOT v_first THEN
                v_set_param := v_set_param || ', ';
            END IF;
            v_set_param := v_set_param || 'salary = ' || p_salary;
            v_first := FALSE;
        END IF;

        IF p_commission_pct IS NOT NULL THEN
            IF NOT v_first THEN
                v_set_param := v_set_param || ', ';
            END IF;
            v_set_param := v_set_param || 'commission_pct = ' || p_commission_pct;
            v_first := FALSE;
        END IF;

        IF p_manager_id IS NOT NULL THEN
            IF NOT v_first THEN
                v_set_param := v_set_param || ', ';
            END IF;
            v_set_param := v_set_param || 'manager_id = ' || p_manager_id;
            v_first := FALSE;
        END IF;

        IF p_department_id IS NOT NULL THEN
            IF NOT v_first THEN
                v_set_param := v_set_param || ', ';
            END IF;
            v_set_param := v_set_param || 'department_id = ' || p_department_id;
        END IF;

        v_set_param := v_set_param || ' WHERE employee_id = ' || p_employee_id;

        --Оновлення працвника
        BEGIN
            EXECUTE IMMEDIATE v_set_param;
            COMMIT;

       log_util.log_finish(p_proc_name => 'change_attribute_employee',
                                p_text => 'У співробітника ' || p_employee_id || ' успішно оновлені атрибути');
        EXCEPTION
            WHEN OTHERS THEN
                v_error_message := SQLERRM;
                log_util.log_error(p_proc_name => 'change_attribute_employee', p_sqlerrm => v_error_message);
                RAISE;
        END;

    END change_attribute_employee;

PROCEDURE copy_table(p_source_scheme  IN VARCHAR2,
                     p_target_scheme  IN VARCHAR2 DEFAULT USER,
                     p_list_table     IN VARCHAR2,
                     p_copy_data      IN BOOLEAN DEFAULT FALSE,
                     po_result        OUT VARCHAR2) IS

    v_create VARCHAR2(4000);
    v_copy   VARCHAR2(4000);
    v_table_name    VARCHAR2(100);

    BEGIN

    to_log('copy_table', 'Стартування копіювання таблиць '||p_list_table||' з '|| p_source_scheme ||' до '|| p_target_scheme);

    -- Перебираємо таблиці
        FOR cc IN (
            SELECT table_name,
                   'CREATE TABLE ' || p_target_scheme || '.' || table_name || ' (' ||
                   LISTAGG(column_name || ' ' || data_type || count_symbol, ', ') WITHIN GROUP(ORDER BY column_id) || ')' AS ddl_code
            FROM (
                SELECT table_name,
                       column_name,
                       data_type,
                       CASE
                           WHEN data_type IN ('VARCHAR2', 'CHAR') THEN '(' || data_length || ')'
                           WHEN data_type = 'DATE' THEN NULL
                           WHEN data_type = 'NUMBER' THEN REPLACE('(' || data_precision || ',' || data_scale || ')', '(,)', NULL)
                       END AS count_symbol,
                       column_id
                FROM all_tab_columns
                WHERE owner = p_source_scheme
                  AND table_name IN (SELECT * FROM TABLE(util.table_from_list(p_list_table)))
                  AND table_name NOT IN (SELECT table_name FROM all_tables WHERE owner = p_target_scheme)
                ORDER BY table_name, column_id
            )
            GROUP BY table_name
        ) LOOP

        BEGIN

        v_table_name := cc.table_name;
        v_create := cc.ddl_code;

        to_log('copy_table', 'Оброблення таблиці: ' || v_table_name);

        EXECUTE IMMEDIATE v_create;
        to_log('copy_table', 'Таблицю ' || v_table_name || ' успішно додано в схему ' || p_target_scheme);

            IF p_copy_data = TRUE THEN
                v_copy := 'INSERT INTO ' || p_target_scheme || '.' || v_table_name ||
                                 ' SELECT * FROM ' || p_source_scheme || '.' || v_table_name;
                EXECUTE IMMEDIATE v_copy;
                to_log('copy_table', 'Дані з таблиці ' || p_source_scheme || '.' || v_table_name || ' успішно додані в ' || p_target_scheme || '.' || v_table_name);
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                to_log('copy_table', 'Виникла помилка під час копіювання таблиці ' || v_table_name || ': ' || sqlerrm);
                CONTINUE;
        END;
    END LOOP;

    to_log('copy_table', 'Копіювання таблиць '||p_list_table||' з '||p_source_scheme||' до '||p_target_scheme||' завершено');
    po_result := 'Таблиці '||p_list_table||' успішно скопійовані з '||p_source_scheme||' до '||p_target_scheme;

    EXCEPTION
        WHEN OTHERS THEN
            to_log('copy_table', 'Помилка при копіюванні таблиць: ' || sqlerrm);
            po_result := 'Помилка при копіюванні таблиць: ' || sqlerrm;

END copy_table;

PROCEDURE api_nbu_sync IS
    v_list_cur  VARCHAR2(2000);
    v_err_message    VARCHAR2(1000);
    BEGIN
    --Список валют
    BEGIN
        SELECT value_text
        INTO v_list_cur
        FROM sys_params
        WHERE param_name = 'list_currencies';

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            --Викликаємо помилку якшо параметра нема
            log_util.log_error(p_proc_name => 'api_nbu_sync', p_sqlerrm => 'Параметр list_currencies не знайдено');
            RAISE_APPLICATION_ERROR(-20001, 'Параметр list_currencies не знайдено');
        WHEN OTHERS THEN
            --Логування помилки
            v_err_message := SQLERRM;
            log_util.log_error(p_proc_name => 'api_nbu_sync', p_sqlerrm => v_err_message);
            RAISE;
    END;

    --Цикд списку валют і оновлення табилці
    FOR cc IN (SELECT value_list AS curr
               FROM TABLE(util.table_from_list(p_list_val => v_list_cur))) 
    LOOP
        BEGIN
               
            INSERT INTO cur_exchange (r030, txt, rate, cur, exchangedate)
            SELECT r030, txt, rate, cur, exchangedate
            FROM TABLE(util.get_currency(p_currency => cc.curr));

            log_util.log_finish(p_proc_name => 'api_nbu_sync', p_text => 'Курс для валюти ' || cc.curr || ' успішно оновлено.');

        EXCEPTION
            WHEN OTHERS THEN
                v_err_message := SQLERRM;
                log_util.log_error(p_proc_name => 'api_nbu_sync', p_sqlerrm => 'Помилка для валюти ' || cc.curr || ': ' || v_err_message);
        END;
    END LOOP;
    
    COMMIT;
    
    EXCEPTION
    WHEN OTHERS THEN
        v_err_message := SQLERRM;
        log_util.log_error(p_proc_name => 'api_nbu_sync', p_sqlerrm => v_err_message);
        RAISE;
    END api_nbu_sync;

END log_util;
/
