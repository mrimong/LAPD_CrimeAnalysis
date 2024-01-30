#1.	In a big city like Los Angeles, there are several different kinds of crimes being committed every day. 
#The head of the police department wants to know which type of crimes are most committed to ensure that 
#they can distribute the workforce and train them accordingly.
USE LA_CRIMES; #Selecting the database
select 
	crime.crime_desc
    ,count(distinct record.dr_no) 	as Number_of_crimes  #Counting the number of incident ids to give the number of crimes
	
    from crime crime
    #Joining crime and record tables based on crime code
	inner join records record 
		on record.crime_code = crime.crime_Code

group by crime.crime_desc
order by Number_of_crimes desc
;
#-------------------------------------------------------------------------------------------------------------------------------------
#2.Furthermore, He wants to update their LAPD website to ensure that civilians and tourists are aware of potential unsafe areas. 
#He wants to know which areas have the most crimes being committed and what sort of crimes are common in these areas.
#Preferably a list of top 5 areas with most crimes and the type of crimes would be ideal for his future action items. 

select distinct 
	location.Area_Name
	,crime.crime_desc 
    ,count(distinct record.dr_no) 		as Number_of_crimes
	,dense_rank() 
		over(partition by location.area_name order by count(distinct record.dr_no) desc) 	as commonality_rank
        #Rank to understand which crimes are common across the area names

	from crime crime
	inner join records record 
		on record.crime_code = crime.crime_code
	inner join location location 
		on location.DR_No = record.dr_no
        
group by location.area_name
		,crime.crime_desc
order by Number_of_crimes desc
;
#-------------------------------------------------------------------------------------------------------------------------------------
#3. What time of the day are crimes most likely to happen in which areas? Also, find the average age of victims for these areas and crimes
select 
	area_name
    ,time_occ
	,crime_desc
    ,count(distinct record.dr_no) 						as number_of_victims
    ,avg(age) 											as avg_age_of_victim

	from records record 
	inner join crime crime 
			on crime.crime_Code=record.crime_code
	inner join location location 
			on location.dr_no= record.dr_no
	inner join victim  
			on record.dr_no=victim.dr_no

group by area_name
		,time_occ
		,crime_desc 
order by number_of_victims desc
;

#-------------------------------------------------------------------------------------------------------------------------------------
#4. Are victims belonging to one particular descent or do they belong to a particular gender. Is there any correlation between age, sex, descent with crime?
select 
	sex
	,age
	,descent
    ,count(distinct dr_no) as number_of_victims
    
	from victim  

group by sex
		,age
		,descent
order by number_of_victims desc;

#-------------------------------------------------------------------------------------------------------------------------------------
#5.Display two sets of victims one with “youngest” victim age, the other with “oldest” victim age along with their age, area of crime and crime type.
select distinct 
	location.area_name
    ,crime_desc
    ,victim.age
    ,'minimum group' as age_group 
    #Group of victims with minimum age along with the type of crimes committed against them
    
	from victim inner join location location 
			on location.dr_no= victim.dr_no 
	inner join records records 
			on records.dr_no= location.dr_no
	inner join crime crime 
			on crime.crime_Code= records.crime_code

where age = (select min(age) from victim)

union all

select distinct 
	location.area_name
    ,crime_desc
    ,victim.age
    ,'max age group' age_group 
    #Group of victims with oldest age along with the type of crimes committed against them
    
    from victim victim
    inner join location location 
		on location.dr_no= victim.dr_no 
	inner join records records
		on records.dr_no= location.dr_no
	inner join crime crime
		on crime.crime_Code= records.crime_code
        
where age = 
	(
		select max(age) 
		from victim where age<>120
    )
;
#-------------------------------------------------------------------------------------------------------------------------------------
#6.What is the most common status of cases and is there a pattern of crimes that are being neglected?
Select 
	investigation.status_desc
    , count(distinct records.dr_no) number_of_cases

	from investigation_status investigation 
	inner join records records
		on records.status_code = investigation.status_code
        
group by investigation.status_desc
order by number_of_cases desc
;


