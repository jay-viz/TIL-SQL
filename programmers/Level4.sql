-- 보호소에서 중성화한 동물
SELECT ANIMAL_ID, ANIMAL_TYPE, NAME
FROM ANIMAL_OUTS
WHERE ANIMAL_ID in (
    SELECT ANIMAL_ID
    FROM ANIMAL_INS
    WHERE SEX_UPON_INTAKE like 'Intact %')
    AND SEX_UPON_OUTCOME not like 'Intact %'
ORDER BY ANIMAL_ID


-- 5월 식품들의 총매출 조회하기
SELECT o.PRODUCT_ID, PRODUCT_NAME, p.PRICE*SUM(AMOUNT) AS TOTAL_SALES
FROM FOOD_ORDER AS o
JOIN FOOD_PRODUCT AS p ON o.PRODUCT_ID = p.PRODUCT_ID
WHERE DATE_FORMAT(PRODUCE_DATE,'%Y-%m')='2022-05'
GROUP BY PRODUCT_ID
ORDER BY TOTAL_SALES DESC, PRODUCT_ID


-- 식품분류별 가장 비싼 식품의 정보 조회하기
SELECT CATEGORY, PRICE AS MAX_PRICE, PRODUCT_NAME
FROM FOOD_PRODUCT
WHERE CATEGORY in ('과자','국','김치','식용유')
    AND PRICE in (SELECT MAX(PRICE) FROM FOOD_PRODUCT GROUP BY CATEGORY)
GROUP BY CATEGORY
ORDER BY MAX_PRICE DESC


-- 서울에 위치한 식당 목록 출력하기
SELECT i.REST_ID, REST_NAME, FOOD_TYPE, FAVORITES, ADDRESS, ROUND(AVG(REVIEW_SCORE),2) AS SCORE
FROM REST_INFO AS i
JOIN REST_REVIEW AS r ON i.REST_ID = r.REST_ID
WHERE ADDRESS LIKE '서울%'
GROUP BY REST_ID
ORDER BY SCORE DESC, FAVORITES DESC


-- 년, 월, 성별 별 상품 구매 회원 수 구하기
SELECT YEAR(SALES_DATE) AS YEAR,
    MONTH(SALES_DATE) AS MONTH,
    GENDER,
    COUNT(distinct s.USER_ID) AS USERS
FROM ONLINE_SALE AS s
JOIN USER_INFO AS i ON s.USER_ID = i.USER_ID
WHERE GENDER IS NOT NULL
GROUP BY YEAR, MONTH, GENDER
ORDER BY YEAR, MONTH, GENDER


-- 우유와 요거트가 담긴 장바구니
SELECT CART_ID
FROM CART_PRODUCTS
WHERE NAME = 'Milk'
    AND CART_ID IN (SELECT CART_ID FROM CART_PRODUCTS WHERE NAME = 'Yogurt')
ORDER BY CART_ID


-- 취소되지 않은 진료 예약 조회하기
SELECT APNT_NO, PT_NAME, a.PT_NO, a.MCDP_CD, DR_NAME, APNT_YMD
FROM APPOINTMENT AS a
JOIN PATIENT AS p ON a.PT_NO = p.PT_NO
JOIN DOCTOR AS d ON a.MDDR_ID = d.DR_ID
WHERE DATE_FORMAT(APNT_YMD,'%Y-%m-%d') = '2022-04-13'
    AND APNT_CNCL_YN = 'N'
    AND a.MCDP_CD = 'CS' 
ORDER BY APNT_YMD


-- 주문량이 많은 아이스크림들 조회하기
SELECT f.FLAVOR
FROM FIRST_HALF AS f
JOIN JULY AS j ON f.FLAVOR = j.FLAVOR
GROUP BY FLAVOR
ORDER BY SUM(f.TOTAL_ORDER)+SUM(j.TOTAL_ORDER) DESC
LIMIT 3


-- 저자 별 카테고리 별 매출액 집계하기
SELECT a.AUTHOR_ID, AUTHOR_NAME, CATEGORY, SUM(PRICE*SALES) AS TOTAL_SALES
FROM BOOK_SALES AS s
JOIN BOOK AS b ON s.BOOK_ID = b.BOOK_ID
JOIN AUTHOR AS a ON b.AUTHOR_ID = a.AUTHOR_ID
WHERE DATE_FORMAT(SALES_DATE, '%Y-%m') = '2022-01'
GROUP BY AUTHOR_ID, CATEGORY
ORDER BY AUTHOR_ID, CATEGORY DESC


