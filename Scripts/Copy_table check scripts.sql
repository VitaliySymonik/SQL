DECLARE
    v_result VARCHAR2(100);
BEGIN
    log_util.copy_table(
        p_source_scheme => 'HR',  
        p_target_scheme => 'VITALIYI_7VA',  
        p_list_table    => 'REGIONAS',  
        p_copy_data     => TRUE, 
        po_result       => v_result  
    );
    DBMS_OUTPUT.PUT_LINE('���������: ' || v_result);
END;
/


--������� HR �����
SELECT * FROM all_tables 
WHERE 1=1
and owner = 'HR' 
AND table_name IN ('REGIONS');

--������� � �����
SELECT * FROM all_tables 
WHERE 1=1
and owner = 'VITALIYI_7VA' 
AND table_name IN ('REGIONS');

--������� ������ � �����
select * from logs 
order by LOG_DATE desc;