#7 Which are some of the oldest cases and what is the status for these cases and how old are they in terms of number of days?
with cte_date_difference as 
(
select 	
	dr_no
	#measuring the age of the case from the current date with the date crime occurred
    ,cast(datediff(curdate(),str_to_date(date_occ,'%m-%d-%Y') )as decimal) 		as diff
	
from LA_Crimes.records
)
select 
	records.dr_no
    ,i.status_desc
    ,diff as number_of_days_old
    
    from records records 
    inner join LA_CRIMES.investigation_status i
        on records.status_code = i.status_code
	inner join cte_date_difference date_difference 
		on date_difference.dr_no = records.dr_no
;

#-------------------------------------------------------------------------------------------------------------------------------------
#8. Are there certain premises which are more unsafe than the others and certain areas which are not good?
with cte_premise as
(
	select 
		prem.premise_code
        ,prem.premise_desc
        ,count(distinct dr_no) as number_of_records
        ,row_number() over( order by count(distinct dr_no) desc) rno
 
		from premise prem
		inner join records rec
				on rec.premise_code= prem.premise_code
group by prem.premise_code
        ,prem.premise_desc
order by prem.premise_desc desc
)
,cte_area as 
( 
	select 
		area_name
        , count(distinct dr_no)  as number_of_records
        ,row_number() over( order by count(distinct dr_no) desc) rno2
  
		from location 
group by  area_name
)
  
,cte_age as
(
	select 
		min(age)
        , max(age)
        , loc.area_name
		
        from victim vict
		inner join records rec
				on rec.dr_no= vict.dr_no
		inner join location loc
				on loc.dr_no= rec.dr_no
)  

select distinct 
		location.area_name
        , premise_desc
		,case when rno>=5 then 'bad premise'
			else 'good' end					 		as typeofpremise 
		,case when rno2>=5 then 'bad area'
			else 'good' end 						as typeofarea
		,prem.number_of_records as noofcrimesinpremise
		,area.number_of_records as noofcrimesinarea

		from location location
		inner join records rec 
				on rec.dr_no = location.DR_No
		inner join cte_premise prem 
				on prem.premise_code = rec.premise_CODE
		inner join cte_area area
				on area.area_name = location.area_name
;
#-------------------------------------------------------------------------------------------------------------------------------------
#9. People want to know how safe their areas are especially for kids or people who live with dependent and old parents. Create a report of the number of kidnapping crimes for each areas along with the weapons used for committing them and how the police department have treated these cases,
# it would also benefit them if they could see a profile of age group of victims. 
with cte_group as
(
	select distinct 
		loc.area_name
        ,case
				when age<13 then 'children'
				when age <19 then 'teens'
				when age>=20 and age < 35 then 'youth'
				when age> 35 and age <60 then 'middle aged'else 'senior citizens' 
		end 										as age_group
		
        from victim vic
		inner join records rec 
				on rec.dr_no= vic.dr_no
		inner join location loc 
				on loc.dr_no = rec.DR_No
)

,cte_area_crime as
(
select 
		loc.area_name
		, crime.crime_desc
        , count(distinct rec.dr_no) as cnt_crime
		
        from crime crime
		inner join records rec on rec.crime_code= crime.crime_code
		inner join location loc on loc.dr_no = rec.DR_No

where upper(crime_desc) like '%KIDNAP%'
group by loc.area_name,crime.crime_desc
)

select distinct 
		loc.area_name
        , weapon_count.weapon_desc
        ,weapon_count.cwpn as numberofweapons_used
        , age.age_group 
        , area_crime.crime_desc as crime_description
        , area_crime.cnt_crime as number_of_crimes
        , invest.STATUS_DESC as investigation_status
        
		from location loc
		inner join records rec on loc.dr_no= rec.dr_no
		inner join 
			(select 
					loc.area_name
					,w.weapon_code
                    , w.weapon_desc
                    , count(distinct rec.dr_no) as cwpn
					
                    from weapon w 
					inner join records rec 
						on w.weapon_code= rec.weapon_code 
					inner join location loc
						on loc.dr_no=rec.dr_no
					
                    group by w.weapon_desc,loc.area_name
					,w.weapon_code
				)weapon_count

			on weapon_count.weapon_code= rec.weapon_code 
			and weapon_count.area_name= loc.area_name
		inner join cte_group age
			on age.area_name= loc.area_name
		inner join cte_area_crime area_crime
			on area_crime.area_name= loc.area_name
		inner join investigation_status invest 
			on invest.Status_Code=rec.status_code
;

#-------------------------------------------------------------------------------------------------------------------------------------