-- 그룹별 조건에 맞는 식당 목록 출력하기
WITH review_rank AS (
    SELECT MEMBER_ID, COUNT(*) AS CNT
    FROM REST_REVIEW
    GROUP BY MEMBER_ID
    ORDER BY CNT DESC
    LIMIT 1
)
SELECT MEMBER_NAME, REVIEW_TEXT, DATE_FORMAT(REVIEW_DATE,'%Y-%m-%d') AS REVIEW_DATE
FROM MEMBER_PROFILE AS m
JOIN review_rank AS t ON m.MEMBER_ID = t.MEMBER_ID
JOIN REST_REVIEW AS r ON m.MEMBER_ID = r.MEMBER_ID
ORDER BY REVIEW_DATE, REVIEW_TEXT


-- 입양 시각 구하기(2)
WITH RECURSIVE H AS(
    SELECT 0 AS HOUR
    UNION ALL
    SELECT HOUR+1 FROM H WHERE HOUR <23
)
SELECT HOUR AS HOUR,
    IFNULL(COUNT(ANIMAL_ID),0) AS COUNT 
FROM ANIMAL_OUTS 
RIGHT JOIN H ON H.HOUR = HOUR(DATETIME)
GROUP BY HOUR
ORDER BY HOUR


-- 오프라인/온라인 판매 데이터 통합하기
SELECT DATE_FORMAT(SALES_DATE,'%Y-%m-%d') AS SALES_DATE,
    PRODUCT_ID, USER_ID, SALES_AMOUNT
FROM ONLINE_SALE 
WHERE LEFT(SALES_DATE,7) = '2022-03'
UNION 
SELECT DATE_FORMAT(SALES_DATE,'%Y-%m-%d') AS SALES_DATE,
    PRODUCT_ID, NULL AS USER_ID, SALES_AMOUNT
FROM OFFLINE_SALE  
WHERE LEFT(SALES_DATE,7) = '2022-03'
ORDER BY SALES_DATE, PRODUCT_ID, USER_ID


-- 특정 기간동안 대여 가능한 자동차들의 대여비용 구하기
SELECT * FROM (
    SELECT CAR_ID, c.CAR_TYPE, 
        ROUND(DAILY_FEE*((100-DISCOUNT_RATE)/100)*30,0) AS FEE
    FROM CAR_RENTAL_COMPANY_CAR AS c
    JOIN CAR_RENTAL_COMPANY_DISCOUNT_PLAN AS p 
    ON c.CAR_TYPE = p.CAR_TYPE
    WHERE c.CAR_TYPE IN ('세단','SUV')
        AND CAR_ID NOT IN (
            SELECT CAR_ID FROM CAR_RENTAL_COMPANY_RENTAL_HISTORY 
            WHERE END_DATE > '2022-11-01')
        AND DURATION_TYPE = '30일 이상'
        ) AS T
WHERE FEE >= 500000 AND FEE < 2000000
ORDER BY FEE DESC, CAR_TYPE, CAR_ID DESC


-- 자동차 대여 기록 별 대여 금액 구하기
SELECT HISTORY_ID,
    ROUND(DAILY_FEE*(1-IFNULL(DISCOUNT_RATE,0)/100)*(DATEDIFF(END_DATE,START_DATE)+1),0) AS FEE
FROM CAR_RENTAL_COMPANY_RENTAL_HISTORY AS h
JOIN CAR_RENTAL_COMPANY_CAR AS c
    ON h.CAR_ID = c.CAR_ID
LEFT JOIN CAR_RENTAL_COMPANY_DISCOUNT_PLAN AS p
    ON c.CAR_TYPE = p.CAR_TYPE 
    AND CASE WHEN DATEDIFF(END_DATE,START_DATE)+1>=90 
            THEN (SELECT p.DISCOUNT_RATE WHERE DURATION_TYPE = '90일 이상')
        WHEN DATEDIFF(END_DATE,START_DATE)+1>=30 
            THEN (SELECT p.DISCOUNT_RATE WHERE DURATION_TYPE = '30일 이상')
        WHEN DATEDIFF(END_DATE,START_DATE)+1>=7 
            THEN (SELECT p.DISCOUNT_RATE WHERE DURATION_TYPE = '7일 이상') 
        END
WHERE c.CAR_TYPE = '트럭'
ORDER BY FEE DESC, HISTORY_ID DESC
