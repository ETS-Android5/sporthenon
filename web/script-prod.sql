CREATE OR REPLACE FUNCTION "Search"(
    _pattern character varying,
    _scope character varying,
    _limit smallint,
    _lang character varying)
  RETURNS SETOF "~RefItem" AS
$BODY$
declare
	_item "~RefItem"%rowtype;
	_index smallint;
	_current_id integer;
	_current_label varchar(100);
	_current_label_en varchar(100);
	_current_id_rel1 integer;
	_current_id_rel2 integer;
	_current_id_rel3 integer;
	_current_label_rel1 varchar(50);
	_current_label_rel2 varchar(50);
	_current_label_rel3 varchar(50);
	_current_label_rel4 varchar(50);
	_current_label_rel5 varchar(50);
	_current_label_rel6 varchar(50);
	_current_link integer;
	_current_ref smallint;
	_scopes varchar(2)[];
	_tables varchar(15)[];
	_label varchar(10);
	_label_en varchar(10);
	_i smallint;
	_s varchar(2);
	_c refcursor;
	_query text;
	_rel_cols text;
	_rel_joins text;
	_rel_count smallint;
	__pattern text;
begin
	INSERT INTO "~Request" VALUES (NEXTVAL('"~SeqRequest"'), 'SC', _pattern, current_date);
	
	_i := 1;
	_index := 1;
	__pattern := "~PatternString"(_pattern);
	_scopes := '{PR,CT,CX,CN,CP,EV,SP,TM,ST,YR}';
	_tables := '{Athlete,City,Complex,Country,Championship,Event,Sport,Team,State,Year}';
	FOR _s IN SELECT UNNEST(_scopes) LOOP
		IF _scope ~ ('(^|,)' || _s || '($|,)') OR _scope = '.' THEN
			_rel_cols := '';
			_rel_joins := '';
			_rel_count := 0;

			-- Get related fields
			IF (_s ~ 'PR|TM') THEN -- Relation: Country
				_rel_cols := _rel_cols || ', CN.id, CN.label' || _lang || ' || '' ('' || CN.code || '')'', CN.code';
				_rel_joins := _rel_joins || ' LEFT JOIN "Country" CN ON ' || _s || '.id_country = CN.id';
				_rel_count := _rel_count + 1;
			END IF;
			IF (_s ~ 'PR|TM') THEN -- Relation: Sport
				_rel_cols := _rel_cols || ', SP.id, SP.label' || _lang || ', SP.label';
				_rel_joins := _rel_joins || ' LEFT JOIN "Sport" SP ON ' || _s || '.id_sport = SP.id';
				_rel_count := _rel_count + 1;
			END IF;
			IF (_s = 'PR') THEN -- Relation: Team
				_rel_cols := _rel_cols || ', TM.id, TM.label, TM.label';
				_rel_joins := _rel_joins || ' LEFT JOIN "Team" TM ON ' || _s || '.id_team = TM.id';
				_rel_count := _rel_count + 1;
			END IF;
			IF (_s = 'CX') THEN -- Relation: City/State/Country
				_rel_cols := _rel_cols || ', CT.id, CT.label' || _lang || ', CT.label';
				_rel_cols := _rel_cols || ', ST.id, ST.label' || _lang || ', ST.label';
				_rel_cols := _rel_cols || ', CN.id, CN.label' || _lang || ', CN.label';
				_rel_joins := _rel_joins || ' LEFT JOIN "City" CT ON ' || _s || '.id_city = CT.id';
				_rel_joins := _rel_joins || ' LEFT JOIN "State" ST ON CT.id_state = ST.id';
				_rel_joins := _rel_joins || ' LEFT JOIN "Country" CN ON CT.id_country = CN.id';
				_rel_count := _rel_count + 3;
			END IF;
			IF (_s = 'CT') THEN -- Relation: State/Country
				_rel_cols := _rel_cols || ', NULL, NULL, NULL';
				_rel_cols := _rel_cols || ', ST.id, ST.label' || _lang || ', ST.label';
				_rel_cols := _rel_cols || ', CN.id, CN.label' || _lang || ', CN.label';
				_rel_joins := _rel_joins || ' LEFT JOIN "State" ST ON ' || _s || '.id_state = ST.id';
				_rel_joins := _rel_joins || ' LEFT JOIN "Country" CN ON ' || _s || '.id_country = CN.id';
				_rel_count := _rel_count + 3;
			END IF;
			FOR _j IN (_rel_count + 1)..3 LOOP
				_rel_cols := _rel_cols || ', NULL, NULL, NULL';
			END LOOP;
			IF (_s ~ 'CT|CX|PR|TM') THEN
				_rel_cols := _rel_cols || ', ' || _s || '.link';
			END IF;
			
			-- Execute query
			_label := 'label';
			_label_en := 'label';
			IF (_s <> 'TM' AND _s <> 'YR') THEN
				_label := 'label' || _lang;
			END IF;
			_query := 'SELECT ' || _s || '.id, ' || _s || '.' || _label || ',' || _s || '.' || _label_en || ',' || _s || '.ref' || _rel_cols || ' FROM "' || _tables[_i] || '" ' || _s;
			_query := _query || _rel_joins || ' WHERE ' || (CASE _s WHEN 'CT' THEN '(CT.link = 0 OR CT.link IS NULL) AND ' WHEN 'CX' THEN '(CX.link = 0 OR CX.link IS NULL) AND ' WHEN 'TM' THEN '(TM.link = 0 OR TM.link IS NULL OR (TM.year1 IS NOT NULL AND TM.year1 <> '''')) AND ' ELSE '' END) || 'lower(' || _s || '.' || _label || ') ~ ''' || __pattern || '''' || (CASE _limit WHEN 0 THEN ' ORDER BY ' || _s || '.' || _label ELSE '' END);
			IF _s = 'PR' THEN
				_query := 'SELECT PR.id, PR.last_name || (CASE WHEN length(PR.first_name) > 0 THEN '', '' || PR.first_name ELSE '''' END), (CASE WHEN length(PR.first_name) > 0 THEN PR.first_name || '' '' ELSE '''' END) || PR.last_name, PR.ref' || _rel_cols || ' FROM "Athlete" PR' || _rel_joins;
				_query := _query || ' WHERE (PR.link = 0 OR PR.link IS NULL) AND (lower(PR.last_name || '' '' || PR.first_name) ~ ''' || __pattern || ''' OR lower(PR.first_name || '' '' || PR.last_name) ~ ''' || __pattern || ''' OR lower(PR.last_name) ~ ''' || __pattern || ''' OR lower(PR.first_name) ~ ''' || __pattern || ''')';
				_query := _query || (CASE _limit WHEN 0 THEN ' ORDER BY PR.last_name, PR.first_name' ELSE '' END);
			END IF;
			OPEN _c FOR EXECUTE _query;
			LOOP
				FETCH _c INTO _current_id, _current_label, _current_label_en, _current_ref, _current_id_rel1, _current_label_rel1, _current_label_rel4, _current_id_rel2, _current_label_rel2, _current_label_rel5, _current_id_rel3, _current_label_rel3, _current_label_rel6, _current_link;
				EXIT WHEN NOT FOUND;
				_item.id = _index;
				_item.id_item = _current_id;
				_item.label = _current_label;
				IF _current_link IS NOT NULL THEN
					IF _s = 'CT' THEN
						SELECT SUM(ref) INTO _item.count_ref FROM "City" WHERE id=_current_id OR link=_current_id;
					ELSIF _s = 'CX' THEN
						SELECT SUM(ref) INTO _item.count_ref FROM "Complex" WHERE id=_current_id OR link=_current_id;
					ELSIF _s = 'PR' THEN
						SELECT SUM(ref) INTO _item.count_ref FROM "Athlete" WHERE id=_current_id OR link=_current_id;
					ELSIF _s = 'TM' THEN
						SELECT SUM(ref) INTO _item.count_ref FROM "Team" WHERE id=_current_id OR link=_current_id;
					END IF;
				ELSE
					_item.count_ref = (CASE WHEN _current_ref IS NOT NULL THEN _current_ref ELSE 0 END);
				END IF;
				_item.entity = _s;
				_item.label_rel1 = _current_label_rel1;
				_item.label_rel2 = _current_label_rel2;
				_item.label_rel3 = _current_label_rel3;
				IF _limit = 0 THEN
					_item.label_en = _current_label_en;
					_item.id_rel1 = _current_id_rel1;
					_item.id_rel2 = _current_id_rel2;
					_item.id_rel3 = _current_id_rel3;
					_item.label_rel4 = _current_label_rel4;
					_item.label_rel5 = _current_label_rel5;
					_item.label_rel6 = _current_label_rel6;
					_item.link = _current_link;
				END IF;
				RETURN NEXT _item;
				_index := _index + 1;
			END LOOP;			
			CLOSE _c;
		END IF;
		_i := _i + 1;
	END LOOP;
	RETURN;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;

  
  
  
  
  
  
  ALTER TABLE "Calendar" ADD id_country integer;

ALTER TABLE "Result" ADD id_country1 integer;

ALTER TABLE "Result" ADD id_country2 integer;

  
  
  
  
  
  CREATE OR REPLACE FUNCTION "GetResults"(
    _id_sport integer,
    _id_championship integer,
    _id_event integer,
    _id_subevent integer,
    _id_subevent2 integer,
    _years text,
    _lang character varying)
  RETURNS refcursor AS
$BODY$
declare
    _c refcursor;
    _type integer;
    _columns text;
    _joins text;
    _event_condition text;
    _year_condition text;
begin
	INSERT INTO "~Request" VALUES (NEXTVAL('"~SeqRequest"'), 'RS', _id_sport || '-' || _id_championship, current_date);

	-- Get entity type (person, country, team)
	IF _id_subevent2 <> 0 THEN
	    SELECT
	        TP.number
	    INTO
	        _type
	    FROM
	        "Event" EV
	        LEFT JOIN "Type" TP ON EV.id_type = TP.id
	    WHERE
	        EV.id = _id_subevent2;
	ELSIF _id_subevent <> 0 THEN
	    SELECT
	        TP.number
	    INTO
	        _type
	    FROM
	        "Event" EV
	        LEFT JOIN "Type" TP ON EV.id_type = TP.id
	    WHERE
	        EV.id = _id_subevent;
	ELSIF _id_event <> 0 THEN
	    SELECT
	        TP.number
	    INTO
	        _type
	    FROM
	        "Event" EV
	        LEFT JOIN "Type" TP ON EV.id_type = TP.id
	    WHERE
	        EV.id = _id_event;	        
	ELSE
	    SELECT DISTINCT
	        TP.number
	    INTO
	        _type
	    FROM
	        "Result" RS
	        LEFT JOIN "Event" EV ON RS.id_event = EV.id
	        LEFT JOIN "Type" TP ON EV.id_type = TP.id
	    WHERE
	         RS.id_sport = _id_sport AND RS.id_championship = _id_championship;
	END IF;

	-- Build entity-specific columns/joins
	_columns := '';
	_joins := '';
	FOR i IN 1..20 LOOP
	    IF _type < 10 THEN -- Person
	        _columns := _columns || ', PR' || i || '.last_name AS en' || i || '_str1, PR' || i || '.first_name AS en' || i || '_str2, NULL AS en' || i || '_str3';
	        _columns := _columns || ', PRTM' || i || '.id AS en' || i || '_rel1_id, NULL AS en' || i || '_rel1_code, PRTM' || i || '.label AS en' || i || '_rel1_label';
	        _columns := _columns || ', PRCN' || i || '.id AS en' || i || '_rel2_id, PRCN' || i || '.code AS en' || i || '_rel2_code, PRCN' || i || '.label' || _lang || ' AS en' || i || '_rel2_label, PRCN' || i || '.label AS en' || i || '_rel2_label_en';
	        _joins := _joins || ' LEFT JOIN "Athlete" PR' || i || ' ON RS.id_rank' || i || ' = PR' || i || '.id';
	        _joins := _joins || ' LEFT JOIN "Team" PRTM' || i || ' ON PR' || i || '.id_team = PRTM' || i || '.id';
	        _joins := _joins || ' LEFT JOIN "Country" PRCN' || i || ' ON PR' || i || '.id_country = PRCN' || i || '.id';
	    ELSIF _type = 50 THEN -- Team
	        _columns := _columns || ', NULL AS en' || i || '_str1, TM' || i || '.label AS en' || i || '_str2, NULL AS en' || i || '_str3';
	        _columns := _columns || ', NULL AS en' || i || '_rel1_id, NULL AS en' || i || '_rel1_code, NULL AS en' || i || '_rel1_label';
	        _columns := _columns || ', TMCN' || i || '.id AS en' || i || '_rel2_id, TMCN' || i || '.code AS en' || i || '_rel2_code, TMCN' || i || '.label' || _lang || ' AS en' || i || '_rel2_label, TMCN' || i || '.label AS en' || i || '_rel2_label_en';
	        _joins := _joins || ' LEFT JOIN "Team" TM' || i || ' ON RS.id_rank' || i || ' = TM' || i || '.id';
	        _joins := _joins || ' LEFT JOIN "Country" TMCN' || i || ' ON TM' || i || '.id_country = TMCN' || i || '.id';
	    ELSIF _type = 99 THEN -- Country
	        _columns := _columns || ', _CN' || i || '.code AS en' || i || '_str1, _CN' || i || '.label' || _lang || ' AS en' || i || '_str2, _CN' || i || '.label AS en' || i || '_str3';
	        _columns := _columns || ', NULL AS en' || i || '_rel1_id, NULL AS en' || i || '_rel1_code, NULL AS en' || i || '_rel1_label';
	        _columns := _columns || ', NULL AS en' || i || '_rel2_id, NULL AS en' || i || '_rel2_code, NULL AS en' || i || '_rel2_label, NULL AS en' || i || '_rel2_label_en';
	        _joins := _joins || ' LEFT JOIN "Country" _CN' || i || ' ON RS.id_rank' || i || ' = _CN' || i || '.id';
	    END IF;
	END LOOP;

	-- Handle null event/subevent
	_event_condition := '';
	IF _id_event <> 0 THEN
	    _event_condition := ' AND RS.id_event = ' ||_id_event;
	END IF;
	IF _id_subevent <> 0 THEN
	    _event_condition := _event_condition || ' AND RS.id_subevent = ' ||_id_subevent;
	END IF;
	IF _id_subevent2 <> 0 THEN
	    _event_condition := _event_condition || ' AND RS.id_subevent2 = ' ||_id_subevent2;
	END IF;

	-- Set year condition
	_year_condition := '';
	IF _years <> '0' THEN
		_year_condition := ' AND YR.id IN (' || _years || ')';
	END IF;
	
	-- Open cursor
	OPEN _c FOR EXECUTE
	'SELECT
		RS.id AS rs_id, RS.date1 AS rs_date1, RS.date2 AS rs_date2, RS.id_rank1 AS rs_rank1, RS.id_rank2 AS rs_rank2, RS.id_rank3 AS rs_rank3, RS.id_rank4 AS rs_rank4, RS.id_rank5 AS rs_rank5, RS.id_rank6 AS rs_rank6, RS.id_rank7 AS rs_rank7, RS.id_rank8 AS rs_rank8, RS.id_rank9 AS rs_rank9, RS.id_rank10 AS rs_rank10, RS.id_rank11 AS rs_rank11, RS.id_rank12 AS rs_rank12, RS.id_rank13 AS rs_rank13, RS.id_rank14 AS rs_rank14, RS.id_rank15 AS rs_rank15, RS.id_rank16 AS rs_rank16, RS.id_rank17 AS rs_rank17, RS.id_rank18 AS rs_rank18, RS.id_rank19 AS rs_rank19, RS.id_rank20 AS rs_rank20,
		RS.result1 AS rs_result1, RS.result2 AS rs_result2, RS.result3 AS rs_result3, RS.result4 AS rs_result4, RS.result5 AS rs_result5, RS.result6 AS rs_result6, RS.result7 AS rs_result7, RS.result8 AS rs_result8, RS.result9 AS rs_result9, RS.result10 AS rs_result10, RS.result11 AS rs_result11, RS.result12 AS rs_result12, RS.result13 AS rs_result13, RS.result14 AS rs_result14, RS.result15 AS rs_result15, RS.result16 AS rs_result16, RS.result17 AS rs_result17, RS.result18 AS rs_result18, RS.result19 AS rs_result19, RS.result20 AS rs_result20,
		RS.comment AS rs_comment, RS.exa AS rs_exa, YR.id AS yr_id, YR.label AS yr_label, CX1.id AS cx1_id, CX1.label' || _lang || ' AS cx1_label, CX1.label AS cx1_label_en, CX2.id AS cx2_id, CX2.label' || _lang || ' AS cx2_label, CX2.label AS cx2_label_en,
		CT1.id AS ct1_id, CT1.label' || _lang || ' AS ct1_label, CT1.label AS ct1_label_en, CT2.id AS ct2_id, CT2.label' || _lang || ' AS ct2_label, CT2.label AS ct2_label_en, CT3.id AS ct3_id, CT3.label' || _lang || ' AS ct3_label, CT3.label AS ct3_label_en, CT4.id AS ct4_id, CT4.label' || _lang || ' AS ct4_label, CT4.label AS ct4_label_en, ST1.id AS st1_id, ST1.code AS st1_code, ST1.label' || _lang || ' AS st1_label, ST1.label AS st1_label_en, ST2.id AS st2_id, ST2.code AS st2_code,
		ST2.label' || _lang || ' AS st2_label, ST2.label AS st2_label_en, ST3.id AS st3_id, ST3.code AS st3_code, ST3.label' || _lang || ' AS st3_label, ST3.label AS st3_label_en, ST4.id AS st4_id, ST4.code AS st4_code, ST4.label' || _lang || ' AS st4_label, ST4.label AS st4_label_en, CN1.id AS cn1_id, CN1.code AS cn1_code, CN1.label' || _lang || ' AS cn1_label, CN1.label AS cn1_label_en, CN2.id AS cn2_id, CN2.code AS cn2_code, CN2.label' || _lang || ' AS cn2_label, CN2.label AS cn2_label_en, CN3.id AS cn3_id, CN3.code AS cn3_code, CN3.label' || _lang || ' AS cn3_label, CN3.label AS cn3_label_en, CN4.id AS cn4_id, CN4.code AS cn4_code, CN4.label' || _lang || ' AS cn4_label, CN4.label AS cn4_label_en, CN5.id AS cn5_id, CN5.code AS cn5_code, CN5.label' || _lang || ' AS cn5_label, CN5.label AS cn5_label_en, CN6.id AS cn6_id, CN6.code AS cn6_code, CN6.label' || _lang || ' AS cn6_label, CN6.label AS cn6_label_en' ||
		_columns || '
	FROM
		"Result" RS
		LEFT JOIN "Year" YR ON RS.id_year = YR.id
		LEFT JOIN "Complex" CX1 ON RS.id_complex1 = CX1.id
		LEFT JOIN "Complex" CX2 ON RS.id_complex2 = CX2.id
		LEFT JOIN "City" CT1 ON CX1.id_city = CT1.id
		LEFT JOIN "City" CT2 ON RS.id_city1 = CT2.id
		LEFT JOIN "City" CT3 ON CX2.id_city = CT3.id
		LEFT JOIN "City" CT4 ON RS.id_city2 = CT4.id
		LEFT JOIN "State" ST1 ON CT1.id_state = ST1.id
		LEFT JOIN "State" ST2 ON CT2.id_state = ST2.id
		LEFT JOIN "State" ST3 ON CT3.id_state = ST3.id
		LEFT JOIN "State" ST4 ON CT4.id_state = ST4.id
		LEFT JOIN "Country" CN1 ON CT1.id_country = CN1.id
		LEFT JOIN "Country" CN2 ON CT2.id_country = CN2.id
		LEFT JOIN "Country" CN3 ON CT3.id_country = CN3.id
		LEFT JOIN "Country" CN4 ON CT4.id_country = CN4.id
		LEFT JOIN "Country" CN5 ON RS.id_country1 = CN5.id
		LEFT JOIN "Country" CN6 ON RS.id_country2 = CN6.id' ||
		_joins || '
	WHERE
		RS.id_sport = ' || _id_sport || ' AND
		RS.id_championship = ' || _id_championship ||
		_event_condition || _year_condition || '
	ORDER BY RS.id_year DESC';
	
	RETURN  _c;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  
  
  
  
  
  CREATE OR REPLACE FUNCTION "GetCalendarResults"(
    _date1 character varying,
    _date2 character varying,
    _sp integer,
    _lang character varying)
  RETURNS SETOF "~RefItem" AS
$BODY$
declare
	_item "~RefItem"%rowtype;
	_c refcursor;
	__c refcursor;
	_query text;
	_where text;
	_index integer;
	_type1 smallint;
	_type2 smallint;
	_type3 smallint;
	_date1 varchar(10) := _date1;
	_date2 varchar(10) := _date2;
	_id1 integer;_id2 integer;_id3 integer;_id4 integer;_id5 integer;
	_id6 integer;_id7 integer;_id8 integer;_id9 integer;_id10 integer;
	_cn1 varchar(5);_cn2 varchar(5);_cn3 varchar(5);_cn4 varchar(5);_cn5 varchar(5);_cn6 varchar(5);
	_tm1 varchar(60);_tm2 varchar(60);_tm3 varchar(60);_tm4 varchar(60);_tm5 varchar(60);_tm6 varchar(60);
begin
	_where := ' WHERE to_date(date2, ''DD/MM/YYYY'') >= to_date(''' || _date1 || ''', ''YYYYMMDD'') AND to_date(date2, ''DD/MM/YYYY'') <= to_date(''' || _date2 || ''', ''YYYYMMDD'')';
	IF (_sp > 0) THEN
		_where := _where || ' AND SP.id = ' || _sp;
	END IF;

	-- Past events
	_query := 'SELECT RS.id, YR.id, YR.label, SP.id, SP.label' || _lang || ', CP.id, CP.label' || _lang || ', EV.id, EV.label' || _lang || ', SE.id, SE.label' || _lang || ', SE2.id, SE2.label' || _lang || ', SP.label, CP.label, EV.label, SE.label, SE2.label, RS.id_rank1, RS.id_rank2, RS.id_rank3, RS.id_rank4, RS.id_rank5, RS.id_rank6, RS.id_rank7, RS.id_rank8, RS.id_rank9, RS.id_rank10, TP1.number, TP2.number, TP3.number, RS.date1, RS.date2';
	_query := _query || ' FROM "Result" RS';
	_query := _query || ' LEFT JOIN "Year" YR ON RS.id_year = YR.id';
	_query := _query || ' LEFT JOIN "Sport" SP ON RS.id_sport = SP.id';
	_query := _query || ' LEFT JOIN "Championship" CP ON RS.id_championship = CP.id';
	_query := _query || ' LEFT JOIN "Event" EV ON RS.id_event = EV.id';
	_query := _query || ' LEFT JOIN "Event" SE ON RS.id_subevent = SE.id';
	_query := _query || ' LEFT JOIN "Event" SE2 ON RS.id_subevent2 = SE2.id';
	_query := _query || ' LEFT JOIN "Type" TP1 ON EV.id_type = TP1.id';
	_query := _query || ' LEFT JOIN "Type" TP2 ON SE.id_type = TP2.id';
	_query := _query || ' LEFT JOIN "Type" TP3 ON SE2.id_type = TP3.id' || _where;
	_index := 1;
	OPEN _c FOR EXECUTE _query;
	LOOP
		FETCH _c INTO _item.id_item, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.id_rel3, _item.label_rel3, _item.id_rel4, _item.label_rel4, _item.id_rel5, _item.label_rel5, _item.id_rel18, _item.label_rel18, _item.label_rel12, _item.label_rel13, _item.label_rel14, _item.label_rel15, _item.label_rel16, _id1, _id2, _id3, _id4, _id5, _id6, _id7, _id8, _id9, _id10, _type1, _type2, _type3, _date1, _date2, _item.count1;
		EXIT WHEN NOT FOUND;
		IF _type3 IS NOT NULL THEN
			_type1 = _type3;
		ELSIF _type2 IS NOT NULL THEN
			_type1 = _type2;
		END IF;
		IF _type1 <= 10 THEN
			SELECT id_rank1, id_rank2, id_rank3, id_rank4, id_rank5, id_rank6, PR1.last_name || (CASE WHEN length(PR1.first_name) > 0 THEN ', ' || PR1.first_name ELSE '' END), (CASE WHEN length(PR1.first_name) > 0 THEN PR1.first_name || ' ' ELSE '' END) || PR1.last_name, CN1.id, CN1.code, TM1.label, PR2.last_name || (CASE WHEN length(PR2.first_name) > 0 THEN ', ' || PR2.first_name ELSE '' END), (CASE WHEN length(PR2.first_name) > 0 THEN PR2.first_name || ' ' ELSE '' END) || PR2.last_name, CN2.id, CN2.code, TM2.label, PR3.last_name || (CASE WHEN length(PR3.first_name) > 0 THEN ', ' || PR3.first_name ELSE '' END), (CASE WHEN length(PR3.first_name) > 0 THEN PR3.first_name || ' ' ELSE '' END) || PR3.last_name, CN3.id, CN3.code, TM3.label, PR4.last_name || (CASE WHEN length(PR4.first_name) > 0 THEN ', ' || PR4.first_name ELSE '' END), (CASE WHEN length(PR4.first_name) > 0 THEN PR4.first_name || ' ' ELSE '' END) || PR4.last_name, CN4.id, CN4.code, TM4.label, PR5.last_name || (CASE WHEN length(PR5.first_name) > 0 THEN ', ' || PR5.first_name ELSE '' END), (CASE WHEN length(PR5.first_name) > 0 THEN PR5.first_name || ' ' ELSE '' END) || PR5.last_name, CN5.id, CN5.code, TM5.label, PR6.last_name || (CASE WHEN length(PR6.first_name) > 0 THEN ', ' || PR6.first_name ELSE '' END), (CASE WHEN length(PR6.first_name) > 0 THEN PR6.first_name || ' ' ELSE '' END) || PR6.last_name, CN6.id, CN6.code, TM6.label, RS.result1, RS.result2, RS.comment, RS.exa
			INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.id_rel9, _item.id_rel10, _item.id_rel11, _item.label_rel6, _item.label_rel20, _item.id_rel12, _cn1, _tm1, _item.label_rel7, _item.label_rel21, _item.id_rel13, _cn2, _tm2, _item.label_rel8, _item.label_rel22, _item.id_rel14, _cn3, _tm3, _item.label_rel9, _item.label_rel23, _item.id_rel15, _cn4, _tm4, _item.label_rel10, _item.label_rel24, _item.id_rel16, _cn5, _tm5, _item.label_rel11, _item.label_rel25, _item.id_rel17, _cn6, _tm6, _item.txt1, _item.txt2, _item.txt3, _item.txt4
			FROM "Result" RS LEFT JOIN "Athlete" PR1 ON RS.id_rank1 = PR1.id LEFT JOIN "Athlete" PR2 ON RS.id_rank2 = PR2.id LEFT JOIN "Athlete" PR3 ON RS.id_rank3 = PR3.id LEFT JOIN "Athlete" PR4 ON RS.id_rank4 = PR4.id LEFT JOIN "Athlete" PR5 ON RS.id_rank5 = PR5.id LEFT JOIN "Athlete" PR6 ON RS.id_rank6 = PR6.id LEFT JOIN "Country" CN1 ON PR1.id_country = CN1.id LEFT JOIN "Country" CN2 ON PR2.id_country = CN2.id LEFT JOIN "Country" CN3 ON PR3.id_country = CN3.id LEFT JOIN "Country" CN4 ON PR4.id_country = CN4.id LEFT JOIN "Country" CN5 ON PR5.id_country = CN5.id LEFT JOIN "Country" CN6 ON PR6.id_country = CN6.id LEFT JOIN "Team" TM1 ON PR1.id_team = TM1.id LEFT JOIN "Team" TM2 ON PR2.id_team = TM2.id LEFT JOIN "Team" TM3 ON PR3.id_team = TM3.id LEFT JOIN "Team" TM4 ON PR4.id_team = TM4.id LEFT JOIN "Team" TM5 ON PR5.id_team = TM5.id LEFT JOIN "Team" TM6 ON PR6.id_team = TM6.id
			WHERE RS.id = _item.id_item;
			IF _cn1 IS NOT NULL THEN _item.label_rel6 = _item.label_rel6 || ' (' || _cn1 || ')';
			ELSIF _tm1 IS NOT NULL THEN _item.label_rel6 = _item.label_rel6 || ' (' || _tm1 || ')'; END IF;
			IF _cn2 IS NOT NULL THEN _item.label_rel7 = _item.label_rel7 || ' (' || _cn2 || ')';
			ELSIF _tm2 IS NOT NULL THEN _item.label_rel7 = _item.label_rel7 || ' (' || _tm2 || ')'; END IF;
			IF _cn3 IS NOT NULL THEN _item.label_rel8 = _item.label_rel8 || ' (' || _cn3 || ')';
			ELSIF _tm3 IS NOT NULL THEN _item.label_rel8 = _item.label_rel8 || ' (' || _tm3 || ')'; END IF;
			IF _cn4 IS NOT NULL THEN _item.label_rel9 = _item.label_rel9 || ' (' || _cn4 || ')';
			ELSIF _tm4 IS NOT NULL THEN _item.label_rel9 = _item.label_rel9 || ' (' || _tm4 || ')'; END IF;
			IF _cn5 IS NOT NULL THEN _item.label_rel10 = _item.label_rel10 || ' (' || _cn5 || ')';
			ELSIF _tm5 IS NOT NULL THEN _item.label_rel10 = _item.label_rel10 || ' (' || _tm5 || ')'; END IF;
			IF _cn6 IS NOT NULL THEN _item.label_rel11 = _item.label_rel11 || ' (' || _cn6 || ')';
			ELSIF _tm6 IS NOT NULL THEN _item.label_rel11 = _item.label_rel11 || ' (' || _tm6 || ')'; END IF;
			IF _type1 = 4 OR _item.txt3 = '#DOUBLE#' THEN
				_item.txt4 = '1-2/3-4/5-6';
			ELSIF _type1 = 5 OR _item.txt3 = '#TRIPLE#' THEN
				_item.txt4 = '1-3/4-6/7-9';
			END IF;
			_item.comment = 'PR';
		ELSIF _type1 = 50 THEN
			SELECT id_rank1, id_rank2, id_rank3, id_rank4, id_rank5, id_rank6, TM1.label, TM2.label, TM3.label, TM4.label, TM5.label, TM6.label, NULL, NULL, NULL, NULL, NULL, NULL, RS.result1, RS.result2, RS.comment, RS.exa
			INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.id_rel9, _item.id_rel10, _item.id_rel11, _item.label_rel6, _item.label_rel7, _item.label_rel8, _item.label_rel9, _item.label_rel10, _item.label_rel11, _item.label_rel20, _item.label_rel21, _item.label_rel22, _item.label_rel23, _item.label_rel24, _item.label_rel25, _item.txt1, _item.txt2, _item.txt3, _item.txt4
			FROM "Result" RS LEFT JOIN "Team" TM1 ON RS.id_rank1 = TM1.id LEFT JOIN "Team" TM2 ON RS.id_rank2 = TM2.id LEFT JOIN "Team" TM3 ON RS.id_rank3 = TM3.id LEFT JOIN "Team" TM4 ON RS.id_rank4 = TM4.id LEFT JOIN "Team" TM5 ON RS.id_rank5 = TM5.id LEFT JOIN "Team" TM6 ON RS.id_rank6 = TM6.id
			WHERE RS.id = _item.id_item;
			_item.comment = 'TM';
		ELSIF _type1 = 99 THEN
			_query = 'SELECT id_rank1, id_rank2, id_rank3, id_rank4, id_rank5, id_rank6, CN1.label' || _lang || ', CN2.label' || _lang || ', CN3.label' || _lang || ', CN4.label' || _lang || ', CN5.label' || _lang || ', CN6.label' || _lang || ', CN1.label, CN2.label, CN3.label, CN4.label, CN5.label, CN6.label, RS.result1, RS.result2, RS.comment, RS.exa';
			_query = _query || ' FROM "Result" RS LEFT JOIN "Country" CN1 ON RS.id_rank1 = CN1.id LEFT JOIN "Country" CN2 ON RS.id_rank2 = CN2.id LEFT JOIN "Country" CN3 ON RS.id_rank3 = CN3.id LEFT JOIN "Country" CN4 ON RS.id_rank4 = CN4.id LEFT JOIN "Country" CN5 ON RS.id_rank5 = CN5.id LEFT JOIN "Country" CN6 ON RS.id_rank6 = CN6.id';
			_query = _query || ' WHERE RS.id = ' || _item.id_item;
			OPEN __c FOR EXECUTE _query;
			FETCH __c INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.id_rel9, _item.id_rel10, _item.id_rel11, _item.label_rel6, _item.label_rel7, _item.label_rel8, _item.label_rel9, _item.label_rel10, _item.label_rel11, _item.label_rel20, _item.label_rel21, _item.label_rel22, _item.label_rel23, _item.label_rel24, _item.label_rel25, _item.txt1, _item.txt2, _item.txt3, _item.txt4;
			CLOSE __c;
			_item.comment = 'CN';
		END IF;
		IF _date1 IS NOT NULL AND _date1 <> '' THEN
			_item.date1 := to_date(_date1, 'DD/MM/YYYY');
		END IF;
		IF _date2 IS NOT NULL AND _date2 <> '' THEN
			_item.date2 := to_date(_date2, 'DD/MM/YYYY');
		END IF;
		_item.id := _index;
		_item.entity := 'RS';
		RETURN NEXT _item;
		_index = _index + 1;
	END LOOP;
	CLOSE _c;

	-- Future events
	_query := 'SELECT CL.id, NULL, NULL, SP.id, SP.label' || _lang || ', CP.id, CP.label' || _lang || ', EV.id, EV.label' || _lang || ', SE.id, SE.label' || _lang || ', SE2.id, SE2.label' || _lang || ', SP.label, CP.label, EV.label, SE.label, SE2.label, CX.id, CX.label' || _lang || ', CX.label, CT1.id, CT1.label' || _lang || ' || '', '' || CN1.code, CT1.label, CT2.id, CT2.label' || _lang || ' || '', '' || CN2.code, CT2.label, CN3.label' || _lang || ', CN3.label, CL.date1, CL.date2';
	_query := _query || ' FROM "Calendar" CL';
	_query := _query || ' LEFT JOIN "Sport" SP ON CL.id_sport = SP.id';
	_query := _query || ' LEFT JOIN "Championship" CP ON CL.id_championship = CP.id';
	_query := _query || ' LEFT JOIN "Event" EV ON CL.id_event = EV.id';
	_query := _query || ' LEFT JOIN "Event" SE ON CL.id_subevent = SE.id';
	_query := _query || ' LEFT JOIN "Event" SE2 ON CL.id_subevent2 = SE2.id';
	_query := _query || ' LEFT JOIN "Complex" CX ON CL.id_complex = CX.id';
	_query := _query || ' LEFT JOIN "City" CT1 ON CX.id_city = CT1.id';
	_query := _query || ' LEFT JOIN "State" ST1 ON CT1.id_state = ST1.id';
	_query := _query || ' LEFT JOIN "Country" CN1 ON CT1.id_country = CN1.id';
	_query := _query || ' LEFT JOIN "City" CT2 ON CL.id_city = CT2.id';
	_query := _query || ' LEFT JOIN "State" ST2 ON CT2.id_state = ST2.id';
	_query := _query || ' LEFT JOIN "Country" CN2 ON CT2.id_country = CN2.id';
	_query := _query || ' LEFT JOIN "Country" CN3 ON CL.id_country = CN3.id' || _where;
	OPEN _c FOR EXECUTE _query;
	LOOP
		FETCH _c INTO _item.id_item, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.id_rel3, _item.label_rel3, _item.id_rel4, _item.label_rel4, _item.id_rel5, _item.label_rel5, _item.id_rel18, _item.label_rel18, _item.label_rel12, _item.label_rel13, _item.label_rel14, _item.label_rel15, _item.label_rel16, _item.id_rel6, _item.label_rel6, _item.label_rel9, _item.id_rel7, _item.label_rel7, _item.label_rel10, _item.id_rel8, _item.label_rel8, _item.label_rel11, _item.label_rel19, _item.label_rel20, _date1, _date2;
		EXIT WHEN NOT FOUND;
		IF _date1 IS NOT NULL AND _date1 <> '' THEN
			_item.date1 := to_date(_date1, 'DD/MM/YYYY');
		END IF;
		IF _date2 IS NOT NULL AND _date2 <> '' THEN
			_item.date2 := to_date(_date2, 'DD/MM/YYYY');
		END IF;
		_item.id := _index;
		_item.entity := 'CL';
		RETURN NEXT _item;
		_index = _index + 1;
	END LOOP;
	CLOSE _c;

	RETURN;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
  
  
  
  
  
  
  
  
  CREATE OR REPLACE FUNCTION "~LastUpdates"(
    _count integer,
    _offset integer,
    _lang character varying)
  RETURNS refcursor AS
$BODY$
declare
	_c refcursor;
begin
	OPEN _c FOR EXECUTE
	'SELECT RS.id AS rs_id, YR.id AS yr_id, YR.label AS yr_label, SP.id AS sp_id, CP.id AS cp_id, EV.id AS ev_id, SE.id AS se_id, SE2.id AS se2_id, SP.label' || _lang || ' AS sp_label, CP.label' || _lang || ' AS cp_label, EV.label' || _lang || ' AS ev_label, SE.label' || _lang || ' AS se_label, SE2.label' || _lang || ' AS se2_label, SP.label AS sp_label_en, CP.label AS cp_label_en, EV.label AS ev_label_en, SE.label AS se_label_en, SE2.label AS se2_label_en, TP1.number as tp1_number, TP2.number AS tp2_number, TP3.number AS tp3_number,
	  PR1.id AS pr1_id, PR1.first_name AS pr1_first_name, PR1.last_name AS pr1_last_name, PR1.id_team AS pr1_team, PR1.id_country AS pr1_country, PRCN1.code AS pr1_country_code, TM1.id AS tm1_id, TM1.label AS tm1_label, CN1.id AS cn1_id, CN1.code AS cn1_code, CN1.label' || _lang || ' AS cn1_label, CN1.label AS cn1_label_en, 
	  PR2.id AS pr2_id, PR2.first_name AS pr2_first_name, PR2.last_name AS pr2_last_name, PR2.id_team AS pr2_team, PR2.id_country AS pr2_country, PRCN2.code AS pr2_country_code, TM2.id AS tm2_id, TM2.label AS tm2_label, CN2.id AS cn2_id, CN2.code AS cn2_code, CN2.label' || _lang || ' AS cn2_label, CN2.label AS cn2_label_en,
	  PR3.id AS pr3_id, PR3.first_name AS pr3_first_name, PR3.last_name AS pr3_last_name, PR3.id_team AS pr3_team, PR3.id_country AS pr3_country, PRCN3.code AS pr3_country_code, TM3.id AS tm3_id, TM3.label AS tm3_label, CN3.id AS cn3_id, CN3.code AS cn3_code, CN3.label' || _lang || ' AS cn3_label, CN3.label AS cn3_label_en,
	  PR4.id AS pr4_id, PR4.first_name AS pr4_first_name, PR4.last_name AS pr4_last_name, PR4.id_team AS pr4_team, PR4.id_country AS pr4_country, PRCN4.code AS pr4_country_code, TM4.id AS tm4_id, TM4.label AS tm4_label, CN4.id AS cn4_id, CN4.code AS cn4_code, CN4.label' || _lang || ' AS cn4_label, CN4.label AS cn4_label_en,
	  RS.result1 AS rs_text1, RS.result2 AS rs_text2, RS.exa AS rs_text3, RS.comment AS rs_text4, (CASE WHEN RS.date2 IS NOT NULL AND RS.date2<>'''' THEN to_date(RS.date2, ''dd/MM/yyyy'') ELSE RS.first_update END) AS rs_date FROM "Result" RS
		LEFT JOIN "Year" YR ON RS.id_year=YR.id
		LEFT JOIN "Sport" SP ON RS.id_sport=SP.id
		LEFT JOIN "Championship" CP ON RS.id_championship=CP.id
		LEFT JOIN "Event" EV ON RS.id_event=EV.id
		LEFT JOIN "Event" SE ON RS.id_subevent=SE.id
		LEFT JOIN "Event" SE2 ON RS.id_subevent2=SE2.id
		LEFT JOIN "Type" TP1 ON EV.id_type=TP1.id
		LEFT JOIN "Type" TP2 ON SE.id_type=TP2.id
		LEFT JOIN "Type" TP3 ON SE2.id_type=TP3.id
		LEFT JOIN "Athlete" PR1 ON RS.id_rank1=PR1.id
		LEFT JOIN "Athlete" PR2 ON RS.id_rank2=PR2.id
		LEFT JOIN "Athlete" PR3 ON RS.id_rank3=PR3.id
		LEFT JOIN "Athlete" PR4 ON RS.id_rank4=PR4.id
		LEFT JOIN "Country" PRCN1 ON PR1.id_country=PRCN1.id
		LEFT JOIN "Country" PRCN2 ON PR2.id_country=PRCN2.id
		LEFT JOIN "Country" PRCN3 ON PR3.id_country=PRCN3.id
		LEFT JOIN "Country" PRCN4 ON PR4.id_country=PRCN4.id
		LEFT JOIN "Team" TM1 ON RS.id_rank1=TM1.id
		LEFT JOIN "Team" TM2 ON RS.id_rank2=TM2.id
		LEFT JOIN "Team" TM3 ON RS.id_rank3=TM3.id
		LEFT JOIN "Team" TM4 ON RS.id_rank4=TM4.id
		LEFT JOIN "Country" CN1 ON RS.id_rank1=CN1.id
		LEFT JOIN "Country" CN2 ON RS.id_rank2=CN2.id
		LEFT JOIN "Country" CN3 ON RS.id_rank3=CN3.id
		LEFT JOIN "Country" CN4 ON RS.id_rank4=CN4.id
	ORDER BY YR.id DESC, rs_date DESC LIMIT ' || _count || ' OFFSET ' || _offset;
	RETURN  _c;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  
  
  
  
  
  CREATE OR REPLACE FUNCTION "GetCalendarResults"(
    _date1 character varying,
    _date2 character varying,
    _sp integer,
    _lang character varying)
  RETURNS SETOF "~RefItem" AS
$BODY$
declare
	_item "~RefItem"%rowtype;
	_c refcursor;
	__c refcursor;
	_query text;
	_where text;
	_index integer;
	_type1 smallint;
	_type2 smallint;
	_type3 smallint;
	_date1 varchar(10) := _date1;
	_date2 varchar(10) := _date2;
	_id1 integer;_id2 integer;_id3 integer;_id4 integer;_id5 integer;
	_id6 integer;_id7 integer;_id8 integer;_id9 integer;_id10 integer;
	_cn1 varchar(5);_cn2 varchar(5);_cn3 varchar(5);_cn4 varchar(5);_cn5 varchar(5);_cn6 varchar(5);
	_tm1 varchar(60);_tm2 varchar(60);_tm3 varchar(60);_tm4 varchar(60);_tm5 varchar(60);_tm6 varchar(60);
begin
	_where := ' WHERE to_date(date2, ''DD/MM/YYYY'') >= to_date(''' || _date1 || ''', ''YYYYMMDD'') AND to_date(date2, ''DD/MM/YYYY'') <= to_date(''' || _date2 || ''', ''YYYYMMDD'')';
	IF (_sp > 0) THEN
		_where := _where || ' AND SP.id = ' || _sp;
	END IF;

	-- Past events
	_query := 'SELECT RS.id, YR.id, YR.label, SP.id, SP.label' || _lang || ', CP.id, CP.label' || _lang || ', EV.id, EV.label' || _lang || ', SE.id, SE.label' || _lang || ', SE2.id, SE2.label' || _lang || ', SP.label, CP.label, EV.label, SE.label, SE2.label, RS.id_rank1, RS.id_rank2, RS.id_rank3, RS.id_rank4, RS.id_rank5, RS.id_rank6, RS.id_rank7, RS.id_rank8, RS.id_rank9, RS.id_rank10, TP1.number, TP2.number, TP3.number, RS.date1, RS.date2';
	_query := _query || ' FROM "Result" RS';
	_query := _query || ' LEFT JOIN "Year" YR ON RS.id_year = YR.id';
	_query := _query || ' LEFT JOIN "Sport" SP ON RS.id_sport = SP.id';
	_query := _query || ' LEFT JOIN "Championship" CP ON RS.id_championship = CP.id';
	_query := _query || ' LEFT JOIN "Event" EV ON RS.id_event = EV.id';
	_query := _query || ' LEFT JOIN "Event" SE ON RS.id_subevent = SE.id';
	_query := _query || ' LEFT JOIN "Event" SE2 ON RS.id_subevent2 = SE2.id';
	_query := _query || ' LEFT JOIN "Type" TP1 ON EV.id_type = TP1.id';
	_query := _query || ' LEFT JOIN "Type" TP2 ON SE.id_type = TP2.id';
	_query := _query || ' LEFT JOIN "Type" TP3 ON SE2.id_type = TP3.id' || _where;
	_index := 1;
	OPEN _c FOR EXECUTE _query;
	LOOP
		FETCH _c INTO _item.id_item, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.id_rel3, _item.label_rel3, _item.id_rel4, _item.label_rel4, _item.id_rel5, _item.label_rel5, _item.id_rel18, _item.label_rel18, _item.label_rel12, _item.label_rel13, _item.label_rel14, _item.label_rel15, _item.label_rel16, _id1, _id2, _id3, _id4, _id5, _id6, _id7, _id8, _id9, _id10, _type1, _type2, _type3, _date1, _date2, _item.count1;
		EXIT WHEN NOT FOUND;
		IF _type3 IS NOT NULL THEN
			_type1 = _type3;
		ELSIF _type2 IS NOT NULL THEN
			_type1 = _type2;
		END IF;
		IF _type1 <= 10 THEN
			SELECT id_rank1, id_rank2, id_rank3, id_rank4, id_rank5, id_rank6, PR1.last_name || (CASE WHEN length(PR1.first_name) > 0 THEN ', ' || PR1.first_name ELSE '' END), (CASE WHEN length(PR1.first_name) > 0 THEN PR1.first_name || ' ' ELSE '' END) || PR1.last_name, CN1.id, CN1.code, TM1.label, PR2.last_name || (CASE WHEN length(PR2.first_name) > 0 THEN ', ' || PR2.first_name ELSE '' END), (CASE WHEN length(PR2.first_name) > 0 THEN PR2.first_name || ' ' ELSE '' END) || PR2.last_name, CN2.id, CN2.code, TM2.label, PR3.last_name || (CASE WHEN length(PR3.first_name) > 0 THEN ', ' || PR3.first_name ELSE '' END), (CASE WHEN length(PR3.first_name) > 0 THEN PR3.first_name || ' ' ELSE '' END) || PR3.last_name, CN3.id, CN3.code, TM3.label, PR4.last_name || (CASE WHEN length(PR4.first_name) > 0 THEN ', ' || PR4.first_name ELSE '' END), (CASE WHEN length(PR4.first_name) > 0 THEN PR4.first_name || ' ' ELSE '' END) || PR4.last_name, CN4.id, CN4.code, TM4.label, PR5.last_name || (CASE WHEN length(PR5.first_name) > 0 THEN ', ' || PR5.first_name ELSE '' END), (CASE WHEN length(PR5.first_name) > 0 THEN PR5.first_name || ' ' ELSE '' END) || PR5.last_name, CN5.id, CN5.code, TM5.label, PR6.last_name || (CASE WHEN length(PR6.first_name) > 0 THEN ', ' || PR6.first_name ELSE '' END), (CASE WHEN length(PR6.first_name) > 0 THEN PR6.first_name || ' ' ELSE '' END) || PR6.last_name, CN6.id, CN6.code, TM6.label, RS.result1, RS.result2, RS.comment, RS.exa
			INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.id_rel9, _item.id_rel10, _item.id_rel11, _item.label_rel6, _item.label_rel20, _item.id_rel12, _cn1, _tm1, _item.label_rel7, _item.label_rel21, _item.id_rel13, _cn2, _tm2, _item.label_rel8, _item.label_rel22, _item.id_rel14, _cn3, _tm3, _item.label_rel9, _item.label_rel23, _item.id_rel15, _cn4, _tm4, _item.label_rel10, _item.label_rel24, _item.id_rel16, _cn5, _tm5, _item.label_rel11, _item.label_rel25, _item.id_rel17, _cn6, _tm6, _item.txt1, _item.txt2, _item.txt3, _item.txt4
			FROM "Result" RS LEFT JOIN "Athlete" PR1 ON RS.id_rank1 = PR1.id LEFT JOIN "Athlete" PR2 ON RS.id_rank2 = PR2.id LEFT JOIN "Athlete" PR3 ON RS.id_rank3 = PR3.id LEFT JOIN "Athlete" PR4 ON RS.id_rank4 = PR4.id LEFT JOIN "Athlete" PR5 ON RS.id_rank5 = PR5.id LEFT JOIN "Athlete" PR6 ON RS.id_rank6 = PR6.id LEFT JOIN "Country" CN1 ON PR1.id_country = CN1.id LEFT JOIN "Country" CN2 ON PR2.id_country = CN2.id LEFT JOIN "Country" CN3 ON PR3.id_country = CN3.id LEFT JOIN "Country" CN4 ON PR4.id_country = CN4.id LEFT JOIN "Country" CN5 ON PR5.id_country = CN5.id LEFT JOIN "Country" CN6 ON PR6.id_country = CN6.id LEFT JOIN "Team" TM1 ON PR1.id_team = TM1.id LEFT JOIN "Team" TM2 ON PR2.id_team = TM2.id LEFT JOIN "Team" TM3 ON PR3.id_team = TM3.id LEFT JOIN "Team" TM4 ON PR4.id_team = TM4.id LEFT JOIN "Team" TM5 ON PR5.id_team = TM5.id LEFT JOIN "Team" TM6 ON PR6.id_team = TM6.id
			WHERE RS.id = _item.id_item;
			IF _cn1 IS NOT NULL THEN _item.label_rel6 = _item.label_rel6 || ' (' || _cn1 || ')';
			ELSIF _tm1 IS NOT NULL THEN _item.label_rel6 = _item.label_rel6 || ' (' || _tm1 || ')'; END IF;
			IF _cn2 IS NOT NULL THEN _item.label_rel7 = _item.label_rel7 || ' (' || _cn2 || ')';
			ELSIF _tm2 IS NOT NULL THEN _item.label_rel7 = _item.label_rel7 || ' (' || _tm2 || ')'; END IF;
			IF _cn3 IS NOT NULL THEN _item.label_rel8 = _item.label_rel8 || ' (' || _cn3 || ')';
			ELSIF _tm3 IS NOT NULL THEN _item.label_rel8 = _item.label_rel8 || ' (' || _tm3 || ')'; END IF;
			IF _cn4 IS NOT NULL THEN _item.label_rel9 = _item.label_rel9 || ' (' || _cn4 || ')';
			ELSIF _tm4 IS NOT NULL THEN _item.label_rel9 = _item.label_rel9 || ' (' || _tm4 || ')'; END IF;
			IF _cn5 IS NOT NULL THEN _item.label_rel10 = _item.label_rel10 || ' (' || _cn5 || ')';
			ELSIF _tm5 IS NOT NULL THEN _item.label_rel10 = _item.label_rel10 || ' (' || _tm5 || ')'; END IF;
			IF _cn6 IS NOT NULL THEN _item.label_rel11 = _item.label_rel11 || ' (' || _cn6 || ')';
			ELSIF _tm6 IS NOT NULL THEN _item.label_rel11 = _item.label_rel11 || ' (' || _tm6 || ')'; END IF;
			IF _type1 = 4 OR _item.txt3 = '#DOUBLE#' THEN
				_item.txt4 = '1-2/3-4/5-6';
			ELSIF _type1 = 5 OR _item.txt3 = '#TRIPLE#' THEN
				_item.txt4 = '1-3/4-6/7-9';
			END IF;
			_item.comment = 'PR';
		ELSIF _type1 = 50 THEN
			SELECT id_rank1, id_rank2, id_rank3, id_rank4, id_rank5, id_rank6, TM1.label, TM2.label, TM3.label, TM4.label, TM5.label, TM6.label, NULL, NULL, NULL, NULL, NULL, NULL, RS.result1, RS.result2, RS.comment, RS.exa
			INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.id_rel9, _item.id_rel10, _item.id_rel11, _item.label_rel6, _item.label_rel7, _item.label_rel8, _item.label_rel9, _item.label_rel10, _item.label_rel11, _item.label_rel20, _item.label_rel21, _item.label_rel22, _item.label_rel23, _item.label_rel24, _item.label_rel25, _item.txt1, _item.txt2, _item.txt3, _item.txt4
			FROM "Result" RS LEFT JOIN "Team" TM1 ON RS.id_rank1 = TM1.id LEFT JOIN "Team" TM2 ON RS.id_rank2 = TM2.id LEFT JOIN "Team" TM3 ON RS.id_rank3 = TM3.id LEFT JOIN "Team" TM4 ON RS.id_rank4 = TM4.id LEFT JOIN "Team" TM5 ON RS.id_rank5 = TM5.id LEFT JOIN "Team" TM6 ON RS.id_rank6 = TM6.id
			WHERE RS.id = _item.id_item;
			_item.comment = 'TM';
		ELSIF _type1 = 99 THEN
			_query = 'SELECT id_rank1, id_rank2, id_rank3, id_rank4, id_rank5, id_rank6, CN1.label' || _lang || ', CN2.label' || _lang || ', CN3.label' || _lang || ', CN4.label' || _lang || ', CN5.label' || _lang || ', CN6.label' || _lang || ', CN1.label, CN2.label, CN3.label, CN4.label, CN5.label, CN6.label, RS.result1, RS.result2, RS.comment, RS.exa';
			_query = _query || ' FROM "Result" RS LEFT JOIN "Country" CN1 ON RS.id_rank1 = CN1.id LEFT JOIN "Country" CN2 ON RS.id_rank2 = CN2.id LEFT JOIN "Country" CN3 ON RS.id_rank3 = CN3.id LEFT JOIN "Country" CN4 ON RS.id_rank4 = CN4.id LEFT JOIN "Country" CN5 ON RS.id_rank5 = CN5.id LEFT JOIN "Country" CN6 ON RS.id_rank6 = CN6.id';
			_query = _query || ' WHERE RS.id = ' || _item.id_item;
			OPEN __c FOR EXECUTE _query;
			FETCH __c INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.id_rel9, _item.id_rel10, _item.id_rel11, _item.label_rel6, _item.label_rel7, _item.label_rel8, _item.label_rel9, _item.label_rel10, _item.label_rel11, _item.label_rel20, _item.label_rel21, _item.label_rel22, _item.label_rel23, _item.label_rel24, _item.label_rel25, _item.txt1, _item.txt2, _item.txt3, _item.txt4;
			CLOSE __c;
			_item.comment = 'CN';
		END IF;
		IF _date1 IS NOT NULL AND _date1 <> '' THEN
			_item.date1 := to_date(_date1, 'DD/MM/YYYY');
		END IF;
		IF _date2 IS NOT NULL AND _date2 <> '' THEN
			_item.date2 := to_date(_date2, 'DD/MM/YYYY');
		END IF;
		_item.id := _index;
		_item.entity := 'RS';
		RETURN NEXT _item;
		_index = _index + 1;
	END LOOP;
	CLOSE _c;

	-- Future events
	_query := 'SELECT CL.id, NULL, NULL, SP.id, SP.label' || _lang || ', CP.id, CP.label' || _lang || ', EV.id, EV.label' || _lang || ', SE.id, SE.label' || _lang || ', SE2.id, SE2.label' || _lang || ', SP.label, CP.label, EV.label, SE.label, SE2.label, CX.id, CX.label' || _lang || ', CX.label, CT1.id, CT1.label' || _lang || ' || '', '' || CN1.code, CT1.label, CT2.id, CT2.label' || _lang || ' || '', '' || CN2.code, CT2.label, CN1.id, CN2.id, CN3.id, CN3.label' || _lang || ', CN3.label, CL.date1, CL.date2';
	_query := _query || ' FROM "Calendar" CL';
	_query := _query || ' LEFT JOIN "Sport" SP ON CL.id_sport = SP.id';
	_query := _query || ' LEFT JOIN "Championship" CP ON CL.id_championship = CP.id';
	_query := _query || ' LEFT JOIN "Event" EV ON CL.id_event = EV.id';
	_query := _query || ' LEFT JOIN "Event" SE ON CL.id_subevent = SE.id';
	_query := _query || ' LEFT JOIN "Event" SE2 ON CL.id_subevent2 = SE2.id';
	_query := _query || ' LEFT JOIN "Complex" CX ON CL.id_complex = CX.id';
	_query := _query || ' LEFT JOIN "City" CT1 ON CX.id_city = CT1.id';
	_query := _query || ' LEFT JOIN "State" ST1 ON CT1.id_state = ST1.id';
	_query := _query || ' LEFT JOIN "Country" CN1 ON CT1.id_country = CN1.id';
	_query := _query || ' LEFT JOIN "City" CT2 ON CL.id_city = CT2.id';
	_query := _query || ' LEFT JOIN "State" ST2 ON CT2.id_state = ST2.id';
	_query := _query || ' LEFT JOIN "Country" CN2 ON CT2.id_country = CN2.id';
	_query := _query || ' LEFT JOIN "Country" CN3 ON CL.id_country = CN3.id' || _where;
	OPEN _c FOR EXECUTE _query;
	LOOP
		FETCH _c INTO _item.id_item, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.id_rel3, _item.label_rel3, _item.id_rel4, _item.label_rel4, _item.id_rel5, _item.label_rel5, _item.id_rel18, _item.label_rel18, _item.label_rel12, _item.label_rel13, _item.label_rel14, _item.label_rel15, _item.label_rel16, _item.id_rel6, _item.label_rel6, _item.label_rel9, _item.id_rel7, _item.label_rel7, _item.label_rel10, _item.id_rel8, _item.label_rel8, _item.label_rel11, _item.id_rel10, _item.id_rel11, _item.id_rel9, _item.label_rel19, _item.label_rel20, _date1, _date2;
		EXIT WHEN NOT FOUND;
		IF _date1 IS NOT NULL AND _date1 <> '' THEN
			_item.date1 := to_date(_date1, 'DD/MM/YYYY');
		END IF;
		IF _date2 IS NOT NULL AND _date2 <> '' THEN
			_item.date2 := to_date(_date2, 'DD/MM/YYYY');
		END IF;
		_item.id := _index;
		_item.entity := 'CL';
		RETURN NEXT _item;
		_index = _index + 1;
	END LOOP;
	CLOSE _c;

	RETURN;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
  
  
  
  CREATE SEQUENCE "~SeqRedirection";
  
  
  CREATE TABLE "~Redirection"
(
  id integer NOT NULL,
  previous_path character varying(255),
  current_path character varying(255)
);


insert into "~Redirection" values (nextval('"~SeqRedirection"'), '/1/2/3', '/4/5/6');



insert into "~Config" values ('max_photo_height', '150');



CREATE OR REPLACE FUNCTION "GetOlympicRankings"(
    _olympics text,
    _countries text,
    _lang character varying)
  RETURNS refcursor AS
$BODY$
declare
	_c refcursor;
	_olympics_condition text;
	_country_condition text;
begin
	INSERT INTO "~Request" VALUES (NEXTVAL('"~SeqRequest"'), 'OL', 'CN-' || _olympics, current_date);

	-- Set olympics condition
	_olympics_condition := '';
	IF _olympics <> '0' THEN
		_olympics_condition := ' AND OL.id IN (' || _olympics || ')';
	END IF;
	
	-- Set country condition
	_country_condition := '';
	IF _countries <> '0' THEN
		_country_condition := ' AND CN1.id IN (' || _countries || ')';
	END IF;
	
	-- Open cursor
	OPEN _c FOR EXECUTE
	'SELECT
		CN1.id AS cn1_id, CN1.code AS cn1_code, CN1.label' || _lang || ' AS cn1_label, CN1.label AS cn1_label_en,
		SUM(OR_.count_gold) AS or_count_gold, SUM(OR_.count_silver) AS or_count_silver, SUM(OR_.count_bronze) AS or_count_bronze
	FROM "OlympicRanking" OR_
		LEFT JOIN "Olympics" OL ON OR_.id_olympics = OL.id
		LEFT JOIN "Country" CN1 ON OR_.id_country = CN1.id
		LEFT JOIN "Year" YR ON OL.id_year = YR.id
		LEFT JOIN "City" CT ON OL.id_city = CT.id
		LEFT JOIN "State" ST ON CT.id_state = ST.id
		LEFT JOIN "Country" CN2 ON CT.id_country = CN2.id
	WHERE
		TRUE' || _olympics_condition || _country_condition || '
	GROUP BY
		CN1.id
	ORDER BY
		or_count_gold DESC, or_count_silver DESC, or_count_bronze DESC';
	
	RETURN  _c;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  
  
  
  
  CREATE OR REPLACE FUNCTION "EntityRef"(
    _entity character varying,
    _id integer,
    _entity_ref character varying,
    _limit character varying,
    _offset integer,
    _lang character varying)
  RETURNS SETOF "~RefItem" AS
$BODY$
declare
	_item "~RefItem"%rowtype;
	_entity varchar := _entity;
	_c refcursor;
	__c refcursor;
	_query text;
	_link integer;
	_rs "Result"%rowtype;
	_ct_list varchar(200);
	_cx_list varchar(200);
	_pr_list varchar(200);
	_tm_list varchar(200);
	_index integer;
	_type1 smallint;
	_type2 smallint;
	_type3 smallint;
	_date varchar(8);
	_date1 varchar(10);
	_date2 varchar(10);
	_array_id integer[];
	_id1 integer;_id2 integer;_id3 integer;_id4 integer;_id5 integer;
	_id6 integer;_id7 integer;_id8 integer;_id9 integer;_id10 integer;
	_id11 integer;_id12 integer;_id13 integer;_id14 integer;
	_cn1 varchar(5);_cn2 varchar(5);_cn3 varchar(5);_cn4 varchar(5);_cn5 varchar(5);_cn6 varchar(5);
	_tm1 varchar(60);_tm2 varchar(60);_tm3 varchar(60);_tm4 varchar(60);_tm5 varchar(60);_tm6 varchar(60);
begin
	IF _entity ~ E'^\\d{8}' THEN
		_date := _entity;
		_entity := 'DT';
	END IF;

	INSERT INTO "~Request" VALUES (NEXTVAL('"~SeqRequest"'), 'IF', _entity || '-' || _id, current_date);
	
	_index := 1;

	IF _entity ~ 'CT' THEN
		SELECT LINK INTO _link FROM "City" WHERE ID = _id;
		IF _link IS NOT NULL THEN
			_query = 'SELECT ID FROM "City" WHERE ';
			IF _link = 0 THEN
				_query = _query || 'ID = ' || _id || ' OR LINK = ' || _id;
			ELSE
				_query = _query || 'ID = ' || _link || ' OR LINK = ' || _link;
			END IF;
			_ct_list = '-1';
			OPEN _c FOR EXECUTE _query;
			LOOP
				FETCH _c INTO _link;
				EXIT WHEN NOT FOUND;
				_ct_list = _ct_list || ',' || _link;
			END LOOP;
			CLOSE _c;
		ELSE
			_ct_list = cast(_id AS varchar);
		END IF;
	ELSIF _entity ~ 'CX' THEN
		SELECT LINK INTO _link FROM "Complex" WHERE ID = _id;
		IF _link IS NOT NULL THEN
			_query = 'SELECT ID FROM "Complex" WHERE ';
			IF _link = 0 THEN
				_query = _query || 'ID = ' || _id || ' OR LINK = ' || _id;
			ELSE
				_query = _query || 'ID = ' || _link || ' OR LINK = ' || _link;
			END IF;
			_cx_list = '-1';
			OPEN _c FOR EXECUTE _query;
			LOOP
				FETCH _c INTO _link;
				EXIT WHEN NOT FOUND;
				_cx_list = _cx_list || ',' || _link;
			END LOOP;
			CLOSE _c;
		ELSE
			_cx_list = cast(_id AS varchar);
		END IF;
	ELSIF _entity ~ 'PR' THEN
		SELECT LINK INTO _link FROM "Athlete" WHERE ID = _id;
		IF _link IS NOT NULL THEN
			_query = 'SELECT ID FROM "Athlete" WHERE ';
			IF _link = 0 THEN
				_query = _query || 'ID = ' || _id || ' OR LINK = ' || _id;
			ELSE
				_query = _query || 'ID = ' || _link || ' OR LINK = ' || _link;
			END IF;
			_pr_list = '-1';
			OPEN _c FOR EXECUTE _query;
			LOOP
				FETCH _c INTO _link;
				EXIT WHEN NOT FOUND;
				_pr_list = _pr_list || ',' || _link;
			END LOOP;
			CLOSE _c;
		ELSE
			_pr_list = cast(_id AS varchar);
		END IF;
	ELSIF _entity ~ 'TM' THEN
		SELECT LINK INTO _link FROM "Team" WHERE ID = _id AND (YEAR1 IS NULL OR YEAR1 = '');
		IF _link IS NOT NULL THEN
			_query = 'SELECT ID FROM "Team" WHERE ';
			IF _link = 0 THEN
				_query = _query || 'ID = ' || _id || ' OR LINK = ' || _id;
			ELSE
				_query = _query || 'ID = ' || _link || ' OR LINK = ' || _link;
			END IF;
			_tm_list = '-1';
			OPEN _c FOR EXECUTE _query;
			LOOP
				FETCH _c INTO _link;
				EXIT WHEN NOT FOUND;
				_tm_list = _tm_list || ',' || _link;
			END LOOP;
			CLOSE _c;
		ELSE
			_tm_list = cast(_id AS varchar);
		END IF;
	END IF;

	-- References in: [Events]
	IF (_entity ~ 'CP|EV|SP' AND (_entity_ref = 'EV' OR _entity_ref = '')) THEN
		_query = 'SELECT DISTINCT SP.id, SP.label' || _lang || ', SP.label, CP.id, CP.label' || _lang || ', CP.label, EV.id, EV.label' || _lang || ', EV.label, SE.id, SE.label' || _lang || ', SE.label, SE2.id, SE2.label' || _lang || ', SE2.label, II.id_championship, II.id_event, II.id_subevent, II.id_subevent2, CP.index, EV.index, SE.index, SE2.index, (CASE WHEN II.id_event IS NOT NULL AND II.id_subevent IS NULL AND II.id_subevent2 IS NULL THEN 1 ELSE 0 END) AS o_ii_ev, (CASE WHEN II.id_subevent IS NOT NULL AND II.id_subevent2 IS NULL THEN 1 ELSE 0 END) AS o_ii_se, (CASE WHEN II.id_subevent2 IS NOT NULL THEN 1 ELSE 0 END) AS o_ii_se2';
		_query = _query || ' FROM "Result" RS LEFT JOIN "Sport" SP ON RS.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "Championship" CP ON RS.id_championship = CP.id';
		_query = _query || ' LEFT JOIN "Event" EV ON RS.id_event = EV.id';
		_query = _query || ' LEFT JOIN "Event" SE ON RS.id_subevent = SE.id';
		_query = _query || ' LEFT JOIN "Event" SE2 ON RS.id_subevent2 = SE2.id';
		_query = _query || ' LEFT JOIN "~InactiveItem" II ON (RS.id_sport = II.id_sport AND RS.id_championship = II.id_championship AND RS.id_event = II.id_event AND (RS.id_subevent = II.id_subevent OR RS.id_subevent IS NULL) AND (RS.id_subevent2 = II.id_subevent2 OR RS.id_subevent2 IS NULL))';
		IF _entity = 'SP' THEN
			_query = _query || ' WHERE RS.id_sport = ' || _id;
		ELSIF _entity = 'CP' THEN
			_query = _query || ' WHERE RS.id_championship = ' || _id;
		ELSIF _entity = 'EV' THEN
			_query = _query || ' WHERE RS.id_event = ' || _id || ' OR RS.id_subevent = ' || _id || ' OR RS.id_subevent2 = ' || _id;
		END IF;
		_query = _query || ' ORDER BY SP.label' || _lang || ', CP.index, o_ii_ev, EV.index, o_ii_se, SE.index, o_ii_se2, SE2.index, CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ', SE2.label' || _lang || ' LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_rel1, _item.label_rel1, _item.label_rel2, _item.id_rel2, _item.label_rel3, _item.label_rel4, _item.id_rel3, _item.label_rel5, _item.label_rel6, _item.id_rel4, _item.label_rel7, _item.label_rel8, _item.id_rel5, _item.label_rel9, _item.label_rel10;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'EV';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Results]
	IF (_entity ~ 'CN|DT|PR|TM|CP|EV|CT|SP|CX|OL|YR' AND (_entity_ref = 'RS' OR _entity_ref = '')) THEN
		_type1 = 1;
		_type2 = 99;
		IF _entity = 'CN' THEN _type1 = 99;_type2 = 99;
		ELSIF _entity = 'PR' THEN _type1 = 1;_type2 = 10;
		ELSIF _entity = 'TM' THEN _type1 = 50;_type2 = 50; END IF;
		_query = 'SELECT RS.id, YR.id, YR.label, SP.id, SP.label' || _lang || ', CP.id, CP.label' || _lang || ', EV.id, EV.label' || _lang || ', SE.id, SE.label' || _lang || ', SE2.id, SE2.label' || _lang || ', SP.label, CP.label, EV.label, SE.label, SE2.label, RS.id_rank1, RS.id_rank2, RS.id_rank3, RS.id_rank4, RS.id_rank5, RS.id_rank6, RS.id_rank7, RS.id_rank8, RS.id_rank9, RS.id_rank10, TP1.number, TP2.number, TP3.number, RS.date1, RS.date2';
		IF (_entity = 'PR') THEN
			_query = _query || ', PL.rank';
		ELSE
			_query = _query || ', 0';
		END IF;
		_query = _query || ' FROM "Result" RS';
		_query = _query || ' LEFT JOIN "Year" YR ON RS.id_year = YR.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON RS.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "Championship" CP ON RS.id_championship = CP.id';
		_query = _query || ' LEFT JOIN "Event" EV ON RS.id_event = EV.id';
		_query = _query || ' LEFT JOIN "Event" SE ON RS.id_subevent = SE.id';
		_query = _query || ' LEFT JOIN "Event" SE2 ON RS.id_subevent2 = SE2.id';
		_query = _query || ' LEFT JOIN "Type" TP1 ON EV.id_type = TP1.id';
		_query = _query || ' LEFT JOIN "Type" TP2 ON SE.id_type = TP2.id';
		_query = _query || ' LEFT JOIN "Type" TP3 ON SE2.id_type = TP3.id';
		IF (_entity = 'OL') THEN
			_query = _query || ' LEFT JOIN "Olympics" OL ON (OL.id_year = YR.id AND OL.type = SP.type)';
		ELSIF (_entity = 'PR') THEN
			_type1 = 1;
			_type2 = 99;
			_query = _query || ' LEFT JOIN "~PersonList" PL ON PL.id_result = RS.id';
		END IF;
		_query = _query || ' WHERE ((TP1.number BETWEEN ' || _type1 || ' AND ' || _type2 || ' AND TP2.number IS NULL) OR (TP2.number BETWEEN ' || _type1 || ' AND ' || _type2 || ' AND TP3.number IS NULL) OR (TP3.number BETWEEN ' || _type1 || ' AND ' || _type2 || '))';
		IF _entity = 'CN' THEN
			_query = _query || ' AND (RS.id_rank1 = ' || _id || ' OR RS.id_rank2 = ' || _id || ' OR RS.id_rank3 = ' || _id || ' OR RS.id_rank4 = ' || _id || ' OR RS.id_rank5 = ' || _id || ' OR RS.id_rank6 = ' || _id || ' OR RS.id_rank7 = ' || _id || ' OR RS.id_rank8 = ' || _id || ' OR RS.id_rank9 = ' || _id || ' OR RS.id_rank10 = ' || _id || ' OR RS.id_rank11 = ' || _id || ' OR RS.id_rank12 = ' || _id || ' OR RS.id_rank13 = ' || _id || ' OR RS.id_rank14 = ' || _id || ' OR RS.id_rank15 = ' || _id || ' OR RS.id_rank16 = ' || _id || ' OR RS.id_rank17 = ' || _id || ' OR RS.id_rank18 = ' || _id || ' OR RS.id_rank19 = ' || _id || ' OR RS.id_rank20 = ' || _id || ')';
		ELSIF _entity = 'DT' THEN
			_query = _query || ' AND to_date(RS.date2, ''DD/MM/YYYY'') = to_date(''' || _date || ''', ''YYYYMMDD'')';
		ELSIF _entity = 'PR' THEN
			_query = _query || ' AND (PL.id_person IN (' || _pr_list || ') OR (((TP1.number BETWEEN 1 AND 10 AND TP2.number IS NULL) OR (TP2.number BETWEEN 1 AND 10 AND TP3.number IS NULL) OR (TP3.number BETWEEN 1 AND 10)) AND ((RS.id_rank1 IN (' || _pr_list || ') OR RS.id_rank2 IN (' || _pr_list || ') OR RS.id_rank3 IN (' || _pr_list || ') OR RS.id_rank4 IN (' || _pr_list || ') OR RS.id_rank5 IN (' || _pr_list || ') OR RS.id_rank6 IN (' || _pr_list || ') OR RS.id_rank7 IN (' || _pr_list || ') OR RS.id_rank8 IN (' || _pr_list || ') OR RS.id_rank9 IN (' || _pr_list || ') OR RS.id_rank10 IN (' || _pr_list || ') OR RS.id_rank11 IN (' || _pr_list || ') OR RS.id_rank12 IN (' || _pr_list || ') OR RS.id_rank13 IN (' || _pr_list || ') OR RS.id_rank14 IN (' || _pr_list || ') OR RS.id_rank15 IN (' || _pr_list || ') OR RS.id_rank16 IN (' || _pr_list || ') OR RS.id_rank17 IN (' || _pr_list || ') OR RS.id_rank18 IN (' || _pr_list || ') OR RS.id_rank19 IN (' || _pr_list || ') OR RS.id_rank20 IN (' || _pr_list || ')))))';
		ELSIF _entity = 'TM' THEN
			_query = _query || ' AND (RS.id_rank1 IN (' || _tm_list || ') OR RS.id_rank2 IN (' || _tm_list || ') OR RS.id_rank3 IN (' || _tm_list || ') OR RS.id_rank4 IN (' || _tm_list || ') OR RS.id_rank5 IN (' || _tm_list || ') OR RS.id_rank6 IN (' || _tm_list || ') OR RS.id_rank7 IN (' || _tm_list || ') OR RS.id_rank8 IN (' || _tm_list || ') OR RS.id_rank9 IN (' || _tm_list || ') OR RS.id_rank10 IN (' || _tm_list || ') OR RS.id_rank11 IN (' || _tm_list || ') OR RS.id_rank12 IN (' || _tm_list || ') OR RS.id_rank13 IN (' || _tm_list || ') OR RS.id_rank14 IN (' || _tm_list || ') OR RS.id_rank15 IN (' || _tm_list || ') OR RS.id_rank16 IN (' || _tm_list || ') OR RS.id_rank17 IN (' || _tm_list || ') OR RS.id_rank18 IN (' || _tm_list || ') OR RS.id_rank19 IN (' || _tm_list || ') OR RS.id_rank20 IN (' || _tm_list || '))';
		ELSIF _entity = 'SP' THEN
			_query = _query || ' AND RS.id_sport = ' || _id;
		ELSIF _entity = 'CP' THEN
			_query = _query || ' AND RS.id_championship = ' || _id;
		ELSIF _entity = 'EV' THEN
			_query = _query || ' AND  (RS.id_event = ' || _id || ' OR RS.id_subevent = ' || _id || ' OR RS.id_subevent2 = ' || _id || ')';
		ELSIF _entity = 'CT' THEN
			_query = _query || ' AND  (RS.id_city1 IN (' || _ct_list || ') OR RS.id_city2 IN (' || _ct_list || '))';
		ELSIF _entity = 'CX' THEN
			_query = _query || ' AND  (RS.id_complex1 IN (' || _cx_list || ') OR RS.id_complex2 IN (' || _cx_list || '))';
		ELSIF _entity = 'OL' THEN
			_query = _query || ' AND RS.id_championship=1 AND OL.id = ' || _id;
		ELSIF _entity = 'YR' THEN
			_query = _query || ' AND RS.id_year = ' || _id;
		END IF;
		_query = _query || ' ORDER BY YR.id DESC, SP.label' || _lang || ', CP.index, EV.index, SE.index, CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ' LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.id_rel3, _item.label_rel3, _item.id_rel4, _item.label_rel4, _item.id_rel5, _item.label_rel5, _item.id_rel18, _item.label_rel18, _item.label_rel12, _item.label_rel13, _item.label_rel14, _item.label_rel15, _item.label_rel16, _id1, _id2, _id3, _id4, _id5, _id6, _id7, _id8, _id9, _id10, _type1, _type2, _type3, _date1, _date2, _item.count1;
			EXIT WHEN NOT FOUND;
			IF _type3 IS NOT NULL THEN
				_type1 = _type3;
			ELSIF _type2 IS NOT NULL THEN
				_type1 = _type2;
			END IF;
			IF _type1 <= 10 THEN
				SELECT id_rank1, id_rank2, id_rank3, id_rank4, id_rank5, id_rank6, PR1.last_name || (CASE WHEN length(PR1.first_name) > 0 THEN ', ' || PR1.first_name ELSE '' END), (CASE WHEN length(PR1.first_name) > 0 THEN PR1.first_name || ' ' ELSE '' END) || PR1.last_name, CN1.id, CN1.code, TM1.label, PR2.last_name || (CASE WHEN length(PR2.first_name) > 0 THEN ', ' || PR2.first_name ELSE '' END), (CASE WHEN length(PR2.first_name) > 0 THEN PR2.first_name || ' ' ELSE '' END) || PR2.last_name, CN2.id, CN2.code, TM2.label, PR3.last_name || (CASE WHEN length(PR3.first_name) > 0 THEN ', ' || PR3.first_name ELSE '' END), (CASE WHEN length(PR3.first_name) > 0 THEN PR3.first_name || ' ' ELSE '' END) || PR3.last_name, CN3.id, CN3.code, TM3.label, PR4.last_name || (CASE WHEN length(PR4.first_name) > 0 THEN ', ' || PR4.first_name ELSE '' END), (CASE WHEN length(PR4.first_name) > 0 THEN PR4.first_name || ' ' ELSE '' END) || PR4.last_name, CN4.id, CN4.code, TM4.label, PR5.last_name || (CASE WHEN length(PR5.first_name) > 0 THEN ', ' || PR5.first_name ELSE '' END), (CASE WHEN length(PR5.first_name) > 0 THEN PR5.first_name || ' ' ELSE '' END) || PR5.last_name, CN5.id, CN5.code, TM5.label, PR6.last_name || (CASE WHEN length(PR6.first_name) > 0 THEN ', ' || PR6.first_name ELSE '' END), (CASE WHEN length(PR6.first_name) > 0 THEN PR6.first_name || ' ' ELSE '' END) || PR6.last_name, CN6.id, CN6.code, TM6.label, RS.result1, RS.result2, RS.comment, RS.exa
				INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.id_rel9, _item.id_rel10, _item.id_rel11, _item.label_rel6, _item.label_rel20, _item.id_rel12, _cn1, _tm1, _item.label_rel7, _item.label_rel21, _item.id_rel13, _cn2, _tm2, _item.label_rel8, _item.label_rel22, _item.id_rel14, _cn3, _tm3, _item.label_rel9, _item.label_rel23, _item.id_rel15, _cn4, _tm4, _item.label_rel10, _item.label_rel24, _item.id_rel16, _cn5, _tm5, _item.label_rel11, _item.label_rel25, _item.id_rel17, _cn6, _tm6, _item.txt1, _item.txt2, _item.txt3, _item.txt4
				FROM "Result" RS LEFT JOIN "Athlete" PR1 ON RS.id_rank1 = PR1.id LEFT JOIN "Athlete" PR2 ON RS.id_rank2 = PR2.id LEFT JOIN "Athlete" PR3 ON RS.id_rank3 = PR3.id LEFT JOIN "Athlete" PR4 ON RS.id_rank4 = PR4.id LEFT JOIN "Athlete" PR5 ON RS.id_rank5 = PR5.id LEFT JOIN "Athlete" PR6 ON RS.id_rank6 = PR6.id LEFT JOIN "Country" CN1 ON PR1.id_country = CN1.id LEFT JOIN "Country" CN2 ON PR2.id_country = CN2.id LEFT JOIN "Country" CN3 ON PR3.id_country = CN3.id LEFT JOIN "Country" CN4 ON PR4.id_country = CN4.id LEFT JOIN "Country" CN5 ON PR5.id_country = CN5.id LEFT JOIN "Country" CN6 ON PR6.id_country = CN6.id LEFT JOIN "Team" TM1 ON PR1.id_team = TM1.id LEFT JOIN "Team" TM2 ON PR2.id_team = TM2.id LEFT JOIN "Team" TM3 ON PR3.id_team = TM3.id LEFT JOIN "Team" TM4 ON PR4.id_team = TM4.id LEFT JOIN "Team" TM5 ON PR5.id_team = TM5.id LEFT JOIN "Team" TM6 ON PR6.id_team = TM6.id
				WHERE RS.id = _item.id_item;
				IF _cn1 IS NOT NULL THEN _item.label_rel6 = _item.label_rel6 || ' (' || _cn1 || ')';
				ELSIF _tm1 IS NOT NULL THEN _item.label_rel6 = _item.label_rel6 || ' (' || _tm1 || ')'; END IF;
				IF _cn2 IS NOT NULL THEN _item.label_rel7 = _item.label_rel7 || ' (' || _cn2 || ')';
				ELSIF _tm2 IS NOT NULL THEN _item.label_rel7 = _item.label_rel7 || ' (' || _tm2 || ')'; END IF;
				IF _cn3 IS NOT NULL THEN _item.label_rel8 = _item.label_rel8 || ' (' || _cn3 || ')';
				ELSIF _tm3 IS NOT NULL THEN _item.label_rel8 = _item.label_rel8 || ' (' || _tm3 || ')'; END IF;
				IF _cn4 IS NOT NULL THEN _item.label_rel9 = _item.label_rel9 || ' (' || _cn4 || ')';
				ELSIF _tm4 IS NOT NULL THEN _item.label_rel9 = _item.label_rel9 || ' (' || _tm4 || ')'; END IF;
				IF _cn5 IS NOT NULL THEN _item.label_rel10 = _item.label_rel10 || ' (' || _cn5 || ')';
				ELSIF _tm5 IS NOT NULL THEN _item.label_rel10 = _item.label_rel10 || ' (' || _tm5 || ')'; END IF;
				IF _cn6 IS NOT NULL THEN _item.label_rel11 = _item.label_rel11 || ' (' || _cn6 || ')';
				ELSIF _tm6 IS NOT NULL THEN _item.label_rel11 = _item.label_rel11 || ' (' || _tm6 || ')'; END IF;
				IF _type1 = 4 OR _item.txt3 = '#DOUBLE#' THEN
					_item.txt4 = '1-2/3-4/5-6';
				ELSIF _type1 = 5 OR _item.txt3 = '#TRIPLE#' THEN
					_item.txt4 = '1-3/4-6/7-9';
				END IF;
				_item.comment = 'PR';
				_array_id = string_to_array(_pr_list, ',')::integer[];
			ELSIF _type1 = 50 THEN
				SELECT id_rank1, id_rank2, id_rank3, id_rank4, id_rank5, id_rank6, TM1.label, TM2.label, TM3.label, TM4.label, TM5.label, TM6.label, NULL, NULL, NULL, NULL, NULL, NULL, RS.result1, RS.result2, RS.comment, RS.exa
				INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.id_rel9, _item.id_rel10, _item.id_rel11, _item.label_rel6, _item.label_rel7, _item.label_rel8, _item.label_rel9, _item.label_rel10, _item.label_rel11, _item.label_rel20, _item.label_rel21, _item.label_rel22, _item.label_rel23, _item.label_rel24, _item.label_rel25, _item.txt1, _item.txt2, _item.txt3, _item.txt4
				FROM "Result" RS LEFT JOIN "Team" TM1 ON RS.id_rank1 = TM1.id LEFT JOIN "Team" TM2 ON RS.id_rank2 = TM2.id LEFT JOIN "Team" TM3 ON RS.id_rank3 = TM3.id LEFT JOIN "Team" TM4 ON RS.id_rank4 = TM4.id LEFT JOIN "Team" TM5 ON RS.id_rank5 = TM5.id LEFT JOIN "Team" TM6 ON RS.id_rank6 = TM6.id
				WHERE RS.id = _item.id_item;
				_item.comment = 'TM';
				_array_id = string_to_array(_tm_list, ',')::integer[];
			ELSIF _type1 = 99 THEN
				_query = 'SELECT id_rank1, id_rank2, id_rank3, id_rank4, id_rank5, id_rank6, CN1.label' || _lang || ', CN2.label' || _lang || ', CN3.label' || _lang || ', CN4.label' || _lang || ', CN5.label' || _lang || ', CN6.label' || _lang || ', CN1.label, CN2.label, CN3.label, CN4.label, CN5.label, CN6.label, RS.result1, RS.result2, RS.comment, RS.exa';
				_query = _query || ' FROM "Result" RS LEFT JOIN "Country" CN1 ON RS.id_rank1 = CN1.id LEFT JOIN "Country" CN2 ON RS.id_rank2 = CN2.id LEFT JOIN "Country" CN3 ON RS.id_rank3 = CN3.id LEFT JOIN "Country" CN4 ON RS.id_rank4 = CN4.id LEFT JOIN "Country" CN5 ON RS.id_rank5 = CN5.id LEFT JOIN "Country" CN6 ON RS.id_rank6 = CN6.id';
				_query = _query || ' WHERE RS.id = ' || _item.id_item;
				OPEN __c FOR EXECUTE _query;
				FETCH __c INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.id_rel9, _item.id_rel10, _item.id_rel11, _item.label_rel6, _item.label_rel7, _item.label_rel8, _item.label_rel9, _item.label_rel10, _item.label_rel11, _item.label_rel20, _item.label_rel21, _item.label_rel22, _item.label_rel23, _item.label_rel24, _item.label_rel25, _item.txt1, _item.txt2, _item.txt3, _item.txt4;
				CLOSE __c;
				_item.comment = 'CN';
				_array_id = ARRAY[_id];
			END IF;
			IF _entity = 'DT' THEN
				_item.date1 := to_date(_date1, 'DD/MM/YYYY');
				_item.date2 := to_date(_date2, 'DD/MM/YYYY');
			END IF;
			SELECT * INTO _rs FROM "Result" RS WHERE RS.id = _item.id_item;
			SELECT "GetRank"(_rs, _type1, _array_id) INTO _item.count1;
			_item.id = _index;
			_item.entity = 'RS';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Rounds]
	IF (_entity ~ 'CN|DT|PR|TM|CP|EV|SP|CX|CT|YR' AND (_entity_ref = 'RD' OR _entity_ref = '')) THEN
		_type1 = 1;
		_type2 = 99;
		IF _entity = 'CN' THEN _type1 = 99;_type2 = 99;
		ELSIF _entity = 'PR' THEN _type1 = 1;_type2 = 10;
		ELSIF _entity = 'TM' THEN _type1 = 50;_type2 = 50; END IF;
		_query = 'SELECT RD.id, RD.id_result, RD.id_result_type, RT.label' || _lang || ', YR.id, YR.label, SP.id, SP.label' || _lang || ', CP.id, CP.label' || _lang || ', EV.id, EV.label' || _lang || ', SE.id, SE.label' || _lang || ', SE2.id, SE2.label' || _lang || ', SP.label, CP.label, EV.label, SE.label, SE2.label, RD.id_rank1, RD.id_rank2, RD.id_rank3, RD.date FROM "Round" RD';
		_query = _query || ' LEFT JOIN "Result" RS ON RD.id_result = RS.id';
		_query = _query || ' LEFT JOIN "RoundType" RT ON RD.id_round_type = RT.id';
		_query = _query || ' LEFT JOIN "Year" YR ON RS.id_year = YR.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON RS.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "Championship" CP ON RS.id_championship = CP.id';
		_query = _query || ' LEFT JOIN "Event" EV ON RS.id_event = EV.id';
		_query = _query || ' LEFT JOIN "Event" SE ON RS.id_subevent = SE.id';
		_query = _query || ' LEFT JOIN "Event" SE2 ON RS.id_subevent2 = SE2.id';
		_query = _query || ' WHERE (id_result_type BETWEEN ' || _type1 || ' AND ' || _type2 || ')';
		IF _entity = 'CN' THEN
			_query = _query || ' AND (RD.id_rank1 = ' || _id || ' OR RD.id_rank2 = ' || _id || ' OR RD.id_rank3 = ' || _id || ')';
		ELSIF _entity = 'DT' THEN
			_query = _query || ' AND to_date(RD.date, ''DD/MM/YYYY'') = to_date(''' || _date || ''', ''YYYYMMDD'')';
		ELSIF _entity = 'PR' THEN
			_query = _query || ' AND (RD.id_rank1 IN (' || _pr_list || ') OR RD.id_rank2 IN (' || _pr_list || ') OR RD.id_rank3 IN (' || _pr_list || '))';
		ELSIF _entity = 'TM' THEN
			_query = _query || ' AND (RD.id_rank1 IN (' || _tm_list || ') OR RD.id_rank2 IN (' || _tm_list || ') OR RD.id_rank3 IN (' || _tm_list || '))';
		ELSIF _entity = 'SP' THEN
			_query = _query || ' AND RS.id_sport = ' || _id;
		ELSIF _entity = 'CP' THEN
			_query = _query || ' AND RS.id_championship = ' || _id;
		ELSIF _entity = 'EV' THEN
			_query = _query || ' AND  (RS.id_event = ' || _id || ' OR RS.id_subevent = ' || _id || ' OR RS.id_subevent2 = ' || _id || ')';
		ELSIF _entity = 'CT' THEN
			_query = _query || ' AND  (RD.id_city IN (' || _ct_list || ') OR RD.id_city IN (' || _ct_list || '))';
		ELSIF _entity = 'CX' THEN
			_query = _query || ' AND  (RD.id_complex IN (' || _cx_list || ') OR RD.id_complex IN (' || _cx_list || '))';
		ELSIF _entity = 'YR' THEN
			_query = _query || ' AND RS.id_year = ' || _id;
		END IF;
		_query = _query || ' ORDER BY YR.id DESC, RD.id DESC LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.id_rel10, _type1, _item.label, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.id_rel3, _item.label_rel3, _item.id_rel4, _item.label_rel4, _item.id_rel5, _item.label_rel5, _item.id_rel18, _item.label_rel18, _item.label_rel12, _item.label_rel13, _item.label_rel14, _item.label_rel15, _item.label_rel16, _id1, _id2, _id3, _date2;
			EXIT WHEN NOT FOUND;
			IF _type1 <= 10 THEN
				SELECT id_rank1, id_rank2, id_rank3, PR1.last_name || (CASE WHEN length(PR1.first_name) > 0 THEN ', ' || PR1.first_name ELSE '' END), (CASE WHEN length(PR1.first_name) > 0 THEN PR1.first_name || ' ' ELSE '' END) || PR1.last_name, CN1.id, CN1.code, TM1.label, PR2.last_name || (CASE WHEN length(PR2.first_name) > 0 THEN ', ' || PR2.first_name ELSE '' END), (CASE WHEN length(PR2.first_name) > 0 THEN PR2.first_name || ' ' ELSE '' END) || PR2.last_name, CN2.id, CN2.code, TM2.label, PR3.last_name || (CASE WHEN length(PR3.first_name) > 0 THEN ', ' || PR3.first_name ELSE '' END), (CASE WHEN length(PR3.first_name) > 0 THEN PR3.first_name || ' ' ELSE '' END) || PR3.last_name, CN3.id, CN3.code, TM3.label, RD.result1, RD.result2, RD.result3
				INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.label_rel6, _item.label_rel20, _item.id_rel12, _cn1, _tm1, _item.label_rel7, _item.label_rel21, _item.id_rel13, _cn2, _tm2, _item.label_rel8, _item.label_rel22, _item.id_rel14, _cn3, _tm3, _item.txt1, _item.txt2, _item.txt3
				FROM "Round" RD LEFT JOIN "Athlete" PR1 ON RD.id_rank1 = PR1.id LEFT JOIN "Athlete" PR2 ON RD.id_rank2 = PR2.id LEFT JOIN "Athlete" PR3 ON RD.id_rank3 = PR3.id LEFT JOIN "Country" CN1 ON PR1.id_country = CN1.id LEFT JOIN "Country" CN2 ON PR2.id_country = CN2.id LEFT JOIN "Country" CN3 ON PR3.id_country = CN3.id LEFT JOIN "Team" TM1 ON PR1.id_team = TM1.id LEFT JOIN "Team" TM2 ON PR2.id_team = TM2.id LEFT JOIN "Team" TM3 ON PR3.id_team = TM3.id
				WHERE RD.id = _item.id_item;
				IF _cn1 IS NOT NULL THEN _item.label_rel6 = _item.label_rel6 || ' (' || _cn1 || ')';
				ELSIF _tm1 IS NOT NULL THEN _item.label_rel6 = _item.label_rel6 || ' (' || _tm1 || ')'; END IF;
				IF _cn2 IS NOT NULL THEN _item.label_rel7 = _item.label_rel7 || ' (' || _cn2 || ')';
				ELSIF _tm2 IS NOT NULL THEN _item.label_rel7 = _item.label_rel7 || ' (' || _tm2 || ')'; END IF;
				IF _cn3 IS NOT NULL THEN _item.label_rel8 = _item.label_rel8 || ' (' || _cn3 || ')';
				ELSIF _tm3 IS NOT NULL THEN _item.label_rel8 = _item.label_rel8 || ' (' || _tm3 || ')'; END IF;
				_item.comment = 'PR';
				_array_id = string_to_array(_pr_list, ',')::integer[];
			ELSIF _type1 = 50 THEN
				SELECT id_rank1, id_rank2, id_rank3, TM1.label, TM2.label, TM3.label, RD.result1, RD.result2, RD.result3
				INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.label_rel6, _item.label_rel7, _item.label_rel8, _item.txt1, _item.txt2, _item.txt3
				FROM "Round" RD LEFT JOIN "Team" TM1 ON RD.id_rank1 = TM1.id LEFT JOIN "Team" TM2 ON RD.id_rank2 = TM2.id LEFT JOIN "Team" TM3 ON RD.id_rank3 = TM3.id
				WHERE RD.id = _item.id_item;
				_item.comment = 'TM';
				_array_id = string_to_array(_tm_list, ',')::integer[];
			ELSIF _type1 = 99 THEN
				_query = 'SELECT id_rank1, id_rank2, id_rank3, CN1.label' || _lang || ', CN2.label' || _lang || ', CN3.label' || _lang || ', CN1.label, CN2.label, CN3.label, RD.result1, RD.result2, RD.result3';
				_query = _query || ' FROM "Round" RD LEFT JOIN "Country" CN1 ON RD.id_rank1 = CN1.id LEFT JOIN "Country" CN2 ON RD.id_rank2 = CN2.id LEFT JOIN "Country" CN3 ON RD.id_rank3 = CN3.id';
				_query = _query || ' WHERE RD.id = ' || _item.id_item;
				OPEN __c FOR EXECUTE _query;
				FETCH __c INTO _item.id_rel6, _item.id_rel7, _item.id_rel8, _item.label_rel6, _item.label_rel7, _item.label_rel8, _item.label_rel9, _item.label_rel10, _item.label_rel11, _item.txt1, _item.txt2, _item.txt3;
				CLOSE __c;
				_item.comment = 'CN';
				_array_id = ARRAY[_id];
			END IF;
			IF _entity = 'DT' THEN
				_item.date2 := to_date(_date2, 'DD/MM/YYYY');
			END IF;
			_item.id = _index;
			_item.entity = 'RD';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;
	
	-- References in: [Athletes]
	IF (_entity ~ 'CN|SP|TM' AND (_entity_ref = 'PR' OR _entity_ref = '')) THEN
		_query = 'SELECT DISTINCT ON (PR.last_name COLLATE "en_EN", PR.first_name COLLATE "en_EN", CN.id, SP.id) PR.id, PR.last_name || (CASE WHEN length(PR.first_name) > 0 THEN '', '' || PR.first_name ELSE '''' END), (CASE WHEN length(PR.first_name) > 0 THEN PR.first_name || '' '' ELSE '''' END) || PR.last_name, CN.id, CN.label' || _lang || ', SP.id, SP.label' || _lang || ', CN.label, SP.label, PR.link FROM "Athlete" PR';
		_query = _query || ' LEFT JOIN "Country" CN ON PR.id_country = CN.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON PR.id_sport = SP.id';
		IF _entity = 'CN' THEN
			_query = _query || ' WHERE PR.id_country = ' || _id;
		ELSIF _entity = 'SP' THEN
			_query = _query || ' WHERE PR.id_sport = ' || _id || ' AND (PR.link = 0 OR PR.link IS NULL)';
		ELSIF _entity = 'TM' THEN
			_query = _query || ' WHERE PR.id_team IN (' || _tm_list || ')';
		END IF;
		_query = _query || ' ORDER BY PR.last_name COLLATE "en_EN", PR.first_name COLLATE "en_EN", SP.id LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label, _item.label_en, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.label_rel3, _item.label_rel4, _item.id_rel11;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'PR';
			_item.txt3 := '';
			IF (_entity = 'SP' AND _item.id_rel11 = 0) THEN
				SELECT string_agg(CN.id || ',' || CN.label || ',' || CN.label_fr, '|') INTO _item.txt3 FROM "Athlete" PR LEFT JOIN "Country" CN ON PR.id_country=CN.id WHERE PR.link=_item.id_item;
			END IF;
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Teams]
	IF (_entity ~ 'SP|CN' AND (_entity_ref = 'TM' OR _entity_ref = '')) THEN
		_query = 'SELECT TM.id, TM.label, CN.id, CN.label' || _lang || ', SP.id, SP.label' || _lang || ', CN.label, SP.label FROM "Team" TM';
		_query = _query || ' LEFT JOIN "Country" CN ON TM.id_country = CN.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON TM.id_sport = SP.id';
		IF _entity = 'SP' THEN
			_query = _query || ' WHERE TM.id_sport = ' || _id;
		ELSIF _entity = 'CN' THEN
			_query = _query || ' WHERE TM.id_country = ' || _id;
		END IF;
		_query = _query || ' ORDER BY SP.label' || _lang || ', TM.label LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.label_rel3, _item.label_rel4;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'TM';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Cities]
	IF (_entity ~ 'CN|ST' AND (_entity_ref = 'CT' OR _entity_ref = '')) THEN
		_query = 'SELECT CT.id, CT.label' || _lang || ', CT.label, CN.id, CN.label' || _lang || ', CN.label FROM "City" CT';
		_query = _query || ' LEFT JOIN "State" ST ON CT.id_state = ST.id';
		_query = _query || ' LEFT JOIN "Country" CN ON CT.id_country = CN.id';
		IF _entity = 'CN' THEN
			_query = _query || ' WHERE CT.id_country = ' || _id;
		ELSIF _entity = 'ST' THEN
			_query = _query || ' WHERE CT.id_state = ' || _id;
		END IF;
		_query = _query || ' ORDER BY CT.label' || _lang || ' COLLATE "en_EN" LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label, _item.label_en, _item.id_rel1, _item.label_rel1, _item.label_rel2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CT';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Complexes]
	IF (_entity = 'CT' AND (_entity_ref = 'CX' OR _entity_ref = '')) THEN
		_query = 'SELECT CX.id, CX.label' || _lang || ', CX.label, CT.id, CT.label' || _lang || ', CN.id, CN.label' || _lang || ', CT.label, CN.label FROM "Complex" CX';
		_query = _query || ' LEFT JOIN "City" CT ON CX.id_city = CT.id';
		_query = _query || ' LEFT JOIN "State" ST ON CT.id_state = ST.id';
		_query = _query || ' LEFT JOIN "Country" CN ON CT.id_country = CN.id';
		_query = _query || ' WHERE CX.id_city = ' || _id;
		_query = _query || ' ORDER BY CX.label' || _lang || ' COLLATE "en_EN" LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label, _item.label_en, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.label_rel3, _item.label_rel4;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CX';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Olympics]
	IF (_entity ~ 'YR|CT' AND (_entity_ref = 'OL' OR _entity_ref = '')) THEN
		_query = 'SELECT OL.id, YR.id, YR.label, CT.id, CT.label' || _lang || ', CN.id, CN.label' || _lang || ', CT.label, CN.label, OL.type FROM "Olympics" OL';
		_query = _query || ' LEFT JOIN "Year" YR ON OL.id_year = YR.id';
		_query = _query || ' LEFT JOIN "City" CT ON OL.id_city = CT.id';
		_query = _query || ' LEFT JOIN "State" ST ON CT.id_state = ST.id';
		_query = _query || ' LEFT JOIN "Country" CN ON CT.id_country = CN.id';
		IF _entity = 'YR' THEN
			_query = _query || ' WHERE OL.id_year = ' || _id;
		ELSIF _entity = 'CT' THEN
			_query = _query || ' WHERE OL.id_city IN (' || _ct_list || ')';
		END IF;
		_query = _query || ' ORDER BY OL.type, YR.id DESC LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.id_rel4, _item.label_rel4, _item.label_rel5, _item.label_rel6, _item.comment;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'OL';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Olympic Rankings]
	IF (_entity ~ 'OL|CN' AND (_entity_ref = 'OR' OR _entity_ref = '')) THEN
		_query = 'SELECT OR_.id, OL.id, YR.id, YR.label, CT.id, CT.label' || _lang || ', CN.id, CN.label' || _lang || ', CT.label, CN.label, OR_.count_gold || '','' || OR_.count_silver || '','' || OR_.count_bronze FROM "OlympicRanking" OR_';
		_query = _query || ' LEFT JOIN "Olympics" OL ON OR_.id_olympics = OL.id';
		_query = _query || ' LEFT JOIN "Year" YR ON OL.id_year = YR.id';
		_query = _query || ' LEFT JOIN "City" CT ON OL.id_city = CT.id';
		_query = _query || ' LEFT JOIN "Country" CN ON OR_.id_country = CN.id';
		IF _entity = 'OL' THEN
			_query = _query || ' WHERE OR_.id_olympics = ' || _id;
		ELSIF _entity = 'CN' THEN
			_query = _query || ' WHERE OR_.id_country = ' || _id;
		END IF;
		_query = _query || ' ORDER BY YR.id DESC LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.id_rel1, _item.id_rel2, _item.label_rel2, _item.id_rel3, _item.label_rel3, _item.id_rel4, _item.label_rel4, _item.label_rel5, _item.label_rel6, _item.comment;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'OR';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Records]
	IF (_entity ~ 'CN|PR|TM|CP|EV|CT|SP' AND (_entity_ref = 'RC' OR _entity_ref = '')) THEN
		_type1 = 1;
		_type2 = 99;
		IF _entity = 'CN' THEN _type1 = 99;_type2 = 99;
		ELSIF _entity = 'PR' THEN _type1 = 1;_type2 = 10;
		ELSIF _entity = 'TM' THEN _type1 = 50;_type2 = 50; END IF;
		_query = 'SELECT RC.id, RC.label, SP.id, SP.label' || _lang || ', CP.id, CP.label' || _lang || ', EV.id, EV.label' || _lang || ', SE.id, SE.label' || _lang || ', SP.label, CP.label, EV.label, SE.label, RC.type1, RC.type2, RC.record1, RC.id_rank1, RC.id_rank2, RC.id_rank3, RC.id_rank4, RC.id_rank5 FROM "Record" RC';
		_query = _query || ' LEFT JOIN "Sport" SP ON RC.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "Championship" CP ON RC.id_championship = CP.id';
		_query = _query || ' LEFT JOIN "Event" EV ON RC.id_event = EV.id';
		_query = _query || ' LEFT JOIN "Event" SE ON RC.id_subevent = SE.id';
		_query = _query || ' LEFT JOIN "Type" TP ON EV.id_type = TP.id';
		_query = _query || ' WHERE TP.number BETWEEN ' || _type1 || ' AND ' || _type2;
		IF _entity = 'CN' THEN
			_query = _query || ' AND (RC.id_rank1 = ' || _id || ' OR RC.id_rank2 = ' || _id || ' OR RC.id_rank3 = ' || _id || ' OR RC.id_rank4 = ' || _id || ' OR RC.id_rank5 = ' || _id || ')';
		ELSIF _entity = 'PR' THEN
			_query = _query || ' AND (RC.id_rank1 IN (' || _pr_list || ') OR RC.id_rank2 IN (' || _pr_list || ') OR RC.id_rank3 IN (' || _pr_list || ') OR RC.id_rank4 IN (' || _pr_list || ') OR RC.id_rank5 IN (' || _pr_list || '))';
		ELSIF _entity = 'TM' THEN
			_query = _query || ' AND (RC.id_rank1 IN (' || _tm_list || ') OR RC.id_rank2 IN (' || _tm_list || ') OR RC.id_rank3 IN (' || _tm_list || ') OR RC.id_rank4 IN (' || _tm_list || ') OR RC.id_rank5 IN (' || _tm_list || '))';
		ELSIF _entity = 'SP' THEN
			_query = _query || ' AND RC.id_sport = ' || _id;
		ELSIF _entity = 'CP' THEN
			_query = _query || ' AND RC.id_championship = ' || _id;
		ELSIF _entity = 'EV' THEN
			_query = _query || ' AND  (RC.id_event = ' || _id || ' OR RC.id_subevent = ' || _id || ')';
		ELSIF _entity = 'CT' THEN
			_query = _query || ' AND RC.id_city IN (' || _ct_list || ')';
		END IF;
		_query = _query || ' ORDER BY SP.label' || _lang || ', CP.index, EV.index, SE.index, CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ', RC.index LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.id_rel3, _item.label_rel3, _item.id_rel4, _item.label_rel4, _item.label_rel5, _item.label_rel6, _item.label_rel7, _item.label_rel8, _item.txt1, _item.txt2, _item.txt3, _id1, _id2, _id3, _id4, _id5;
			EXIT WHEN NOT FOUND;
			IF _entity ~ 'CN|PR|TM' THEN
				IF _id1 = _id THEN _item.comment = '1';
				ELSIF _id2 = _id THEN _item.comment = '2';
				ELSIF _id3 = _id THEN _item.comment = '3';
				ELSIF _id4 = _id THEN _item.comment = '4';
				ELSIF _id5 = _id THEN _item.comment = '5'; END IF;
			END IF;
			_item.id = _index;
			_item.entity = 'RC';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Hall of Fame]
	IF (_entity ~ 'YR|PR' AND (_entity_ref = 'HF' OR _entity_ref = '')) THEN
		_query = 'SELECT HF.id, YR.id, YR.label, PR.id, PR.last_name, PR.first_name, LG.id, LG.label, HF.position FROM "HallOfFame" HF';
		_query = _query || ' LEFT JOIN "Year" YR ON HF.id_year = YR.id';
		_query = _query || ' LEFT JOIN "Athlete" PR ON HF.id_person = PR.id';
		_query = _query || ' LEFT JOIN "League" LG ON HF.id_league = LG.id';
		IF _entity = 'YR' THEN
			_query = _query || ' WHERE HF.id_year = ' || _id;
		ELSIF _entity = 'PR' THEN
			_query = _query || ' WHERE HF.id_person IN (' || _pr_list || ')';
		END IF;
		_query = _query || ' ORDER BY YR.id DESC LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.label_rel3, _item.id_rel3, _item.comment, _item.txt1;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'HF';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Retired Numbers]
	IF (_entity ~ 'PR' AND (_entity_ref = 'RN' OR _entity_ref = '')) THEN
		_query = 'SELECT RN.id, TM.id, TM.label, PR.id, PR.last_name, PR.first_name, LG.id, LG.label, RN.number FROM "RetiredNumber" RN';
		_query = _query || ' LEFT JOIN "Team" TM ON RN.id_team = TM.id';
		_query = _query || ' LEFT JOIN "Athlete" PR ON RN.id_person = PR.id';
		_query = _query || ' LEFT JOIN "League" LG ON RN.id_league = LG.id';
		IF _entity = 'TM' THEN
			_query = _query || ' WHERE RN.id_team IN (' || _tm_list || ')';
		ELSIF _entity = 'PR' THEN
			_query = _query || ' WHERE RN.id_person IN (' || _pr_list || ')';
		END IF;
		_query = _query || ' ORDER BY TM.label, RN.number LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.label_rel3, _item.id_rel3, _item.comment, _item.id_rel4;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'RN';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Team Stadiums]
	IF (_entity ~ 'CX' AND (_entity_ref = 'TS' OR _entity_ref = '')) THEN
		_query = 'SELECT TS.id, TM.id, TM.label, CX.id, CX.label' || _lang || ', CT.id, CT.label' || _lang || ', ST.id, ST.label' || _lang || ', CN.id, CN.label' || _lang || ', CX.label, CT.label, ST.label, CN.label, LG.id, LG.label, TS.date1, TS.date2 FROM "TeamStadium" TS';
		_query = _query || ' LEFT JOIN "Team" TM ON TS.id_team = TM.id';
		_query = _query || ' LEFT JOIN "Complex" CX ON TS.id_complex = CX.id';
		_query = _query || ' LEFT JOIN "City" CT ON CX.id_city = CT.id';
		_query = _query || ' LEFT JOIN "State" ST ON CT.id_state = ST.id';
		_query = _query || ' LEFT JOIN "Country" CN ON CT.id_country = CN.id';
		_query = _query || ' LEFT JOIN "League" LG ON TS.id_league = LG.id';
		IF _entity = 'TM' THEN
			_query = _query || ' WHERE TS.id_team IN (' || _tm_list || ')';
		ELSIF _entity = 'CX' THEN
			_query = _query || ' WHERE TS.id_complex IN (' || _cx_list || ')';
		END IF;
		_query = _query || ' ORDER BY TM.label, TS.date1 DESC LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.id_rel3, _item.label_rel3, _item.id_rel4, _item.label_rel4, _item.id_rel5, _item.label_rel5, _item.label_rel6, _item.label_rel7, _item.label_rel8, _item.label_rel9, _item.id_rel6, _item.comment, _item.txt1, _item.txt2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'TS';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- References in: [Contributions]
	IF (_entity ~ 'CB' AND (_entity_ref = 'CO' OR _entity_ref = '')) THEN
		_query = 'SELECT RS.id, YR.id, YR.label, SP.id, SP.label' || _lang || ', CP.id, CP.label' || _lang || ', EV.id, EV.label' || _lang || ', SE.id, SE.label' || _lang || ', SE2.id, SE2.label' || _lang || ', SP.label, CP.label, EV.label, SE.label, SE2.label, CO.type, CO.date';
		_query = _query || ' FROM "~Contribution" CO';
		_query = _query || ' LEFT JOIN "Result" RS ON CO.id_item = RS.id';
		_query = _query || ' LEFT JOIN "Year" YR ON RS.id_year = YR.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON RS.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "Championship" CP ON RS.id_championship = CP.id';
		_query = _query || ' LEFT JOIN "Event" EV ON RS.id_event = EV.id';
		_query = _query || ' LEFT JOIN "Event" SE ON RS.id_subevent = SE.id';
		_query = _query || ' LEFT JOIN "Event" SE2 ON RS.id_subevent2 = SE2.id';
		_query = _query || ' WHERE RS.id_contributor=' || _id || ' ORDER BY CO.date DESC, YR.id DESC, SP.label' || _lang || ' LIMIT ' || _limit || ' OFFSET ' || _offset;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.id_rel1, _item.label_rel1, _item.id_rel2, _item.label_rel2, _item.id_rel3, _item.label_rel3, _item.id_rel4, _item.label_rel4, _item.id_rel5, _item.label_rel5, _item.id_rel18, _item.label_rel18, _item.label_rel6, _item.label_rel7, _item.label_rel8, _item.label_rel9, _item.label_rel10, _item.txt1, _item.date1; 
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CO';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;
	
	RETURN;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
  
  
  
  
  
  CREATE OR REPLACE FUNCTION "~Overview"(
    _entity character varying,
    _id_sport integer,
    _count integer,
    _pattern character varying,
    _lang character varying)
  RETURNS SETOF "~RefItem" AS
$BODY$
declare
	_item "~RefItem"%rowtype;
	_c refcursor;
	_index integer;
	_query text;
begin
	--RAISE NOTICE '%', '--'||_query;
	_index := 1;
	-- Results
	IF (_entity = 'RS' OR _entity = '') THEN
		_query = 'SELECT RS.id, YR.label, SP.label' || _lang || ', CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ', SE2.label' || _lang || ',';
		_query = _query || 'concat_ws('','', RS.id_rank1, RS.id_rank2, RS.id_rank3, RS.id_rank4, RS.id_rank5, RS.id_rank6, RS.id_rank7, RS.id_rank8, RS.id_rank9, RS.id_rank10, RS.id_rank11, RS.id_rank12, RS.id_rank13, RS.id_rank14, RS.id_rank15, RS.id_rank16, RS.id_rank17, RS.id_rank18, RS.id_rank19, RS.id_rank20) AS ranks,';
		_query = _query || 'concat_ws('','', RS.result1, RS.result2, RS.result3, RS.result4, RS.result5, RS.result6, RS.result7, RS.result8, RS.result9, RS.result10, RS.result11, RS.result12, RS.result13, RS.result14, RS.result15, RS.result16, RS.result17, RS.result18, RS.result19, RS.result20) AS results,';
		_query = _query || 'concat_ws('','', id_complex1, id_complex2, id_city1, id_city2) AS places, concat_ws('','', date1, date2) AS dates, TP1.number, TP2.number, TP3.number, string_agg(CAST (EL.id AS VARCHAR), '',''), string_agg(CAST (RD.id AS VARCHAR), '','')';	
		_query = _query || ' FROM "Result" RS';
		_query = _query || ' LEFT JOIN "Year" YR ON RS.id_year = YR.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON RS.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "Championship" CP ON RS.id_championship = CP.id';
		_query = _query || ' LEFT JOIN "Event" EV ON RS.id_event = EV.id';
		_query = _query || ' LEFT JOIN "Event" SE ON RS.id_subevent = SE.id';
		_query = _query || ' LEFT JOIN "Event" SE2 ON RS.id_subevent2 = SE2.id';
		_query = _query || ' LEFT JOIN "Type" TP1 ON EV.id_type = TP1.id';
		_query = _query || ' LEFT JOIN "Type" TP2 ON SE.id_type = TP2.id';
		_query = _query || ' LEFT JOIN "Type" TP3 ON SE2.id_type = TP3.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = RS.id';
		_query = _query || ' LEFT JOIN "Round" RD ON RD.id_result = RS.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(SP.label' || _lang || ') like ''' || lower(_pattern) || '%'' OR lower(EV.label' || _lang || ') like ''' || lower(_pattern) || '%'' OR lower(EV.label' || _lang || ') like ''' || lower(_pattern) || '%'' OR lower(YR.label) = ''' || _pattern || '''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR SP.id = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY RS.id, YR.id, YR.label, SP.label' || _lang || ', CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ', SE2.label' || _lang || ', ranks, results, places, dates, TP1.number, TP2.number, TP3.number, CP.index, EV.index, SE.index';
		_query = _query || ' ORDER BY YR.id DESC, RS.first_update DESC, SP.label' || _lang || ', CP.index, EV.index, SE.index, CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ' LIMIT ' || _count;

		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label_rel4, _item.label_rel5, _item.label_rel6, _item.txt3, _item.txt4, _item.txt1, _item.txt2, _item.id_rel1, _item.id_rel2, _item.id_rel3, _item.label, _item.label_en;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'RS';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Athletes
	IF (_entity = 'PR' OR _entity = '') THEN
		_query = 'SELECT PR.id, PR.last_name, PR.first_name, CN.code, TM.label, SP.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), PR.ref';
		_query = _query || ' FROM "Athlete" PR';
		_query = _query || ' LEFT JOIN "Country" CN ON PR.id_country = CN.id';
		_query = _query || ' LEFT JOIN "Team" TM ON PR.id_team = TM.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON PR.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = PR.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(PR.last_name) like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR PR.id_sport = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY PR.id, PR.last_name, PR.first_name, CN.code, TM.label, SP.label' || _lang || ', PR.ref';
		_query = _query || ' ORDER BY PR.last_name, PR.first_name LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label_rel4, _item.label_rel5, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'PR';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Teams
	IF (_entity = 'TM' OR _entity = '') THEN
		_query = 'SELECT TM.id, TM.label, CN.code, SP.label' || _lang || ', LG.label, string_agg(CAST (EL.id AS VARCHAR), '',''), TM.ref';
		_query = _query || ' FROM "Team" TM';
		_query = _query || ' LEFT JOIN "Country" CN ON TM.id_country = CN.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON TM.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "League" LG ON TM.id_league = LG.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = TM.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(TM.label) like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR SP.id = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY TM.id, TM.label, CN.code, SP.label' || _lang || ', LG.label, TM.ref';
		_query = _query || ' ORDER BY TM.label LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label_rel4, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'TM';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Sports
	IF (_entity = 'SP' OR _entity = '') THEN
		_query = 'SELECT SP.id, SP.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), SP.ref';
		_query = _query || ' FROM "Sport" SP';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = SP.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(SP.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR SP.id = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY SP.id, SP.label' || _lang || ', SP.ref';
		_query = _query || ' ORDER BY SP.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'SP';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Championships
	IF (_entity = 'CP' OR _entity = '') THEN
		_query = 'SELECT CP.id, CP.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), CP.ref';
		_query = _query || ' FROM "Championship" CP';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = CP.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(CP.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR CP.id IN (SELECT id_championship FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY CP.id, CP.label' || _lang || ', CP.ref';
		_query = _query || ' ORDER BY CP.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CP';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Events
	IF (_entity = 'EV' OR _entity = '') THEN
		_query = 'SELECT EV.id, EV.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), EV.ref';
		_query = _query || ' FROM "Event" EV';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = EV.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(EV.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR EV.id IN (SELECT id_event FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_subevent FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_subevent2 FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY EV.id, EV.label' || _lang || ', EV.ref';
		_query = _query || ' ORDER BY EV.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'EV';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Cities
	IF (_entity = 'CT' OR _entity = '') THEN
		_query = 'SELECT CT.id, CT.label' || _lang || ', CN.code, string_agg(CAST (EL.id AS VARCHAR), '',''), CT.ref';
		_query = _query || ' FROM "City" CT';
		_query = _query || ' LEFT JOIN "Country" CN ON CT.id_country = CN.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = CT.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(CT.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR CT.id IN (SELECT id_city1 FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_city2 FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY CT.id, CT.label' || _lang || ', CN.code, CT.ref';
		_query = _query || ' ORDER BY CT.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CT';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Complexes
	IF (_entity = 'CX' OR _entity = '') THEN
		_query = 'SELECT CX.id, CX.label' || _lang || ', CT.label' || _lang || ', CN.code, string_agg(CAST (EL.id AS VARCHAR), '',''), CX.ref';
		_query = _query || ' FROM "Complex" CX';
		_query = _query || ' LEFT JOIN "City" CT ON CX.id_city = CT.id';
		_query = _query || ' LEFT JOIN "Country" CN ON CT.id_country = CN.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = CX.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(CX.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR CX.id IN (SELECT id_complex1 FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_complex2 FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY CX.id, CX.label' || _lang || ', CT.label' || _lang || ', CN.code, CX.ref';
		_query = _query || ' ORDER BY CX.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CX';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	RETURN;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
  
  
  
  
  ALTER TABLE "~RefItem"
   ALTER COLUMN label TYPE character varying(500);
ALTER TABLE "~RefItem"
   ALTER COLUMN label_en TYPE character varying(500);
   
   
   
   CREATE OR REPLACE FUNCTION "~Overview"(
    _entity character varying,
    _id_sport integer,
    _count integer,
    _pattern character varying,
    _lang character varying)
  RETURNS SETOF "~RefItem" AS
$BODY$
declare
	_item "~RefItem"%rowtype;
	_c refcursor;
	_index integer;
	_query text;
begin
	--RAISE NOTICE '%', '--'||_query;
	_index := 1;
	-- Results
	IF (_entity = 'RS' OR _entity = '') THEN
		_query = 'SELECT RS.id, YR.label, SP.label' || _lang || ', CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ', SE2.label' || _lang || ',';
		_query = _query || 'concat_ws('','', RS.id_rank1, RS.id_rank2, RS.id_rank3, RS.id_rank4, RS.id_rank5, RS.id_rank6, RS.id_rank7, RS.id_rank8, RS.id_rank9, RS.id_rank10, RS.id_rank11, RS.id_rank12, RS.id_rank13, RS.id_rank14, RS.id_rank15, RS.id_rank16, RS.id_rank17, RS.id_rank18, RS.id_rank19, RS.id_rank20) AS ranks,';
		_query = _query || 'concat_ws('','', RS.result1, RS.result2, RS.result3, RS.result4, RS.result5, RS.result6, RS.result7, RS.result8, RS.result9, RS.result10, RS.result11, RS.result12, RS.result13, RS.result14, RS.result15, RS.result16, RS.result17, RS.result18, RS.result19, RS.result20) AS results,';
		_query = _query || 'concat_ws('','', coalesce(id_complex1, ''0''), coalesce(id_complex2, ''0''), coalesce(id_city1, ''0''), coalesce(id_city2, ''0'')) AS places, concat_ws('','', coalesce(date1, ''0''), coalesce(date2, ''0'')) AS dates, TP1.number, TP2.number, TP3.number, string_agg(CAST (EL.id AS VARCHAR), '',''), string_agg(CAST (RD.id AS VARCHAR), '','')';	
		_query = _query || ' FROM "Result" RS';
		_query = _query || ' LEFT JOIN "Year" YR ON RS.id_year = YR.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON RS.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "Championship" CP ON RS.id_championship = CP.id';
		_query = _query || ' LEFT JOIN "Event" EV ON RS.id_event = EV.id';
		_query = _query || ' LEFT JOIN "Event" SE ON RS.id_subevent = SE.id';
		_query = _query || ' LEFT JOIN "Event" SE2 ON RS.id_subevent2 = SE2.id';
		_query = _query || ' LEFT JOIN "Type" TP1 ON EV.id_type = TP1.id';
		_query = _query || ' LEFT JOIN "Type" TP2 ON SE.id_type = TP2.id';
		_query = _query || ' LEFT JOIN "Type" TP3 ON SE2.id_type = TP3.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = RS.id';
		_query = _query || ' LEFT JOIN "Round" RD ON RD.id_result = RS.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(SP.label' || _lang || ') like ''' || lower(_pattern) || '%'' OR lower(EV.label' || _lang || ') like ''' || lower(_pattern) || '%'' OR lower(EV.label' || _lang || ') like ''' || lower(_pattern) || '%'' OR lower(YR.label) = ''' || _pattern || '''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR SP.id = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY RS.id, YR.id, YR.label, SP.label' || _lang || ', CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ', SE2.label' || _lang || ', ranks, results, places, dates, TP1.number, TP2.number, TP3.number, CP.index, EV.index, SE.index';
		_query = _query || ' ORDER BY YR.id DESC, RS.first_update DESC, SP.label' || _lang || ', CP.index, EV.index, SE.index, CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ' LIMIT ' || _count;

		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label_rel4, _item.label_rel5, _item.label_rel6, _item.txt3, _item.txt4, _item.txt1, _item.txt2, _item.id_rel1, _item.id_rel2, _item.id_rel3, _item.label, _item.label_en;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'RS';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Athletes
	IF (_entity = 'PR' OR _entity = '') THEN
		_query = 'SELECT PR.id, PR.last_name, PR.first_name, CN.code, TM.label, SP.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), PR.ref';
		_query = _query || ' FROM "Athlete" PR';
		_query = _query || ' LEFT JOIN "Country" CN ON PR.id_country = CN.id';
		_query = _query || ' LEFT JOIN "Team" TM ON PR.id_team = TM.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON PR.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = PR.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(PR.last_name) like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR PR.id_sport = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY PR.id, PR.last_name, PR.first_name, CN.code, TM.label, SP.label' || _lang || ', PR.ref';
		_query = _query || ' ORDER BY PR.last_name, PR.first_name LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label_rel4, _item.label_rel5, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'PR';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Teams
	IF (_entity = 'TM' OR _entity = '') THEN
		_query = 'SELECT TM.id, TM.label, CN.code, SP.label' || _lang || ', LG.label, string_agg(CAST (EL.id AS VARCHAR), '',''), TM.ref';
		_query = _query || ' FROM "Team" TM';
		_query = _query || ' LEFT JOIN "Country" CN ON TM.id_country = CN.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON TM.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "League" LG ON TM.id_league = LG.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = TM.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(TM.label) like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR SP.id = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY TM.id, TM.label, CN.code, SP.label' || _lang || ', LG.label, TM.ref';
		_query = _query || ' ORDER BY TM.label LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label_rel4, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'TM';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Sports
	IF (_entity = 'SP' OR _entity = '') THEN
		_query = 'SELECT SP.id, SP.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), SP.ref';
		_query = _query || ' FROM "Sport" SP';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = SP.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(SP.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR SP.id = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY SP.id, SP.label' || _lang || ', SP.ref';
		_query = _query || ' ORDER BY SP.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'SP';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Championships
	IF (_entity = 'CP' OR _entity = '') THEN
		_query = 'SELECT CP.id, CP.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), CP.ref';
		_query = _query || ' FROM "Championship" CP';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = CP.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(CP.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR CP.id IN (SELECT id_championship FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY CP.id, CP.label' || _lang || ', CP.ref';
		_query = _query || ' ORDER BY CP.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CP';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Events
	IF (_entity = 'EV' OR _entity = '') THEN
		_query = 'SELECT EV.id, EV.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), EV.ref';
		_query = _query || ' FROM "Event" EV';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = EV.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(EV.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR EV.id IN (SELECT id_event FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_subevent FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_subevent2 FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY EV.id, EV.label' || _lang || ', EV.ref';
		_query = _query || ' ORDER BY EV.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'EV';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Cities
	IF (_entity = 'CT' OR _entity = '') THEN
		_query = 'SELECT CT.id, CT.label' || _lang || ', CN.code, string_agg(CAST (EL.id AS VARCHAR), '',''), CT.ref';
		_query = _query || ' FROM "City" CT';
		_query = _query || ' LEFT JOIN "Country" CN ON CT.id_country = CN.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = CT.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(CT.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR CT.id IN (SELECT id_city1 FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_city2 FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY CT.id, CT.label' || _lang || ', CN.code, CT.ref';
		_query = _query || ' ORDER BY CT.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CT';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Complexes
	IF (_entity = 'CX' OR _entity = '') THEN
		_query = 'SELECT CX.id, CX.label' || _lang || ', CT.label' || _lang || ', CN.code, string_agg(CAST (EL.id AS VARCHAR), '',''), CX.ref';
		_query = _query || ' FROM "Complex" CX';
		_query = _query || ' LEFT JOIN "City" CT ON CX.id_city = CT.id';
		_query = _query || ' LEFT JOIN "Country" CN ON CT.id_country = CN.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = CX.id';
		_query = _query || ' WHERE 0=1';
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' OR lower(CX.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		ELSIF _id_sport > 0 THEN
			_query = _query || ' OR CX.id IN (SELECT id_complex1 FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_complex2 FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		_query = _query || ' GROUP BY CX.id, CX.label' || _lang || ', CT.label' || _lang || ', CN.code, CX.ref';
		_query = _query || ' ORDER BY CX.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CX';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	RETURN;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
  
  
  
  CREATE OR REPLACE FUNCTION "~Overview"(
    _entity character varying,
    _id_sport integer,
    _count integer,
    _pattern character varying,
    _lang character varying)
  RETURNS SETOF "~RefItem" AS
$BODY$
declare
	_item "~RefItem"%rowtype;
	_c refcursor;
	_index integer;
	_query text;
begin
	--RAISE NOTICE '%', '--'||_query;
	_index := 1;
	-- Results
	IF (_entity = 'RS' OR _entity = '') THEN
		_query = 'SELECT RS.id, YR.label, SP.label' || _lang || ', CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ', SE2.label' || _lang || ',';
		_query = _query || 'concat_ws('','', RS.id_rank1, RS.id_rank2, RS.id_rank3, RS.id_rank4, RS.id_rank5, RS.id_rank6, RS.id_rank7, RS.id_rank8, RS.id_rank9, RS.id_rank10, RS.id_rank11, RS.id_rank12, RS.id_rank13, RS.id_rank14, RS.id_rank15, RS.id_rank16, RS.id_rank17, RS.id_rank18, RS.id_rank19, RS.id_rank20) AS ranks,';
		_query = _query || 'concat_ws('','', RS.result1, RS.result2, RS.result3, RS.result4, RS.result5, RS.result6, RS.result7, RS.result8, RS.result9, RS.result10, RS.result11, RS.result12, RS.result13, RS.result14, RS.result15, RS.result16, RS.result17, RS.result18, RS.result19, RS.result20) AS results,';
		_query = _query || 'concat_ws('','', coalesce(id_complex1, ''0''), coalesce(id_complex2, ''0''), coalesce(id_city1, ''0''), coalesce(id_city2, ''0'')) AS places, concat_ws('','', coalesce(date1, ''0''), coalesce(date2, ''0'')) AS dates, TP1.number, TP2.number, TP3.number, string_agg(CAST (EL.id AS VARCHAR), '',''), string_agg(CAST (RD.id AS VARCHAR), '','')';	
		_query = _query || ' FROM "Result" RS';
		_query = _query || ' LEFT JOIN "Year" YR ON RS.id_year = YR.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON RS.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "Championship" CP ON RS.id_championship = CP.id';
		_query = _query || ' LEFT JOIN "Event" EV ON RS.id_event = EV.id';
		_query = _query || ' LEFT JOIN "Event" SE ON RS.id_subevent = SE.id';
		_query = _query || ' LEFT JOIN "Event" SE2 ON RS.id_subevent2 = SE2.id';
		_query = _query || ' LEFT JOIN "Type" TP1 ON EV.id_type = TP1.id';
		_query = _query || ' LEFT JOIN "Type" TP2 ON SE.id_type = TP2.id';
		_query = _query || ' LEFT JOIN "Type" TP3 ON SE2.id_type = TP3.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = RS.id';
		_query = _query || ' LEFT JOIN "Round" RD ON RD.id_result = RS.id';
		_query = _query || ' WHERE 0=1';
		IF _id_sport > 0 THEN
			_query = _query || ' OR SP.id = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' AND (lower(SP.label' || _lang || ') like ''' || lower(_pattern) || '%'' OR lower(EV.label' || _lang || ') like ''' || lower(_pattern) || '%'' OR lower(EV.label' || _lang || ') like ''' || lower(_pattern) || '%'' OR lower(YR.label) = ''' || _pattern || ''')';
		END IF;
		_query = _query || ' GROUP BY RS.id, YR.id, YR.label, SP.label' || _lang || ', CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ', SE2.label' || _lang || ', ranks, results, places, dates, TP1.number, TP2.number, TP3.number, CP.index, EV.index, SE.index';
		_query = _query || ' ORDER BY YR.id DESC, RS.first_update DESC, SP.label' || _lang || ', CP.index, EV.index, SE.index, CP.label' || _lang || ', EV.label' || _lang || ', SE.label' || _lang || ' LIMIT ' || _count;

		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label_rel4, _item.label_rel5, _item.label_rel6, _item.txt3, _item.txt4, _item.txt1, _item.txt2, _item.id_rel1, _item.id_rel2, _item.id_rel3, _item.label, _item.label_en;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'RS';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Athletes
	IF (_entity = 'PR' OR _entity = '') THEN
		_query = 'SELECT PR.id, PR.last_name, PR.first_name, CN.code, TM.label, SP.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), PR.ref';
		_query = _query || ' FROM "Athlete" PR';
		_query = _query || ' LEFT JOIN "Country" CN ON PR.id_country = CN.id';
		_query = _query || ' LEFT JOIN "Team" TM ON PR.id_team = TM.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON PR.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = PR.id';
		_query = _query || ' WHERE 0=1';
		IF _id_sport > 0 THEN
			_query = _query || ' OR PR.id_sport = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' AND lower(PR.last_name) like ''' || lower(_pattern) || '%''';
		END IF;	
		_query = _query || ' GROUP BY PR.id, PR.last_name, PR.first_name, CN.code, TM.label, SP.label' || _lang || ', PR.ref';
		_query = _query || ' ORDER BY PR.last_name, PR.first_name LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label_rel4, _item.label_rel5, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'PR';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Teams
	IF (_entity = 'TM' OR _entity = '') THEN
		_query = 'SELECT TM.id, TM.label, CN.code, SP.label' || _lang || ', LG.label, string_agg(CAST (EL.id AS VARCHAR), '',''), TM.ref';
		_query = _query || ' FROM "Team" TM';
		_query = _query || ' LEFT JOIN "Country" CN ON TM.id_country = CN.id';
		_query = _query || ' LEFT JOIN "Sport" SP ON TM.id_sport = SP.id';
		_query = _query || ' LEFT JOIN "League" LG ON TM.id_league = LG.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = TM.id';
		_query = _query || ' WHERE 0=1';
		IF _id_sport > 0 THEN
			_query = _query || ' OR SP.id = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' AND lower(TM.label) like ''' || lower(_pattern) || '%''';
		END IF;
		_query = _query || ' GROUP BY TM.id, TM.label, CN.code, SP.label' || _lang || ', LG.label, TM.ref';
		_query = _query || ' ORDER BY TM.label LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label_rel4, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'TM';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Sports
	IF (_entity = 'SP' OR _entity = '') THEN
		_query = 'SELECT SP.id, SP.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), SP.ref';
		_query = _query || ' FROM "Sport" SP';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = SP.id';
		_query = _query || ' WHERE 0=1';
		IF _id_sport > 0 THEN
			_query = _query || ' OR SP.id = ' || _id_sport;
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' AND lower(SP.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		END IF;	
		_query = _query || ' GROUP BY SP.id, SP.label' || _lang || ', SP.ref';
		_query = _query || ' ORDER BY SP.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'SP';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Championships
	IF (_entity = 'CP' OR _entity = '') THEN
		_query = 'SELECT CP.id, CP.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), CP.ref';
		_query = _query || ' FROM "Championship" CP';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = CP.id';
		_query = _query || ' WHERE 0=1';
		IF _id_sport > 0 THEN
			_query = _query || ' OR CP.id IN (SELECT id_championship FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' AND lower(CP.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		END IF;
		_query = _query || ' GROUP BY CP.id, CP.label' || _lang || ', CP.ref';
		_query = _query || ' ORDER BY CP.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CP';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Events
	IF (_entity = 'EV' OR _entity = '') THEN
		_query = 'SELECT EV.id, EV.label' || _lang || ', string_agg(CAST (EL.id AS VARCHAR), '',''), EV.ref';
		_query = _query || ' FROM "Event" EV';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = EV.id';
		_query = _query || ' WHERE 0=1';
		IF _id_sport > 0 THEN
			_query = _query || ' OR EV.id IN (SELECT id_event FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_subevent FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_subevent2 FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' AND lower(EV.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		END IF;	
		_query = _query || ' GROUP BY EV.id, EV.label' || _lang || ', EV.ref';
		_query = _query || ' ORDER BY EV.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'EV';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Cities
	IF (_entity = 'CT' OR _entity = '') THEN
		_query = 'SELECT CT.id, CT.label' || _lang || ', CN.code, string_agg(CAST (EL.id AS VARCHAR), '',''), CT.ref';
		_query = _query || ' FROM "City" CT';
		_query = _query || ' LEFT JOIN "Country" CN ON CT.id_country = CN.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = CT.id';
		_query = _query || ' WHERE 0=1';
		IF _id_sport > 0 THEN
			_query = _query || ' OR CT.id IN (SELECT id_city1 FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_city2 FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' AND lower(CT.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		END IF;
		_query = _query || ' GROUP BY CT.id, CT.label' || _lang || ', CN.code, CT.ref';
		_query = _query || ' ORDER BY CT.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CT';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	-- Complexes
	IF (_entity = 'CX' OR _entity = '') THEN
		_query = 'SELECT CX.id, CX.label' || _lang || ', CT.label' || _lang || ', CN.code, string_agg(CAST (EL.id AS VARCHAR), '',''), CX.ref';
		_query = _query || ' FROM "Complex" CX';
		_query = _query || ' LEFT JOIN "City" CT ON CX.id_city = CT.id';
		_query = _query || ' LEFT JOIN "Country" CN ON CT.id_country = CN.id';
		_query = _query || ' LEFT JOIN "~ExternalLink" EL ON EL.id_item = CX.id';
		_query = _query || ' WHERE 0=1';
		IF _id_sport > 0 THEN
			_query = _query || ' OR CX.id IN (SELECT id_complex1 FROM "Result" WHERE id_sport=' || _id_sport || ' UNION SELECT id_complex2 FROM "Result" WHERE id_sport=' || _id_sport || ')';
		ELSE
			_query = _query || ' OR 1=1';
		END IF;
		IF (_pattern IS NOT NULL AND _pattern <> '') THEN
			_query = _query || ' AND lower(CX.label' || _lang || ') like ''' || lower(_pattern) || '%''';
		END IF;	
		_query = _query || ' GROUP BY CX.id, CX.label' || _lang || ', CT.label' || _lang || ', CN.code, CX.ref';
		_query = _query || ' ORDER BY CX.label' || _lang || ' LIMIT ' || _count;
		OPEN _c FOR EXECUTE _query;
		LOOP
			FETCH _c INTO _item.id_item, _item.label_rel1, _item.label_rel2, _item.label_rel3, _item.label, _item.count2;
			EXIT WHEN NOT FOUND;
			_item.id = _index;
			_item.entity = 'CX';
			RETURN NEXT _item;
			_index = _index + 1;
		END LOOP;
		CLOSE _c;
	END IF;

	RETURN;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
  
  
  
  
  
  alter table "RoundType" add CONSTRAINT "RoundType_pkey" PRIMARY KEY (id);
alter table "~ErrorReport" add CONSTRAINT "~ErrorReport_pkey" PRIMARY KEY (id);

alter table "~FolderHistory" add CONSTRAINT "~FolderHistory_pkey" PRIMARY KEY (id);

alter table "~InactiveItem" add CONSTRAINT "~InactiveItem_pkey" PRIMARY KEY (id);

alter table "~PersonList" add CONSTRAINT "~PersonList_pkey" PRIMARY KEY (id);

alter table "~Redirection" add CONSTRAINT "~Redirection_pkey" PRIMARY KEY (id);
alter table "~RefItem" add CONSTRAINT "~RefItem_pkey" PRIMARY KEY (id);
  
  alter table "~Request" add CONSTRAINT "~Request_pkey" PRIMARY KEY (id);
alter table "~Translation" add CONSTRAINT "~Translation_pkey" PRIMARY KEY (id);

alter table "~TreeItem" add CONSTRAINT "~TreeItem_pkey" PRIMARY KEY (id);




  