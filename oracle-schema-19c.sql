-- alter session set container=PDB1;
alter session set "_ORACLE_SCRIPT"=true;
drop tablespace tbs_shop including contents and datafiles;
--create tablespace tbs_shop datafile '/u01/app/oracle/oradata/XE/tbs_shop.dbf' size 1G autoextend on;
create tablespace tbs_shop datafile size 1G autoextend on;

drop user shop cascade;
create user shop identified by shop
default tablespace tbs_shop
temporary tablespace temp;

grant create session, resource, dba  to shop;

--drop sequence shop.seq_product_product_id;
create sequence shop.seq_product_product_id
start with 1
increment by 1
cache 20;

--drop sequence shop.seq_comment_comment_id;
create sequence shop.seq_comment_comment_id
start with 1
increment by 1
cache 20;

--drop sequence shop.seq_order_order_id;
create sequence shop.seq_order_order_id
start with 1
increment by 1
nomaxvalue
nocycle
cache 20;


-- rownum 를 이용한 페이징 처리 체크.
-- lob 데이터 마이그 확인
-- 각종 데이터타입 변환 정보확인
-- display 의 경우 char, varchar로 서로 다름.

--drop table shop.tb_category;
create table shop.tb_category
(
   category_id       number(4) not null primary key,
   category_name     varchar(300) not null,
   display_yn        varchar(1) default 'Y' not null
);

--drop table shop.tb_product;
create table shop.tb_product
(
   product_id         number(9) not null,
   category_id        number(4) not null,
   name               varchar2(100) not null,
   price              number(19,3) not null,
   description        clob,
   image_data         blob,
   thumb_image_url    varchar2(300),
   image_url          varchar2(300),
   delivery_type      varchar2(10) not null,
   comment_cnt        number(9) default 0 not null,
   buy_cnt            number(9) default 0 not null,
   display_yn         char(1) default 'Y',
   reg_ymdt           date default sysdate not null,
   upd_ymdt           date,
   primary key(product_id)
);

create index shop.idx_product_01 on shop.tb_product(category_id, product_id);

--drop table shop.tb_comment;
create table shop.tb_comment
(
   comment_id         number not null,
   member_id          varchar2(30) not null,
   product_id         number(9) not null,
   score              varchar(1) not null,
   comment_body       varchar(4000),
   primary key(comment_id)
);

create index shop.idx_comment_01 on shop.tb_comment(member_id, comment_id);


-- order_no YYYYMMDD + serial(12자리) 어플리케이션에서 발행(프로시저로 만듬)
-- 체크 제약조건이 제대로 변환되는지 확인한다.

--drop table shop.tb_order;
create table shop.tb_order
(
   order_no                varchar2(20) not null primary key,
   member_id               varchar2(30) not null,
   order_price             number(19,3) not null,
   order_ymdt              date default sysdate,
   pay_status              varchar2(10) not null,
   pay_ymdt                date,
   error_ymdt              date,
   error_message           date,
   error_cd                varchar2(3),
   constraint check_pay_status
   check(pay_status in ('Queued', 'Processing', 'error', 'Completed'))
);


--drop table shop.tb_order_detail;
create table shop.tb_order_detail
(
   order_no                varchar2(20) not null,
   product_id              number(9),
   product_price           number(19,3) not null,
   product_cnt             number,
   primary key(order_no, product_id)
);


-- added 2021/02/01
-- view
create or replace view shop.view_recent_order_30 as
select name, order_no, member_id, order_price, order_ymdt
from (
    select rownum as rn, p.name, o.order_no, o.member_id, o.order_price, o.order_ymdt
    from shop.tb_order o, shop.tb_order_detail d, shop.tb_product p
    where o.order_no = d.order_no
      and d.product_id = p.product_id
    order by o.order_ymdt desc
)
where rn between 1 and 30;

-- function
DROP FUNCTION shop.get_product_id;
CREATE OR REPLACE FUNCTION shop.get_product_id
RETURN VARCHAR2
IS
    v_today           VARCHAR2(8);
    v_sub_order_no    VARCHAR(12);
BEGIN

    select to_char(sysdate, 'yyyymmdd') into v_today from dual;
    select lpad(shop.seq_order_order_id.nextval, 12, '0') into v_sub_order_no from dual;

    return v_today || v_sub_order_no;
END;
/

-- procedure
drop table shop.tb_product_summary;
create table shop.tb_product_summary
(
   year           varchar2(4) not null,
   month          varchar2(2) not null,
   day            varchar2(2) not null,
   hour           varchar2(2) not null,
   min            varchar2(2) not null,
   product_id     number(9) not null,
   order_cnt      number not null,
   total_price    number not null,
   comment_cnt    number not null,
   primary key(year, month, day, hour, min, product_id)
);

CREATE OR REPLACE PROCEDURE shop.sp_product_summary(v_interval in number)
IS
    v_cnt NUMBER := 0;
BEGIN
    -- truncate table.
    execute immediate 'truncate table test_table';

    insert into shop.tb_product_summary
    select to_char(o.order_ymdt, 'yyyy') as year,
        to_char(o.order_ymdt, 'mm') as month,
        to_char(o.order_ymdt, 'dd') as day,
        to_char(o.order_ymdt, 'hh') as hour,
        to_char(o.order_ymdt, 'mm') as min,
        p.product_id,
        count(1) as order_cnt,
        sum(d.product_price) as total_price,
        max(c.comment_cnt) as comment_cnt
    from
        shop.tb_order o,
        shop.tb_order_detail d,
        shop.tb_product p,
        (select product_id, count(1) as comment_cnt
         from shop.tb_comment
         group by product_id) c
    where o.order_no = d.order_no
      and d.product_id = p.product_id
      and p.product_id = c.product_id(+)
    group by to_char(o.order_ymdt, 'yyyy'),
        to_char(o.order_ymdt, 'mm'),
        to_char(o.order_ymdt, 'dd'),
        to_char(o.order_ymdt, 'hh'),
        to_char(o.order_ymdt, 'mm'),
        p.product_id;

    COMMIT;
END;
/



quit