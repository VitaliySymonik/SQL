CREATE OR REPLACE PROCEDURE api_nbu_sync IS
    v_list_cur  VARCHAR2(2000);
    v_err_message    VARCHAR2(1000);
    BEGIN
    --������ �����
    BEGIN
        SELECT value_text
        INTO v_list_cur
        FROM sys_params
        WHERE param_name = 'list_currencies';

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            --��������� ������� ���� ��������� ����
            log_util.log_error(p_proc_name => 'api_nbu_sync', p_sqlerrm => '�������� list_currencies �� ��������');
            RAISE_APPLICATION_ERROR(-20001, '�������� list_currencies �� ��������');
        WHEN OTHERS THEN
            --��������� �������
            v_err_message := SQLERRM;
            log_util.log_error(p_proc_name => 'api_nbu_sync', p_sqlerrm => v_err_message);
            RAISE;
    END;

    --���� ������ ����� � ��������� �������
    FOR cc IN (SELECT value_list AS curr
               FROM TABLE(util.table_from_list(p_list_val => v_list_cur))) 
    LOOP
        BEGIN
               
            INSERT INTO cur_exchange (r030, txt, rate, cur, exchangedate)
            SELECT r030, txt, rate, cur, exchangedate
            FROM TABLE(util.get_currency(p_currency => cc.curr));

            log_util.log_finish(p_proc_name => 'api_nbu_sync', p_text => '���� ��� ������ ' || cc.curr || ' ������ ��������.');

        EXCEPTION
            WHEN OTHERS THEN
                v_err_message := SQLERRM;
                log_util.log_error(p_proc_name => 'api_nbu_sync', p_sqlerrm => '������� ��� ������ ' || cc.curr || ': ' || v_err_message);
        END;
    END LOOP;
    
    COMMIT;
    
    EXCEPTION
    WHEN OTHERS THEN
        v_err_message := SQLERRM;
        log_util.log_error(p_proc_name => 'api_nbu_sync', p_sqlerrm => v_err_message);
        RAISE;
    END api_nbu_sync;
